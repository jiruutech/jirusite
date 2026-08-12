const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const authRoutes = require('./routes/auth.routes');
const organizationRoutes = require('./routes/organization.routes');
const projectRoutes = require('./routes/project.routes');
const expenseRoutes = require('./routes/expense.routes');
const laborRoutes = require('./routes/labor.routes');
const materialRoutes = require('./routes/material.routes');
const supplierRoutes = require('./routes/supplier.routes');
const quoteRoutes = require('./routes/quote.routes');
const purchaseOrderRoutes = require('./routes/purchaseOrder.routes');
const scheduleRoutes = require('./routes/schedule.routes');
const notificationRoutes = require('./routes/notification.routes');
const billingRoutes = require('./routes/billing.routes');

const { errorHandler } = require('./middleware/errorHandler');

const app = express();

// ── Security & parsing middleware ──────────────────────────────────────────
app.use(helmet());
app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (native mobile apps, Postman, curl)
      if (!origin) return callback(null, true);

      const allowed = (process.env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);

      // Always allow localhost in development
      const isLocalhost =
        origin.includes('localhost') || origin.includes('127.0.0.1');

      // Always allow localhost regardless of env — Flutter web dev runs on
      // random high ports (e.g. localhost:53487) and the port changes each run.
      if (isLocalhost) return callback(null, true);

      if (allowed.includes(origin)) return callback(null, true);

      callback(new Error(`CORS: origin ${origin} not allowed`));
    },
    credentials: true,
  })
);
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('combined'));
}

// ── Global rate limiter ────────────────────────────────────────────────────
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 500,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
});
app.use('/api', globalLimiter);

// ── Auth rate limiter (tighter) ────────────────────────────────────────────
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many authentication attempts.' },
});

// ── Health check ───────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// ── Routes ─────────────────────────────────────────────────────────────────
app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/organizations', organizationRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/expenses', expenseRoutes);
app.use('/api/labor', laborRoutes);
app.use('/api/materials', materialRoutes);
app.use('/api/material-prices', materialRoutes);
app.use('/api/suppliers', supplierRoutes);
app.use('/api/quote-requests', quoteRoutes);
app.use('/api/purchase-orders', purchaseOrderRoutes);
app.use('/api/schedule', scheduleRoutes);
app.use('/api/schedule-tasks', scheduleRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/billing', billingRoutes);

// ── 404 handler ────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// ── Global error handler ───────────────────────────────────────────────────
app.use(errorHandler);

module.exports = app;
