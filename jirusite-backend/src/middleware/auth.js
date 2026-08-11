const jwt = require('jsonwebtoken');
const { query } = require('../db/pool');

/**
 * Verify the Bearer JWT and attach req.user = { id, organization_id, role }.
 */
async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.slice(7);
    const payload = jwt.verify(token, process.env.JWT_SECRET);

    // Confirm user still exists and is active
    const { rows } = await query(
      'SELECT id, organization_id, role, is_active FROM users WHERE id = $1',
      [payload.sub]
    );

    if (!rows.length || !rows[0].is_active) {
      return res.status(401).json({ error: 'User not found or deactivated' });
    }

    req.user = rows[0];
    next();
  } catch (err) {
    next(err);
  }
}

/**
 * Role-based guard. Pass an array of allowed roles.
 * Usage: authorize(['owner', 'admin'])
 */
function authorize(allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Not authenticated' });
    }
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

/**
 * Confirm that the project_id in params belongs to req.user.organization_id.
 * Attaches req.project for downstream use.
 */
async function scopeProject(req, res, next) {
  try {
    const projectId = req.params.id || req.params.projectId || req.body.project_id;
    if (!projectId) return next();

    const { rows } = await query(
      `SELECT id, organization_id, status FROM projects
       WHERE id = $1 AND deleted_at IS NULL`,
      [projectId]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'Project not found' });
    }

    if (rows[0].organization_id !== req.user.organization_id) {
      return res.status(403).json({ error: 'Access denied to this project' });
    }

    req.project = rows[0];
    next();
  } catch (err) {
    next(err);
  }
}

module.exports = { authenticate, authorize, scopeProject };
