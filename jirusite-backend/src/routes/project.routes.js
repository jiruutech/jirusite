const { Router } = require('express');
const { body, param, query: qv } = require('express-validator');
const { query } = require('../db/pool');
const { authenticate, authorize, scopeProject } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');
const { writeAudit } = require('../services/audit.service');

const router = Router();
router.use(authenticate);

// ── GET /api/projects ──────────────────────────────────────────────────────
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `SELECT p.*,
         COALESCE(SUM(e.amount) FILTER (WHERE e.deleted_at IS NULL), 0) AS total_spent
       FROM projects p
       LEFT JOIN expenses e ON e.project_id = p.id
       WHERE p.organization_id = $1 AND p.deleted_at IS NULL
       GROUP BY p.id
       ORDER BY p.created_at DESC`,
      [req.user.organization_id]
    );
    res.json(rows);
  })
);

// ── POST /api/projects ─────────────────────────────────────────────────────
router.post(
  '/',
  authorize(['owner', 'admin', 'project_manager']),
  [
    body('name').trim().notEmpty().withMessage('name is required'),
    body('total_budget').optional().isDecimal(),
    body('start_date').optional().isISO8601(),
    body('target_end_date').optional().isISO8601(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const {
      name, location_text, latitude, longitude,
      total_budget, currency = 'ETB', start_date, target_end_date, status = 'planning',
    } = req.body;

    const { rows } = await query(
      `INSERT INTO projects
         (organization_id, name, location_text, latitude, longitude,
          total_budget, currency, start_date, target_end_date, status, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       RETURNING *`,
      [req.user.organization_id, name, location_text, latitude, longitude,
       total_budget, currency, start_date, target_end_date, status, req.user.id]
    );

    const project = rows[0];

    // Auto-add creator as member
    await query(
      `INSERT INTO project_members (project_id, user_id, role_on_project)
       VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
      [project.id, req.user.id, req.user.role]
    );

    await writeAudit({
      organizationId: req.user.organization_id,
      userId: req.user.id,
      entityType: 'project',
      entityId: project.id,
      action: 'create',
    });

    res.status(201).json(project);
  })
);

// ── GET /api/projects/:id ──────────────────────────────────────────────────
router.get(
  '/:id',
  scopeProject,
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `SELECT p.*,
         COALESCE(SUM(e.amount) FILTER (WHERE e.deleted_at IS NULL), 0) AS total_spent,
         COUNT(DISTINCT pm.user_id) AS member_count
       FROM projects p
       LEFT JOIN expenses e ON e.project_id = p.id
       LEFT JOIN project_members pm ON pm.project_id = p.id
       WHERE p.id = $1 GROUP BY p.id`,
      [req.params.id]
    );
    res.json(rows[0]);
  })
);

// ── PATCH /api/projects/:id ────────────────────────────────────────────────
router.patch(
  '/:id',
  authorize(['owner', 'admin', 'project_manager']),
  scopeProject,
  asyncHandler(async (req, res) => {
    const allowed = ['name', 'location_text', 'latitude', 'longitude',
                     'total_budget', 'start_date', 'target_end_date', 'status'];
    const fields = [];
    const values = [];
    let idx = 1;

    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        fields.push(`${key} = $${idx++}`);
        values.push(req.body[key]);
      }
    }
    if (!fields.length) return res.status(400).json({ error: 'No fields to update' });

    fields.push(`updated_at = now()`);
    values.push(req.params.id);

    const { rows } = await query(
      `UPDATE projects SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
      values
    );

    await writeAudit({
      organizationId: req.user.organization_id,
      userId: req.user.id,
      entityType: 'project',
      entityId: req.params.id,
      action: 'update',
      changes: req.body,
    });

    res.json(rows[0]);
  })
);

// ── GET /api/projects/:id/dashboard ───────────────────────────────────────
router.get(
  '/:id/dashboard',
  scopeProject,
  asyncHandler(async (req, res) => {
    const pid = req.params.id;

    const [budgetSummary, costCodeBreakdown, recentExpenses, laborSummary] = await Promise.all([
      // Overall budget vs actual
      query(
        `SELECT
           p.total_budget,
           p.currency,
           COALESCE(SUM(e.amount) FILTER (WHERE e.deleted_at IS NULL), 0) AS total_spent,
           p.total_budget - COALESCE(SUM(e.amount) FILTER (WHERE e.deleted_at IS NULL), 0) AS remaining
         FROM projects p
         LEFT JOIN expenses e ON e.project_id = p.id
         WHERE p.id = $1
         GROUP BY p.id`,
        [pid]
      ),
      // Per-cost-code breakdown
      query(
        `SELECT cc.id, cc.code, cc.name, cc.budgeted_amount,
           COALESCE(SUM(e.amount) FILTER (WHERE e.deleted_at IS NULL), 0) AS spent
         FROM cost_codes cc
         LEFT JOIN expenses e ON e.cost_code_id = cc.id
         WHERE cc.project_id = $1
         GROUP BY cc.id
         ORDER BY cc.sort_order`,
        [pid]
      ),
      // 10 most recent expenses
      query(
        `SELECT e.*, u.full_name AS entered_by_name, cc.name AS cost_code_name
         FROM expenses e
         JOIN users u ON u.id = e.entered_by
         LEFT JOIN cost_codes cc ON cc.id = e.cost_code_id
         WHERE e.project_id = $1 AND e.deleted_at IS NULL
         ORDER BY e.transaction_date DESC, e.created_at DESC LIMIT 10`,
        [pid]
      ),
      // Labor totals
      query(
        `SELECT COUNT(*) AS entry_count,
           SUM(total_amount) AS total_labor_cost,
           SUM(number_of_workers) AS total_worker_days
         FROM labor_entries
         WHERE project_id = $1 AND deleted_at IS NULL`,
        [pid]
      ),
    ]);

    res.json({
      budget: budgetSummary.rows[0],
      costCodes: costCodeBreakdown.rows,
      recentExpenses: recentExpenses.rows,
      labor: laborSummary.rows[0],
    });
  })
);

// ── GET /api/projects/:id/cost-codes ──────────────────────────────────────
router.get(
  '/:id/cost-codes',
  scopeProject,
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `SELECT cc.*,
         COALESCE(SUM(e.amount) FILTER (WHERE e.deleted_at IS NULL), 0) AS spent
       FROM cost_codes cc
       LEFT JOIN expenses e ON e.cost_code_id = cc.id
       WHERE cc.project_id = $1
       GROUP BY cc.id
       ORDER BY cc.sort_order, cc.code`,
      [req.params.id]
    );
    res.json(rows);
  })
);

// ── POST /api/projects/:id/cost-codes ─────────────────────────────────────
router.post(
  '/:id/cost-codes',
  authorize(['owner', 'admin', 'project_manager']),
  scopeProject,
  [
    body('code').trim().notEmpty(),
    body('name').trim().notEmpty(),
    body('budgeted_amount').optional().isDecimal(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { code, name, budgeted_amount = 0, parent_cost_code_id, sort_order = 0 } = req.body;
    const { rows } = await query(
      `INSERT INTO cost_codes (project_id, code, name, budgeted_amount, parent_cost_code_id, sort_order)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [req.params.id, code, name, budgeted_amount, parent_cost_code_id || null, sort_order]
    );
    res.status(201).json(rows[0]);
  })
);

// ── GET /api/projects/:id/team ─────────────────────────────────────────────
router.get(
  '/:id/team',
  scopeProject,
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `SELECT u.id, u.full_name, u.phone_number, u.email, pm.role_on_project, pm.added_at
       FROM project_members pm
       JOIN users u ON u.id = pm.user_id
       WHERE pm.project_id = $1`,
      [req.params.id]
    );
    res.json(rows);
  })
);

// ── POST /api/projects/:id/team ────────────────────────────────────────────
router.post(
  '/:id/team',
  authorize(['owner', 'admin', 'project_manager']),
  scopeProject,
  [
    body('user_id').isUUID(),
    body('role_on_project').trim().notEmpty(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { user_id, role_on_project } = req.body;
    // Ensure user belongs to same org
    const { rows: userRows } = await query(
      'SELECT id FROM users WHERE id = $1 AND organization_id = $2',
      [user_id, req.user.organization_id]
    );
    if (!userRows.length) {
      return res.status(404).json({ error: 'User not found in your organization' });
    }
    await query(
      `INSERT INTO project_members (project_id, user_id, role_on_project)
       VALUES ($1,$2,$3)
       ON CONFLICT (project_id, user_id) DO UPDATE SET role_on_project = $3`,
      [req.params.id, user_id, role_on_project]
    );
    res.status(201).json({ message: 'Member added' });
  })
);

module.exports = router;
