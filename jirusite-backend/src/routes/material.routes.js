const { Router } = require('express');
const { body, query: qv } = require('express-validator');
const { query } = require('../db/pool');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');

const router = Router();
router.use(authenticate);

// ── GET /api/materials ─────────────────────────────────────────────────────
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { category, search } = req.query;
    const conditions = [];
    const values = [];
    let idx = 1;

    if (category) { conditions.push(`category = $${idx++}`); values.push(category); }
    if (search)   { conditions.push(`name ILIKE $${idx++}`); values.push(`%${search}%`); }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    const { rows } = await query(
      `SELECT * FROM materials ${where} ORDER BY category, name`,
      values
    );
    res.json(rows);
  })
);

// ── GET /api/materials/:id/price-history ──────────────────────────────────
router.get(
  '/:id/price-history',
  asyncHandler(async (req, res) => {
    const { region, days = 90 } = req.query;
    const conditions = ['mp.material_id = $1', `mp.observed_at >= now() - INTERVAL '${parseInt(days, 10)} days'`];
    const values = [req.params.id];
    let idx = 2;

    if (region) { conditions.push(`mp.region = $${idx++}`); values.push(region); }

    const { rows } = await query(
      `SELECT mp.*, s.name AS supplier_name, u.full_name AS reporter_name
       FROM material_prices mp
       LEFT JOIN suppliers s ON s.id = mp.supplier_id
       LEFT JOIN users u ON u.id = mp.reported_by
       WHERE ${conditions.join(' AND ')}
       ORDER BY mp.observed_at DESC`,
      values
    );
    res.json(rows);
  })
);

// ── POST /api/material-prices (crowdsourced) ───────────────────────────────
router.post(
  '/prices',
  [
    body('material_id').isUUID().withMessage('material_id is required'),
    body('region').trim().notEmpty().withMessage('region is required'),
    body('price').isDecimal().withMessage('price must be decimal'),
    body('observed_at').isISO8601().withMessage('observed_at must be a date'),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { material_id, supplier_id, region, price, observed_at } = req.body;

    const { rows } = await query(
      `INSERT INTO material_prices
         (material_id, supplier_id, region, price, currency, source, reported_by, observed_at)
       VALUES ($1,$2,$3,$4,'ETB','crowdsourced',$5,$6)
       RETURNING *`,
      [material_id, supplier_id || null, region, price, req.user.id, observed_at]
    );
    res.status(201).json(rows[0]);
  })
);

// ── GET /api/materials/:id ─────────────────────────────────────────────────
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const { rows } = await query('SELECT * FROM materials WHERE id = $1', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Material not found' });
    res.json(rows[0]);
  })
);

module.exports = router;
