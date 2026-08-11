/**
 * Centralized error handler.
 * Express expects 4-argument middleware to be treated as error handlers.
 */
function errorHandler(err, req, res, _next) {
  // Validation errors from express-validator (thrown manually as 422)
  if (err.type === 'validation') {
    return res.status(422).json({ error: 'Validation failed', details: err.errors });
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({ error: 'Invalid token' });
  }
  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({ error: 'Token expired' });
  }

  // pg unique violation
  if (err.code === '23505') {
    return res.status(409).json({ error: 'Duplicate entry', detail: err.detail });
  }

  // pg foreign key violation
  if (err.code === '23503') {
    return res.status(400).json({ error: 'Referenced record not found', detail: err.detail });
  }

  const status = err.status || err.statusCode || 500;
  const message = err.message || 'Internal server error';

  if (status >= 500) {
    console.error('[ERROR]', err);
  }

  res.status(status).json({ error: message });
}

/**
 * Wrap an async route handler so that thrown errors are forwarded to errorHandler.
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

module.exports = { errorHandler, asyncHandler };
