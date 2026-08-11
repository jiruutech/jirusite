const { Router } = require('express');
const { body } = require('express-validator');
const { query } = require('../db/pool');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');

const router = Router();
router.use(authenticate);

// ── POST /api/quote-requests ───────────────────────────────────────────────
router.post(
  '/',
  [
    body('material_id').optional().isUUID(),
    body('quantity').optional().isDecimal(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { project_id, material_id, quantity, unit, notes } = req.body;

    // Org scope if project is given
    if (project_id) {
      const { rows } = await query(
        'SELECT id FROM projects WHERE id=$1 AND organization_id=$2 AND deleted_at IS NULL',
        [project_id, req.user.organization_id]
      );
      if (!rows.length) return res.status(404).json({ error: 'Project not found' });
    }

    const { rows } = await query(
      `INSERT INTO quote_requests (project_id, requested_by, material_id, quantity, unit, notes)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [project_id || null, req.user.id, material_id || null, quantity || null, unit || null, notes || null]
    );
    res.status(201).json(rows[0]);
  })
);

// ── GET /api/quote-requests ────────────────────────────────────────────────
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `SELECT qr.*, m.name AS material_name, u.full_name AS requested_by_name
       FROM quote_requests qr
       LEFT JOIN materials m ON m.id = qr.material_id
       JOIN users u ON u.id = qr.requested_by
       WHERE u.organization_id = $1
       ORDER BY qr.created_at DESC`,
      [req.user.organization_id]
    );
    res.json(rows);
  })
);

// ── GET /api/quote-requests/:id/responses ─────────────────────────────────
router.get(
  '/:id/responses',
  asyncHandler(async (req, res) => {
    // Verify ownership
    const { rows: qr } = await query(
      `SELECT qr.id FROM quote_requests qr
       JOIN users u ON u.id = qr.requested_by
       WHERE qr.id = $1 AND u.organization_id = $2`,
      [req.params.id, req.user.organization_id]
    );
    if (!qr.length) return res.status(404).json({ error: 'Quote request not found' });

    const { rows } = await query(
      `SELECT qres.*, s.name AS supplier_name, s.phone_number AS supplier_phone
       FROM quote_responses qres
       JOIN suppliers s ON s.id = qres.supplier_id
       WHERE qres.quote_request_id = $1
       ORDER BY qres.quoted_price ASC`,
      [req.params.id]
    );
    res.json(rows);
  })
);

// ── POST /api/quote-requests/:id/responses ────────────────────────────────
router.post(
  '/:id/responses',
  [
    body('supplier_id').isUUID().withMessage('supplier_id is required'),
    body('quoted_price').isDecimal().withMessage('quoted_price is required'),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { supplier_id, quoted_price } = req.body;
    const { rows } = await query(
      `INSERT INTO quote_responses (quote_request_id, supplier_id, quoted_price)
       VALUES ($1,$2,$3) RETURNING *`,
      [req.params.id, supplier_id, quoted_price]
    );
    res.status(201).json(rows[0]);
  })
);

module.exports = router;
