const { Router } = require('express');
const bcrypt = require('bcryptjs');
const { body } = require('express-validator');
const { query } = require('../db/pool');
const { validate } = require('../middleware/validate');
const { authenticate } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const tokenService = require('../services/token.service');
const otpService = require('../services/otp.service');
const { sendSms } = require('../services/sms.service');

const router = Router();

// ── POST /api/auth/register ────────────────────────────────────────────────
router.post(
  '/register',
  [
    body('full_name').trim().notEmpty().withMessage('full_name is required'),
    body('phone_number')
      .trim()
      .notEmpty()
      .matches(/^\+?[0-9]{9,15}$/)
      .withMessage('Valid phone_number is required'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
    body('role')
      .optional()
      .isIn(['owner', 'admin', 'project_manager', 'site_engineer', 'viewer'])
      .withMessage('Invalid role'),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { full_name, phone_number, email, password, role = 'owner', preferred_language } = req.body;

    const existing = await query('SELECT id FROM users WHERE phone_number = $1', [phone_number]);
    if (existing.rows.length) {
      return res.status(409).json({ error: 'Phone number already registered' });
    }

    const password_hash = await bcrypt.hash(password, 12);

    const { rows } = await query(
      `INSERT INTO users (full_name, phone_number, email, password_hash, role, preferred_language)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, full_name, phone_number, email, role, preferred_language, created_at`,
      [full_name, phone_number, email || null, password_hash, role, preferred_language || 'am']
    );

    const user = rows[0];
    const accessToken = tokenService.generateAccessToken(user);
    const refreshToken = tokenService.generateRefreshToken(user);
    await tokenService.saveRefreshToken(user.id, refreshToken);

    res.status(201).json({ user, accessToken, refreshToken });
  })
);

// ── POST /api/auth/login ───────────────────────────────────────────────────
router.post(
  '/login',
  [
    body('phone_number').trim().notEmpty().withMessage('phone_number is required'),
    body('password').notEmpty().withMessage('password is required'),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { phone_number, password } = req.body;

    const { rows } = await query(
      `SELECT id, organization_id, full_name, phone_number, email, password_hash, role,
              preferred_language, is_active
       FROM users WHERE phone_number = $1`,
      [phone_number]
    );

    if (!rows.length) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = rows[0];

    if (!user.is_active) {
      return res.status(403).json({ error: 'Account deactivated' });
    }

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    await query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);

    const accessToken = tokenService.generateAccessToken(user);
    const refreshToken = tokenService.generateRefreshToken(user);
    await tokenService.saveRefreshToken(user.id, refreshToken);

    const { password_hash: _, ...safeUser } = user;
    res.json({ user: safeUser, accessToken, refreshToken });
  })
);

// ── POST /api/auth/refresh ─────────────────────────────────────────────────
router.post(
  '/refresh',
  asyncHandler(async (req, res) => {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ error: 'refreshToken is required' });
    }
    const tokens = await tokenService.rotateRefreshToken(refreshToken);
    res.json(tokens);
  })
);

// ── POST /api/auth/otp/request ─────────────────────────────────────────────
router.post(
  '/otp/request',
  [
    body('phone_number').trim().notEmpty().withMessage('phone_number is required'),
    body('purpose').optional().isIn(['verify', 'reset']).withMessage('Invalid purpose'),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { phone_number, purpose = 'verify' } = req.body;
    const code = await otpService.generateOtp(phone_number, purpose);
    await sendSms(phone_number, `Your JIRUSite verification code is: ${code}. Valid for 5 minutes.`);
    res.json({ message: 'OTP sent' });
  })
);

// ── POST /api/auth/otp/verify ──────────────────────────────────────────────
router.post(
  '/otp/verify',
  [
    body('phone_number').trim().notEmpty(),
    body('code').trim().notEmpty(),
    body('purpose').optional().isIn(['verify', 'reset']),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { phone_number, code, purpose = 'verify' } = req.body;
    await otpService.verifyOtp(phone_number, code, purpose);

    if (purpose === 'reset' && req.body.new_password) {
      const hash = await bcrypt.hash(req.body.new_password, 12);
      await query('UPDATE users SET password_hash = $1 WHERE phone_number = $2', [hash, phone_number]);
      return res.json({ message: 'Password reset successful' });
    }

    res.json({ message: 'OTP verified' });
  })
);

// ── POST /api/auth/logout ──────────────────────────────────────────────────
router.post(
  '/logout',
  authenticate,
  asyncHandler(async (req, res) => {
    await tokenService.revokeAllTokens(req.user.id);
    res.json({ message: 'Logged out' });
  })
);

module.exports = router;
