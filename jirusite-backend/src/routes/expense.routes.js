const { Router } = require('express');
const { body } = require('express-validator');
const { query, getClient } = require('../db/pool');
const { authenticate, scopeProject } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');
const { writeAudit } = require('../services/audit.service');
const { upload, getFileUrl } = require('../services/upload.service');

const router = Router();
router.use(authenticate);

// ── GET /api/projects/:id/expenses ─────────────────────────────────────────
// Mounted via project routes but also accessible here directly
router.get(
  '/project/:projectId',
  asyncHandler(async (req, res) => {
    const { projectId } = req.params;
    // Org scope check
    const { rows: proj } = await query(
      'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
      [projectId, req.user.organization_id]
    );
    if (!proj.length) return res.status(404).json({ error: 'Project not found' });

    const { cost_code_id, expense_type, from_date, to_date, sync_status } = req.query;
    const conditions = ['e.project_id = $1', 'e.deleted_at IS NULL'];
    const values = [projectId];
    let idx = 2;

    if (cost_code_id) { conditions.push(`e.cost_code_id = $${idx++}`); values.push(cost_code_id); }
    if (expense_type) { conditions.push(`e.expense_type = $${idx++}`); values.push(expense_type); }
    if (from_date)    { conditions.push(`e.transaction_date >= $${idx++}`); values.push(from_date); }
    if (to_date)      { conditions.push(`e.transaction_date <= $${idx++}`); values.push(to_date); }
    if (sync_status)  { conditions.push(`e.sync_status = $${idx++}`); values.push(sync_status); }

    const { rows } = await query(
      `SELECT e.*, u.full_name AS entered_by_name, cc.name AS cost_code_name, s.name AS supplier_name
       FROM expenses e
       JOIN users u ON u.id = e.entered_by
       LEFT JOIN cost_codes cc ON cc.id = e.cost_code_id
       LEFT JOIN suppliers s ON s.id = e.supplier_id
       WHERE ${conditions.join(' AND ')}
       ORDER BY e.transaction_date DESC, e.created_at DESC`,
      values
    );
    res.json(rows);
  })
);

// ── POST /api/projects/:projectId/expenses ─────────────────────────────────
router.post(
  '/project/:projectId',
  [
    body('amount').isDecimal({ decimal_digits: '0,2' }).withMessage('amount must be a decimal'),
    body('expense_type')
      .isIn(['material', 'labor', 'equipment', 'other'])
      .withMessage('Invalid expense_type'),
    body('transaction_date').isISO8601().withMessage('transaction_date must be a date'),
    body('client_generated_id').optional().isUUID(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { projectId } = req.params;
    const {
      cost_code_id, supplier_id, description, amount,
      quantity, unit, expense_type, transaction_date, client_generated_id,
    } = req.body;

    // Org scope
    const { rows: proj } = await query(
      'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
      [projectId, req.user.organization_id]
    );
    if (!proj.length) return res.status(404).json({ error: 'Project not found' });

    const { rows } = await query(
      `INSERT INTO expenses
         (project_id, cost_code_id, entered_by, supplier_id, description,
          amount, quantity, unit, expense_type, transaction_date, client_generated_id, sync_status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'synced')
       ON CONFLICT (client_generated_id) DO UPDATE
         SET amount=$6, description=$5, sync_status='synced', updated_at=now()
       RETURNING *`,
      [projectId, cost_code_id || null, req.user.id, supplier_id || null,
       description, amount, quantity || null, unit || null, expense_type,
       transaction_date, client_generated_id || null]
    );

    await writeAudit({
      organizationId: req.user.organization_id,
      userId: req.user.id,
      entityType: 'expense',
      entityId: rows[0].id,
      action: 'create',
    });

    res.status(201).json(rows[0]);
  })
);

// ── POST /api/expenses/sync-batch ──────────────────────────────────────────
router.post(
  '/sync-batch',
  asyncHandler(async (req, res) => {
    const { expenses: batch } = req.body;
    if (!Array.isArray(batch) || !batch.length) {
      return res.status(400).json({ error: 'expenses array is required' });
    }

    const client = await getClient();
    const results = [];
    const conflicts = [];

    try {
      await client.query('BEGIN');

      for (const exp of batch) {
        // Validate project ownership
        const { rows: proj } = await client.query(
          'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
          [exp.project_id, req.user.organization_id]
        );
        if (!proj.length) {
          conflicts.push({ client_generated_id: exp.client_generated_id, reason: 'project_not_found' });
          continue;
        }

        // Check for server-side version conflict (server_updated_at > client's last_synced_at)
        if (exp.client_generated_id) {
          const { rows: existing } = await client.query(
            'SELECT id, updated_at FROM expenses WHERE client_generated_id = $1',
            [exp.client_generated_id]
          );

          if (existing.length && exp.server_updated_at) {
            const serverUpdated = new Date(existing[0].updated_at);
            const clientKnew = new Date(exp.server_updated_at);
            if (serverUpdated > clientKnew) {
              // Conflict: server wins, record it
              const { rows: serverRow } = await client.query(
                'SELECT * FROM expenses WHERE id = $1', [existing[0].id]
              );
              await client.query(
                `INSERT INTO sync_conflicts
                   (organization_id, user_id, entity_type, client_generated_id, client_payload, server_payload)
                 VALUES ($1,$2,'expense',$3,$4,$5)`,
                [req.user.organization_id, req.user.id, exp.client_generated_id,
                 JSON.stringify(exp), JSON.stringify(serverRow[0])]
              );
              conflicts.push({ client_generated_id: exp.client_generated_id, reason: 'conflict_server_wins' });
              results.push(serverRow[0]);
              continue;
            }
          }
        }

        const { rows } = await client.query(
          `INSERT INTO expenses
             (project_id, cost_code_id, entered_by, supplier_id, description,
              amount, quantity, unit, expense_type, transaction_date, client_generated_id, sync_status)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'synced')
           ON CONFLICT (client_generated_id) DO UPDATE
             SET amount=$6, description=$5, cost_code_id=$2, supplier_id=$4,
                 quantity=$7, unit=$8, expense_type=$9, transaction_date=$10,
                 sync_status='synced', updated_at=now()
           RETURNING *`,
          [exp.project_id, exp.cost_code_id || null, req.user.id, exp.supplier_id || null,
           exp.description, exp.amount, exp.quantity || null, exp.unit || null,
           exp.expense_type, exp.transaction_date, exp.client_generated_id || null]
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

// ── POST /api/expenses/:id/receipt ─────────────────────────────────────────
router.post(
  '/:id/receipt',
  upload.single('receipt'),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    // Verify expense ownership
    const { rows } = await query(
      `SELECT e.id, e.project_id FROM expenses e
       JOIN projects p ON p.id = e.project_id
       WHERE e.id = $1 AND p.organization_id = $2 AND e.deleted_at IS NULL`,
      [req.params.id, req.user.organization_id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Expense not found' });

    const url = getFileUrl(req, req.file.filename);
    await query(
      'UPDATE expenses SET receipt_photo_url = $1, updated_at = now() WHERE id = $2',
      [url, req.params.id]
    );

    res.json({ receipt_photo_url: url });
  })
);

// ── DELETE /api/expenses/:id (soft delete) ─────────────────────────────────
router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `UPDATE expenses SET deleted_at = now(), updated_at = now()
       WHERE id = $1
         AND entered_by = $2
         AND deleted_at IS NULL
       RETURNING id`,
      [req.params.id, req.user.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Expense not found' });

    await writeAudit({
      organizationId: req.user.organization_id,
      userId: req.user.id,
      entityType: 'expense',
      entityId: req.params.id,
      action: 'delete',
    });

    res.json({ message: 'Expense deleted' });
  })
);

module.exports = router;
