const bcrypt = require('bcryptjs');
const { query } = require('../db/pool');

// OTP validity window: 5 minutes
const OTP_TTL_MS = 5 * 60 * 1000;

/**
 * Generate a 6-digit numeric OTP, store its hash, and return the plaintext
 * code so the caller can send it via SMS.
 */
async function generateOtp(phoneNumber, purpose = 'verify') {
  const code = String(Math.floor(100000 + Math.random() * 900000));
  const hash = await bcrypt.hash(code, 10);
  const expiresAt = new Date(Date.now() + OTP_TTL_MS).toISOString();

  // Invalidate any prior unused codes for this phone+purpose
  await query(
    `UPDATE otp_codes SET used_at = now()
     WHERE phone_number = $1 AND purpose = $2 AND used_at IS NULL`,
    [phoneNumber, purpose]
  );

  await query(
    `INSERT INTO otp_codes (phone_number, code_hash, purpose, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [phoneNumber, hash, purpose, expiresAt]
  );

  return code;
}

/**
 * Verify an OTP code. Throws with status 400 if invalid/expired.
 * Marks it used on success.
 */
async function verifyOtp(phoneNumber, code, purpose = 'verify') {
  const { rows } = await query(
    `SELECT id, code_hash FROM otp_codes
     WHERE phone_number = $1 AND purpose = $2
       AND used_at IS NULL AND expires_at > now()
     ORDER BY created_at DESC LIMIT 1`,
    [phoneNumber, purpose]
  );

  if (!rows.length) {
    throw Object.assign(new Error('OTP not found or expired'), { status: 400 });
  }

  const valid = await bcrypt.compare(code, rows[0].code_hash);
  if (!valid) {
    throw Object.assign(new Error('Invalid OTP'), { status: 400 });
  }

  await query('UPDATE otp_codes SET used_at = now() WHERE id = $1', [rows[0].id]);
  return true;
}

module.exports = { generateOtp, verifyOtp };
