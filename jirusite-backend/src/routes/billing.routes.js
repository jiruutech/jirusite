const { Router } = require('express');
const { body } = require('express-validator');
const crypto = require('crypto');
const { query } = require('../db/pool');
const { authenticate, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');

const router = Router();

const TIER_PRICES = {
  starter:      { monthly: 0,     etb: 0 },
  growth:       { monthly: 1200,  etb: 1200 },
  professional: { monthly: 3500,  etb: 3500 },
  enterprise:   { monthly: 8000,  etb: 8000 },
};

// ── GET /api/billing/subscription ─────────────────────────────────────────
router.get(
  '/subscription',
  authenticate,
  asyncHandler(async (req, res) => {
    const { rows: org } = await query(
      `SELECT subscription_tier, subscription_status, trial_ends_at FROM organizations WHERE id = $1`,
      [req.user.organization_id]
    );

    const { rows: payments } = await query(
      `SELECT id, amount, currency, status, billing_period_start, billing_period_end, created_at
       FROM subscription_payments
       WHERE organization_id = $1 ORDER BY created_at DESC LIMIT 10`,
      [req.user.organization_id]
    );

    res.json({ subscription: org[0], payments });
  })
);

// ── POST /api/billing/telebirr/initiate ────────────────────────────────────
router.post(
  '/telebirr/initiate',
  authenticate,
  authorize(['owner']),
  [
    body('tier')
      .isIn(['growth', 'professional', 'enterprise'])
      .withMessage('Invalid subscription tier'),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { tier } = req.body;
    const price = TIER_PRICES[tier];

    const now = new Date();
    const periodEnd = new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());

    // Create a pending payment record
    const { rows } = await query(
      `INSERT INTO subscription_payments
         (organization_id, amount, currency, status, billing_period_start, billing_period_end)
       VALUES ($1,$2,'ETB','pending',$3,$4) RETURNING *`,
      [req.user.organization_id, price.monthly, now.toISOString().split('T')[0], periodEnd.toISOString().split('T')[0]]
    );
    const payment = rows[0];

    // In production: call Telebirr API to get a payment URL
    // For MVP we return a stub response
    const telebirrPayload = {
      appId: process.env.TELEBIRR_APP_ID,
      shortCode: process.env.TELEBIRR_SHORT_CODE,
      outTradeNo: payment.id,
      subject: `JIRUSite ${tier} subscription`,
      totalAmount: String(price.monthly),
      notifyUrl: process.env.TELEBIRR_NOTIFY_URL,
      returnUrl: `${process.env.APP_BASE_URL || 'https://app.jirusite.com'}/billing/success`,
      receiveName: 'JIRUSite',
      nonce: crypto.randomBytes(16).toString('hex'),
      timeoutExpress: '30',
    };

    // TODO: Sign & POST to Telebirr API — return redirect URL
    res.json({
      payment_id: payment.id,
      amount: price.monthly,
      currency: 'ETB',
      tier,
      // payment_url: signed telebirr redirect URL
      stub: 'Telebirr integration pending — sign telebirrPayload with your app key',
      telebirrPayload,
    });
  })
);

// ── POST /api/billing/telebirr/webhook ────────────────────────────────────
// Called by Telebirr after payment
router.post(
  '/telebirr/webhook',
  asyncHandler(async (req, res) => {
    const { outTradeNo, tradeNo, tradeStatus } = req.body;

    if (!outTradeNo) return res.status(400).json({ error: 'Missing outTradeNo' });

    const success = tradeStatus === 'SUCCESS' || tradeStatus === 'TRADE_SUCCESS';
    const status = success ? 'success' : 'failed';

    const { rows } = await query(
      `UPDATE subscription_payments
       SET status = $1, telebirr_transaction_id = $2
       WHERE id = $3 RETURNING organization_id, billing_period_end`,
      [status, tradeNo || null, outTradeNo]
    );

    if (rows.length && success) {
      // Activate subscription
      await query(
        `UPDATE organizations
         SET subscription_status = 'active', updated_at = now()
         WHERE id = $1`,
        [rows[0].organization_id]
      );
    }

    res.json({ received: true });
  })
);

module.exports = router;
