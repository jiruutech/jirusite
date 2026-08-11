/**
 * Notification service — handles FCM push and SMS dispatch,
 * and writes to the notifications table.
 */
const { query } = require('../db/pool');
const { sendSms } = require('./sms.service');

let admin;
try {
  admin = require('firebase-admin');

  // Prefer inline JSON env var (for Railway/cloud deployments) over a file path.
  let serviceAccount;
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    serviceAccount = require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
  } else {
    serviceAccount = require('../../firebase-service-account.json');
  }

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  }
} catch {
  console.warn('[FCM] Firebase admin not initialized — push notifications disabled');
  admin = null;
}

/**
 * Send a push notification via FCM.
 * @param {string} fcmToken
 * @param {string} title
 * @param {string} body
 * @param {object} data  — extra k/v pairs for the app
 */
async function sendPush(fcmToken, title, body, data = {}) {
  if (!admin) {
    console.log(`[Push stub] title="${title}" body="${body}"`);
    return null;
  }
  return admin.messaging().send({
    token: fcmToken,
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
  });
}

/**
 * Notify a user — inserts a notifications row, then dispatches via FCM and/or SMS.
 * @param {object} opts
 * @param {string} opts.userId
 * @param {string} opts.title
 * @param {string} opts.body
 * @param {string[]} opts.channels — e.g. ['push', 'sms']
 * @param {string} [opts.fcmToken]
 * @param {string} [opts.phoneNumber]
 */
async function notifyUser({ userId, title, body, channels = ['push'], fcmToken, phoneNumber }) {
  for (const channel of channels) {
    await query(
      `INSERT INTO notifications (user_id, channel, title, body, sent_at)
       VALUES ($1, $2, $3, $4, now())`,
      [userId, channel, title, body]
    );

    if (channel === 'push' && fcmToken) {
      await sendPush(fcmToken, title, body).catch((err) =>
        console.error('[FCM error]', err.message)
      );
    }

    if (channel === 'sms' && phoneNumber) {
      await sendSms(phoneNumber, `${title}: ${body}`).catch((err) =>
        console.error('[SMS error]', err.message)
      );
    }
  }
}

module.exports = { notifyUser, sendPush };
