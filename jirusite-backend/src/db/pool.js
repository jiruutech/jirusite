const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  min: parseInt(process.env.DATABASE_POOL_MIN || '2', 10),
  max: parseInt(process.env.DATABASE_POOL_MAX || '10', 10),
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  // Neon (and most managed Postgres providers) require SSL in production.
  // The connection string already contains ?sslmode=require, but the pg
  // driver also needs ssl: { rejectUnauthorized: false } for Neon's certs.
  ...(process.env.NODE_ENV === 'production' && {
    ssl: { rejectUnauthorized: false },
  }),
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
});

/**
 * Execute a query with an optional array of parameter values.
 * Returns the pg QueryResult.
 */
async function query(text, params) {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  if (process.env.NODE_ENV === 'development') {
    console.debug('executed query', { text, duration, rows: res.rowCount });
  }
  return res;
}

/**
 * Acquire a client from the pool for a transaction.
 * Caller is responsible for client.release().
 */
async function getClient() {
  const client = await pool.connect();
  return client;
}

module.exports = { query, getClient, pool };
