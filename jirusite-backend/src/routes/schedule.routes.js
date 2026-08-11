const { Router } = require('express');
const { body } = require('express-validator');
const { query } = require('../db/pool');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');

const router = Router();
router.use(authenticate);

// ── GET /api/projects/:projectId/schedule ──────────────────────────────────
router.get(
  '/project/:projectId',
  asyncHandler(async (req, res) => {
    const { rows: proj } = await query(
      'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
      [req.params.projectId, req.user.organization_id]
    );
    if (!proj.length) return res.status(404).json({ error: 'Project not found' });

    const { rows } = await query(
      `SELECT st.*, cc.code AS cost_code_code, cc.name AS cost_code_name
       FROM schedule_tasks st
       LEFT JOIN cost_codes cc ON cc.id = st.cost_code_id
       WHERE st.project_id = $1
       ORDER BY cc.sort_order NULLS LAST, st.planned_start NULLS LAST`,
      [req.params.projectId]
    );
    res.json(rows);
  })
);

// ── POST /api/projects/:projectId/schedule ─────────────────────────────────
router.post(
  '/project/:projectId',
  [
    body('name').trim().notEmpty().withMessage('name is required'),
    body('planned_start').optional().isISO8601(),
    body('planned_end').optional().isISO8601(),
    body('percent_complete').optional().isInt({ min: 0, max: 100 }),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { rows: proj } = await query(
      'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
      [req.params.projectId, req.user.organization_id]
    );
    if (!proj.length) return res.status(404).json({ error: 'Project not found' });

    const { cost_code_id, name, planned_start, planned_end, percent_complete = 0 } = req.body;
    const { rows } = await query(
      `INSERT INTO schedule_tasks
         (project_id, cost_code_id, name, planned_start, planned_end, percent_complete)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [req.params.projectId, cost_code_id || null, name, planned_start || null, planned_end || null, percent_complete]
    );
    res.status(201).json(rows[0]);
  })
);

// ── PATCH /api/schedule-tasks/:id ─────────────────────────────────────────
router.patch(
  '/:id',
  asyncHandler(async (req, res) => {
    const allowed = ['name', 'planned_start', 'planned_end', 'actual_start',
                     'actual_end', 'percent_complete', 'status', 'cost_code_id'];
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

    values.push(req.params.id);
    values.push(req.user.organization_id);

    const { rows } = await query(
      `UPDATE schedule_tasks SET ${fields.join(', ')}
       WHERE id = $${idx}
         AND (SELECT organization_id FROM projects WHERE id = project_id) = $${idx + 1}
       RETURNING *`,
      values
    );
    if (!rows.length) return res.status(404).json({ error: 'Task not found' });
    res.json(rows[0]);
  })
);

// ── DELETE /api/schedule-tasks/:id ────────────────────────────────────────
router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `DELETE FROM schedule_tasks
       WHERE id = $1
         AND (SELECT organization_id FROM projects WHERE id = project_id) = $2
       RETURNING id`,
      [req.params.id, req.user.organization_id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Task not found' });
    res.json({ message: 'Task deleted' });
  })
);

module.exports = router;
