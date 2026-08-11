const { validationResult } = require('express-validator');

/**
 * Runs after express-validator chains and returns 422 if any error exists.
 */
function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({ error: 'Validation failed', details: errors.array() });
  }
  next();
}

module.exports = { validate };
