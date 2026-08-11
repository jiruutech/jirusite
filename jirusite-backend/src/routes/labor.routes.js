const { Router } = require('express');
const { body } = require('express-validator');
const { query, getClient } = require('../db/pool');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');
const { writeAudit } = require('../services/audit.service');

const router = Router();
router.use(authenticate);

// ── GET /api/labor/project/:projectId ─────────────────────────────────────
router.get(
  '/project/:projectId',
  asyncHandler(async (req, res) => {
    const { projectId } = req.params;
    const { rows: proj } = await query(
      'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
      [projectId, req.user.organization_id]
    );
    if (!proj.length) return res.status(404).json({ error: 'Project not found' });

    const { from_date, to_date, cost_code_id } = req.query;
    const conditions = ['l.project_id = $1', 'l.deleted_at IS NULL'];
    const values = [projectId];
    let idx = 2;

    if (from_date)    { conditions.push(`l.work_date >= $${idx++}`); values.push(from_date); }
    if (to_date)      { conditions.push(`l.work_date <= $${idx++}`); values.push(to_date); }
    if (cost_code_id) { conditions.push(`l.cost_code_id = $${idx++}`); values.push(cost_code_id); }

    const { rows } = await query(
      `SELECT l.*, u.full_name AS entered_by_name, cc.name AS cost_code_name
       FROM labor_entries l
       JOIN users u ON u.id = l.entered_by
       LEFT JOIN cost_codes cc ON cc.id = l.cost_code_id
       WHERE ${conditions.join(' AND ')}
       ORDER BY l.work_date DESC`,
      values
    );
    res.json(rows);
  })
);

// ── POST /api/labor/project/:projectId ────────────────────────────────────
router.post(
  '/project/:projectId',
  [
    body('worker_or_crew_name').trim().notEmpty().withMessage('worker_or_crew_name is required'),
    body('total_amount').isDecimal().withMessage('total_amount must be decimal'),
    body('work_date').isISO8601().withMessage('work_date must be a date'),
    body('client_generated_id').optional().isUUID(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { projectId } = req.params;
    const {
      cost_code_id, worker_or_crew_name, work_description,
      number_of_workers = 1, daily_rate, total_amount, work_date, client_generated_id,
    } = req.body;

    const { rows: proj } = await query(
      'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
      [projectId, req.user.organization_id]
    );
    if (!proj.length) return res.status(404).json({ error: 'Project not found' });

    const { rows } = await query(
      `INSERT INTO labor_entries
         (project_id, cost_code_id, entered_by, worker_or_crew_name, work_description,
          number_of_workers, daily_rate, total_amount, work_date, client_generated_id, sync_status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'synced')
       ON CONFLICT (client_generated_id) DO UPDATE
         SET worker_or_crew_name=$4, work_description=$5, number_of_workers=$6,
             daily_rate=$7, total_amount=$8, work_date=$9, sync_status='synced'
       RETURNING *`,
      [projectId, cost_code_id || null, req.user.id, worker_or_crew_name, work_description || null,
       number_of_workers, daily_rate || null, total_amount, work_date, client_generated_id || null]
    );

    await writeAudit({
      organizationId: req.user.organization_id,
      userId: req.user.id,
      entityType: 'labor_entry',
      entityId: rows[0].id,
      action: 'create',
    });

    res.status(201).json(rows[0]);
  })
);

// ── POST /api/labor/sync-batch ─────────────────────────────────────────────
router.post(
  '/sync-batch',
  asyncHandler(async (req, res) => {
    const { entries } = req.body;
    if (!Array.isArray(entries) || !entries.length) {
      return res.status(400).json({ error: 'entries array is required' });
    }

    const client = await getClient();
    const results = [];
    const conflicts = [];

    try {
      await client.query('BEGIN');

      for (const entry of entries) {
        const { rows: proj } = await client.query(
          'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
          [entry.project_id, req.user.organization_id]
        );
        if (!proj.length) {
          conflicts.push({ client_generated_id: entry.client_generated_id, reason: 'project_not_found' });
          continue;
        }

        const { rows } = await client.query(
          `INSERT INTO labor_entries
             (project_id, cost_code_id, entered_by, worker_or_crew_name, work_description,
              number_of_workers, daily_rate, total_amount, work_date, client_generated_id, sync_status)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'synced')
           ON CONFLICT (client_generated_id) DO UPDATE
             SET worker_or_crew_name=$4, work_description=$5, number_of_workers=$6,
                 daily_rate=$7, total_amount=$8, work_date=$9, sync_status='synced'
           RETURNING *`,
          [entry.project_id, entry.cost_code_id || null, req.user.id,
           entry.worker_or_crew_name, entry.work_description || null,
           entry.number_of_workers || 1, entry.daily_rate || null,
           entry.total_amount, entry.work_date, entry.client_generated_id || null]
        );
        results.push(rows[0]);
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    res.json({ synced: results, conflicts });
  })
);

// ── DELETE /api/labor/:id (soft delete) ───────────────────────────────────
router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `UPDATE labor_entries SET deleted_at = now()
       WHERE id=$1 AND entered_by=$2 AND deleted_at IS NULL
       RETURNING id`,
      [req.params.id, req.user.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Labor entry not found' });
    res.json({ message: 'Labor entry deleted' });
  })
);

module.exports = router;
