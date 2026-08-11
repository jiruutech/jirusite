const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { query } = require('../db/pool');

const ACCESS_EXPIRES = process.env.JWT_EXPIRES_IN || '15m';
const REFRESH_EXPIRES = process.env.JWT_REFRESH_EXPIRES_IN || '7d';

function generateAccessToken(user) {
  return jwt.sign(
    { sub: user.id, org: user.organization_id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: ACCESS_EXPIRES }
  );
}

function generateRefreshToken(user) {
  return jwt.sign(
    { sub: user.id, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: REFRESH_EXPIRES }
  );
}

async function saveRefreshToken(userId, rawToken) {
  const hash = await bcrypt.hash(rawToken, 10);
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  await query(
    'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)',
    [userId, hash, expiresAt]
  );
}

async function rotateRefreshToken(rawToken) {
  let payload;
  try {
    payload = jwt.verify(rawToken, process.env.JWT_REFRESH_SECRET);
  } catch {
    throw Object.assign(new Error('Invalid refresh token'), { status: 401 });
  }

  // Find matching stored token
  const { rows } = await query(
    `SELECT id, token_hash, expires_at FROM refresh_tokens
     WHERE user_id = $1 AND expires_at > now()
     ORDER BY created_at DESC LIMIT 10`,
    [payload.sub]
  );

  let matched = null;
  for (const row of rows) {
    const ok = await bcrypt.compare(rawToken, row.token_hash);
    if (ok) { matched = row; break; }
  }

  if (!matched) {
    throw Object.assign(new Error('Refresh token not found or expired'), { status: 401 });
  }

  // Rotate: delete old, issue new
  await query('DELETE FROM refresh_tokens WHERE id = $1', [matched.id]);

  const { rows: userRows } = await query(
    'SELECT id, organization_id, role FROM users WHERE id = $1 AND is_active = true',
    [payload.sub]
  );
  if (!userRows.length) {
    throw Object.assign(new Error('User not found'), { status: 401 });
  }

  const user = userRows[0];
  const newAccess = generateAccessToken(user);
  const newRefresh = generateRefreshToken(user);
  await saveRefreshToken(user.id, newRefresh);

  return { accessToken: newAccess, refreshToken: newRefresh };
}

async function revokeAllTokens(userId) {
  await query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);
}

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  saveRefreshToken,
  rotateRefreshToken,
  revokeAllTokens,
};
