require('dotenv').config();
const app = require('./app');
const { pool } = require('./db/pool');
const path = require('path');

const PORT = process.env.PORT || 3000;

async function runMigrations() {
  // node-pg-migrate is a CommonJS module
  const pgMigrate = require('node-pg-migrate').default || require('node-pg-migrate');
  await pgMigrate({
    databaseUrl: process.env.DATABASE_URL,
    migrationsTable: 'pgmigrations',
    dir: path.join(__dirname, '..', 'migrations'),
    direction: 'up',
    count: Infinity,
    log: (msg) => console.log('[migrate]', msg),
  });
}

async function start() {
  try {
    // Verify DB connectivity before accepting traffic
    await pool.query('SELECT 1');
    console.log('✅ PostgreSQL connected');

    // Auto-run any pending migrations on startup — safe to call repeatedly
    // because node-pg-migrate tracks applied migrations in pgmigrations table
    try {
      await runMigrations();
      console.log('✅ Migrations up to date');
    } catch (migErr) {
      console.error('⚠️  Migration error (non-fatal):', migErr.message);
      // Don't crash the server — the app can still serve existing tables
    }

    app.listen(PORT, () => {
      console.log(`🚀 JIRUSite API running on port ${PORT} [${process.env.NODE_ENV}]`);
    });

    // Keep Render free tier warm — ping /health every 14 minutes so the
    // server doesn't spin down and cause 30s cold starts on the mobile app.
    if (process.env.RENDER_EXTERNAL_URL) {
      const https = require('https');
      setInterval(() => {
        const url = `${process.env.RENDER_EXTERNAL_URL}/health`;
        https.get(url, (res) => {
          console.log(`[keep-warm] ${url} → ${res.statusCode}`);
        }).on('error', (e) => {
          console.warn('[keep-warm] ping failed:', e.message);
        });
      }, 14 * 60 * 1000); // 14 minutes
      console.log('🔁 Keep-warm pinger started');
    }
  } catch (err) {
    console.error('❌ Failed to start server:', err.message);
    process.exit(1);
  }
}

start();
