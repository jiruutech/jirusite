const { Router } = require('express');
const { body } = require('express-validator');
const crypto = require('crypto');
const axios = require('axios');
const { query } = require('../db/pool');
const { authenticate, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errorHandler');

const router = Router();

// ── Constants ──────────────────────────────────────────────────────────────

const CHAPA_BASE_URL = 'https://api.chapa.co/v1';

const TIER_PRICES = {
  starter:      { monthly: 0     },
  growth:       { monthly: 1200  },
  professional: { monthly: 3500  },
  enterprise:   { monthly: 8000  },
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

// ── POST /api/billing/chapa/initiate ──────────────────────────────────────
// Creates a pending payment record, calls Chapa to get a checkout_url,
// returns the URL to the mobile app which opens it in a WebView.
router.post(
  '/chapa/initiate',
  authenticate,
  authorize(['owner']),
  [
    body('tier')
      .isIn(['growth', 'professional', 'enterprise'])
      .withMessage('Invalid subscription tier'),
    body('email').optional().isEmail(),
    body('first_name').optional().isString(),
    body('last_name').optional().isString(),
    body('phone_number').optional().isString(),
  ],
  validate,
  asyncHandler(async (req, res) => {
    const { tier, email, first_name = 'JIRUSite', last_name = 'User', phone_number } = req.body;
    const price = TIER_PRICES[tier];

    if (!price) return res.status(400).json({ error: 'Invalid tier' });
    if (!process.env.CHAPA_SECRET_KEY) {
      return res.status(503).json({ error: 'Payment gateway not configured (CHAPA_SECRET_KEY missing)' });
    }

    const now = new Date();
    const periodEnd = new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());

    // Create a pending payment record
    const { rows } = await query(
      `INSERT INTO subscription_payments
         (organization_id, amount, currency, status, billing_period_start, billing_period_end)
       VALUES ($1,$2,'ETB','pending',$3,$4) RETURNING id`,
      [
        req.user.organization_id,
        price.monthly,
        now.toISOString().split('T')[0],
        periodEnd.toISOString().split('T')[0],
      ]
    );
    const paymentId = rows[0].id;

    // Unique tx_ref — Chapa requires this to be unique per transaction
    const txRef = `jirusite-${paymentId}-${Date.now()}`;

    // Store txRef on payment record for later verification
    await query(
      'UPDATE subscription_payments SET chapa_tx_ref = $1, chapa_tier = $2 WHERE id = $3',
      [txRef, tier, paymentId]
    );

    const chapaPayload = {
      amount: String(price.monthly),
      currency: 'ETB',
      tx_ref: txRef,
      // User details — improves Chapa checkout UX
      ...(email && { email }),
      first_name,
      last_name,
      ...(phone_number && { phone_number }),
      callback_url: `${process.env.APP_BASE_URL || 'https://jirusite.onrender.com'}/api/billing/chapa/callback?tx_ref=${txRef}`,
      return_url: `${process.env.APP_BASE_URL || 'https://jirusite.onrender.com'}/api/billing/chapa/return?tx_ref=${txRef}`,
      customization: {
        title: `JIRUSite ${tier[0].toUpperCase()}${tier.slice(1)} Plan`,
        description: `Monthly subscription — ETB ${price.monthly}/month`,
        logo: process.env.APP_LOGO_URL || undefined,
      },
      meta: {
        organization_id: req.user.organization_id,
        payment_id: paymentId,
        tier,
      },
    };

    const chapaResp = await axios.post(
      `${CHAPA_BASE_URL}/transaction/initialize`,
      chapaPayload,
      {
        headers: {
          Authorization: `Bearer ${process.env.CHAPA_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
        timeout: 15000,
      }
    );

    if (chapaResp.data.status !== 'success') {
      return res.status(502).json({
        error: 'Chapa initialization failed',
        details: chapaResp.data.message,
      });
    }

    res.json({
      payment_id: paymentId,
      tx_ref: txRef,
      checkout_url: chapaResp.data.data.checkout_url,
      amount: price.monthly,
      currency: 'ETB',
      tier,
    });
  })
);

// ── GET /api/billing/chapa/callback ───────────────────────────────────────
// Chapa calls this after payment. We verify the transaction and update DB.
// This is called by Chapa's server, not the mobile app.
router.get(
  '/chapa/callback',
  asyncHandler(async (req, res) => {
    const { tx_ref } = req.query;
    if (!tx_ref) return res.status(400).json({ error: 'tx_ref required' });

    await _verifyAndActivate(tx_ref);
    res.json({ received: true });
  })
);

// ── POST /api/billing/chapa/webhook ──────────────────────────────────────
// Chapa webhook (enabled in Chapa dashboard).
// Payload contains { event, data: { tx_ref, status, ... } }
router.post(
  '/chapa/webhook',
  asyncHandler(async (req, res) => {
    // Optionally verify Chapa's webhook signature header
    const chapaHash = req.headers['x-chapa-signature'];
    if (chapaHash && process.env.CHAPA_WEBHOOK_SECRET) {
      const expected = crypto
        .createHmac('sha256', process.env.CHAPA_WEBHOOK_SECRET)
        .update(JSON.stringify(req.body))
        .digest('hex');
      if (!crypto.timingSafeEqual(Buffer.from(chapaHash), Buffer.from(expected))) {
        return res.status(401).json({ error: 'Invalid webhook signature' });
      }
    }

    const txRef = req.body?.data?.tx_ref || req.body?.tx_ref;
    if (txRef) await _verifyAndActivate(txRef).catch(console.error);

    res.json({ received: true });
  })
);

// ── GET /api/billing/chapa/return ─────────────────────────────────────────
// Browser return URL after Chapa checkout — shows a simple success page.
// The mobile app polls GET /api/billing/subscription after WebView closes
// to get updated subscription status.
router.get(
  '/chapa/return',
  asyncHandler(async (req, res) => {
    const { tx_ref } = req.query;
    if (tx_ref) await _verifyAndActivate(tx_ref).catch(() => {});

    // Return HTML that the mobile WebView can detect
    res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Payment</title>
          <style>
            body { font-family: -apple-system, sans-serif; text-align: center;
                   padding: 60px 20px; background: #f0f2f5; }
            .card { background: white; border-radius: 16px; padding: 40px 24px;
                    max-width: 360px; margin: 0 auto; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
            .icon { font-size: 56px; margin-bottom: 16px; }
            h1 { color: #16303D; margin: 0 0 8px; font-size: 22px; }
            p { color: #4A5C63; margin: 0; font-size: 15px; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">✅</div>
            <h1>Payment Complete</h1>
            <p>Your subscription has been activated. You can close this window.</p>
          </div>
          <script>
            // Signal the Flutter WebView that payment is done
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('paymentComplete', { tx_ref: '${tx_ref || ''}' });
            }
            // Also try postMessage for WebView implementations
            window.parent.postMessage({ type: 'PAYMENT_COMPLETE', tx_ref: '${tx_ref || ''}' }, '*');
          </script>
        </body>
      </html>
    `);
  })
);

// ── POST /api/billing/chapa/verify ────────────────────────────────────────
// Mobile app calls this to manually verify a transaction after WebView closes.
router.post(
  '/chapa/verify',
  authenticate,
  [body('tx_ref').notEmpty()],
  validate,
  asyncHandler(async (req, res) => {
    const { tx_ref } = req.body;
    const result = await _verifyAndActivate(tx_ref);
    res.json(result);
  })
);

// ── Telebirr legacy routes (kept for backward compat) ─────────────────────
router.post(
  '/telebirr/initiate',
  authenticate,
  authorize(['owner']),
  asyncHandler(async (_req, res) => {
    res.status(410).json({
      error: 'Telebirr integration has been replaced by Chapa. Use POST /api/billing/chapa/initiate instead.',
    });
  })
);

router.post('/telebirr/webhook', asyncHandler(async (_req, res) => {
  res.json({ received: true });
}));

// ── Shared helper ─────────────────────────────────────────────────────────

async function _verifyAndActivate(txRef) {
  if (!process.env.CHAPA_SECRET_KEY) return { verified: false };

  // Fetch payment record
  const { rows: pmts } = await query(
    `SELECT id, organization_id, chapa_tier, status FROM subscription_payments WHERE chapa_tx_ref = $1`,
    [txRef]
  );
  if (!pmts.length) return { verified: false, error: 'Payment not found' };

  const pmt = pmts[0];
  if (pmt.status === 'success') return { verified: true, already_active: true };

  // Verify with Chapa
  const verifyResp = await axios.get(
    `${CHAPA_BASE_URL}/transaction/verify/${txRef}`,
    {
      headers: { Authorization: `Bearer ${process.env.CHAPA_SECRET_KEY}` },
      timeout: 10000,
    }
  );

  const chapaStatus = verifyResp.data?.data?.status;
  const success = chapaStatus === 'success';

  await query(
    `UPDATE subscription_payments SET status = $1, chapa_ref_id = $2 WHERE id = $3`,
    [success ? 'success' : 'failed', verifyResp.data?.data?.reference || null, pmt.id]
  );

  if (success) {
    // Upgrade subscription tier
    await query(
      `UPDATE organizations
       SET subscription_tier = $1, subscription_status = 'active', updated_at = now()
       WHERE id = $2`,
      [pmt.chapa_tier, pmt.organization_id]
    );
  }

  return { verified: true, success, tier: pmt.chapa_tier };
}

module.exports = router;
