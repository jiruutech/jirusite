const { Router } = require('express');
const { body } = require('express-validator');
const { query } = require('../db/pool');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');

const router = Router();
router.use(authenticate);

// ── GET /api/suppliers ─────────────────────────────────────────────────────
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { category, region, verified, search } = req.query;
    const conditions = [];
    const values = [];
    let idx = 1;

    if (category)           { conditions.push(`category = $${idx++}`); values.push(category); }
    if (region)             { conditions.push(`location_text ILIKE $${idx++}`); values.push(`%${region}%`); }
    if (verified === 'true'){ conditions.push(`is_verified = true`); }
    if (search)             { conditions.push(`name ILIKE $${idx++}`); values.push(`%${search}%`); }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    const { rows } = await query(
      `SELECT * FROM suppliers ${where} ORDER BY is_verified DESC, average_rating DESC NULLS LAST, name`,
      values
    );
    res.json(rows);
  })
);

// ── GET /api/suppliers/:id ─────────────────────────────────────────────────
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const { rows } = await query('SELECT * FROM suppliers WHERE id = $1', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Supplier not found' });
    res.json(rows[0]);
  })
);

// ── POST /api/suppliers ────────────────────────────────────────────────────
router.post(
  '/',
  [
    body('name').trim().notEmpty().withMessage('name is required'),
    body('category').optional().trim(),
    body('phone_number').optional().trim(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { name, phone_number, location_text, category } = req.body;
    const { rows } = await query(
      `INSERT INTO suppliers (name, phone_number, location_text, category)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [name, phone_number || null, location_text || null, category || null]
    );
    res.status(201).json(rows[0]);
  })
);

module.exports = router;
