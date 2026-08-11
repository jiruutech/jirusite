const { Router } = require('express');
const { body } = require('express-validator');
const { query } = require('../db/pool');
const { authenticate, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');
const { writeAudit } = require('../services/audit.service');
const { notifyUser } = require('../services/notification.service');

const router = Router();
router.use(authenticate);

// ── GET /api/projects/:projectId/purchase-orders ──────────────────────────
router.get(
  '/project/:projectId',
  asyncHandler(async (req, res) => {
    const { rows: proj } = await query(
      'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
      [req.params.projectId, req.user.organization_id]
    );
    if (!proj.length) return res.status(404).json({ error: 'Project not found' });

    const { rows } = await query(
      `SELECT po.*, s.name AS supplier_name,
         u1.full_name AS requested_by_name, u2.full_name AS approved_by_name,
         json_agg(json_build_object(
           'id', poi.id, 'material_id', poi.material_id, 'material_name', m.name,
           'quantity', poi.quantity, 'unit_price', poi.unit_price, 'line_total', poi.line_total
         )) AS items
       FROM purchase_orders po
       LEFT JOIN suppliers s ON s.id = po.supplier_id
       JOIN users u1 ON u1.id = po.requested_by
       LEFT JOIN users u2 ON u2.id = po.approved_by
       LEFT JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
       LEFT JOIN materials m ON m.id = poi.material_id
       WHERE po.project_id = $1 AND po.deleted_at IS NULL
       GROUP BY po.id, s.name, u1.full_name, u2.full_name
       ORDER BY po.created_at DESC`,
      [req.params.projectId]
    );
    res.json(rows);
  })
);

// ── POST /api/projects/:projectId/purchase-orders ─────────────────────────
router.post(
  '/project/:projectId',
  [
    body('items').isArray({ min: 1 }).withMessage('items must be a non-empty array'),
    body('items.*.quantity').isDecimal(),
    body('items.*.unit_price').isDecimal(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { rows: proj } = await query(
      'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
      [req.params.projectId, req.user.organization_id]
    );
    if (!proj.length) return res.status(404).json({ error: 'Project not found' });

    const { supplier_id, notes, items } = req.body;

    // Calculate total
    const total = items.reduce((sum, item) => sum + parseFloat(item.unit_price) * parseFloat(item.quantity), 0);

    const { rows } = await query(
      `INSERT INTO purchase_orders (project_id, supplier_id, requested_by, total_amount, notes)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [req.params.projectId, supplier_id || null, req.user.id, total.toFixed(2), notes || null]
    );
    const po = rows[0];

    // Insert line items
    for (const item of items) {
      const lineTotal = (parseFloat(item.unit_price) * parseFloat(item.quantity)).toFixed(2);
      await query(
        `INSERT INTO purchase_order_items (purchase_order_id, material_id, quantity, unit_price, line_total)
         VALUES ($1,$2,$3,$4,$5)`,
        [po.id, item.material_id || null, item.quantity, item.unit_price, lineTotal]
      );
    }

    await writeAudit({
      organizationId: req.user.organization_id,
      userId: req.user.id,
      entityType: 'purchase_order',
      entityId: po.id,
      action: 'create',
    });

    // Notify admins/owners that a PO needs approval
    const { rows: admins } = await query(
      `SELECT id, phone_number FROM users
       WHERE organization_id = $1 AND role IN ('owner', 'admin') AND is_active = true`,
      [req.user.organization_id]
    );
    for (const admin of admins) {
      await notifyUser({
        userId: admin.id,
        title: 'Purchase Order Needs Approval',
        body: `A new purchase order for ${total.toLocaleString()} ETB has been submitted.`,
        channels: ['push'],
      });
    }

    res.status(201).json(po);
  })
);

// ── PATCH /api/purchase-orders/:id/approve ────────────────────────────────
router.patch(
  '/:id/approve',
  authorize(['owner', 'admin']),
  asyncHandler(async (req, res) => {
    const { action, notes } = req.body; // action: 'approve' | 'reject'
    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'action must be approve or reject' });
    }

    const newStatus = action === 'approve' ? 'approved' : 'cancelled';
    const { rows } = await query(
      `UPDATE purchase_orders
       SET status = $1, approved_by = $2, approved_at = now(),
           notes = COALESCE($3, notes)
       WHERE id = $4
         AND deleted_at IS NULL
         AND (SELECT organization_id FROM projects WHERE id = project_id) = $5
       RETURNING *`,
      [newStatus, req.user.id, notes || null, req.params.id, req.user.organization_id]
    );

    if (!rows.length) return res.status(404).json({ error: 'Purchase order not found' });

    await writeAudit({
      organizationId: req.user.organization_id,
      userId: req.user.id,
      entityType: 'purchase_order',
      entityId: req.params.id,
      action: 'approve',
      changes: { status: newStatus },
    });

    // Notify requester
    const { rows: po } = await query(
      `SELECT po.requested_by, u.phone_number FROM purchase_orders po
       JOIN users u ON u.id = po.requested_by WHERE po.id = $1`,
      [req.params.id]
    );
    if (po.length) {
      await notifyUser({
        userId: po[0].requested_by,
        title: `Purchase Order ${action === 'approve' ? 'Approved' : 'Rejected'}`,
        body: `Your purchase order has been ${newStatus}.`,
        channels: ['push'],
      });
    }

    res.json(rows[0]);
  })
);

// ── DELETE /api/purchase-orders/:id (soft delete) ─────────────────────────
router.delete(
  '/:id',
  authorize(['owner', 'admin']),
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `UPDATE purchase_orders SET deleted_at = now()
       WHERE id = $1
         AND deleted_at IS NULL
         AND (SELECT organization_id FROM projects WHERE id = project_id) = $2
       RETURNING id`,
      [req.params.id, req.user.organization_id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Purchase order not found' });
    res.json({ message: 'Purchase order deleted' });
  })
);

module.exports = router;
