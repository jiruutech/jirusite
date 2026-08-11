const { Router } = require('express');
const { query } = require('../db/pool');
const { authenticate } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');

const router = Router();
router.use(authenticate);

// ── GET /api/notifications ─────────────────────────────────────────────────
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { unread_only, limit = 50 } = req.query;
    const conditions = ['user_id = $1'];
    const values = [req.user.id];
    let idx = 2;

    if (unread_only === 'true') { conditions.push(`is_read = false`); }

    const { rows } = await query(
      `SELECT * FROM notifications
       WHERE ${conditions.join(' AND ')}
       ORDER BY created_at DESC LIMIT $${idx}`,
      [...values, parseInt(limit, 10)]
    );
    res.json(rows);
  })
);

// ── PATCH /api/notifications/:id/read ─────────────────────────────────────
router.patch(
  '/:id/read',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      'UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2 RETURNING id',
      [req.params.id, req.user.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Notification not found' });
    res.json({ message: 'Marked as read' });
  })
);

// ── PATCH /api/notifications/read-all ─────────────────────────────────────
router.patch(
  '/read-all',
  asyncHandler(async (req, res) => {
    await query(
      'UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false',
      [req.user.id]
    );
    res.json({ message: 'All notifications marked as read' });
  })
);

// ── POST /api/notifications/register-token (FCM device token) ─────────────
router.post(
  '/register-token',
  asyncHandler(async (req, res) => {
    const { fcm_token } = req.body;
    if (!fcm_token) return res.status(400).json({ error: 'fcm_token is required' });

    // Store token on user — for MVP we store in users table (simple approach)
    await query(
      'UPDATE users SET fcm_token = $1 WHERE id = $2',
      [fcm_token, req.user.id]
    );
    res.json({ message: 'Token registered' });
  })
);

module.exports = router;
