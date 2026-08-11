const { Router } = require('express');
const { body } = require('express-validator');
const { query } = require('../db/pool');
const { authenticate, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');

const router = Router();
router.use(authenticate);

// ── GET /api/organizations/me ──────────────────────────────────────────────
router.get(
  '/me',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `SELECT id, name, tin_number, subscription_tier, subscription_status,
              trial_ends_at, created_at
       FROM organizations WHERE id = $1`,
      [req.user.organization_id]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Organization not found' });
    }
    res.json(rows[0]);
  })
);

// ── POST /api/organizations (create — called during owner onboarding) ──────
router.post(
  '/',
  [
    body('name').trim().notEmpty().withMessage('name is required'),
    body('tin_number').optional().trim(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { name, tin_number } = req.body;

    // If user already has an org, block
    if (req.user.organization_id) {
      return res.status(409).json({ error: 'User already belongs to an organization' });
    }

    const trialEnds = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();
    const { rows } = await query(
      `INSERT INTO organizations (name, tin_number, trial_ends_at)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [name, tin_number || null, trialEnds]
    );
    const org = rows[0];

    // Link user to new org
    await query(
      'UPDATE users SET organization_id = $1 WHERE id = $2',
      [org.id, req.user.id]
    );

    res.status(201).json(org);
  })
);

// ── PATCH /api/organizations/me ────────────────────────────────────────────
router.patch(
  '/me',
  authorize(['owner', 'admin']),
  [
    body('name').optional().trim().notEmpty(),
    body('tin_number').optional().trim(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { name, tin_number } = req.body;
    const fields = [];
    const values = [];
    let idx = 1;

    if (name !== undefined) { fields.push(`name = $${idx++}`); values.push(name); }
    if (tin_number !== undefined) { fields.push(`tin_number = $${idx++}`); values.push(tin_number); }

    if (!fields.length) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    fields.push(`updated_at = now()`);
    values.push(req.user.organization_id);

    const { rows } = await query(
      `UPDATE organizations SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
      values
    );
    res.json(rows[0]);
  })
);

// ── GET /api/organizations/me/members ─────────────────────────────────────
router.get(
  '/me/members',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `SELECT id, full_name, phone_number, email, role, preferred_language, is_active, last_login_at
       FROM users WHERE organization_id = $1 ORDER BY full_name`,
      [req.user.organization_id]
    );
    res.json(rows);
  })
);

// ── POST /api/organizations/me/members (invite by phone) ──────────────────
router.post(
  '/me/members',
  authorize(['owner', 'admin']),
  [
    body('phone_number').trim().notEmpty().withMessage('phone_number is required'),
    body('role')
      .isIn(['admin', 'project_manager', 'site_engineer', 'viewer'])
      .withMessage('Invalid role'),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { phone_number, role } = req.body;

    const { rows } = await query(
      'SELECT id, organization_id FROM users WHERE phone_number = $1',
      [phone_number]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'No user found with that phone number' });
    }

    const target = rows[0];
    if (target.organization_id) {
      return res.status(409).json({ error: 'User already belongs to an organization' });
    }

    await query(
      'UPDATE users SET organization_id = $1, role = $2 WHERE id = $3',
      [req.user.organization_id, role, target.id]
    );

    res.json({ message: 'User added to organization', userId: target.id, role });
  })
);

module.exports = router;
