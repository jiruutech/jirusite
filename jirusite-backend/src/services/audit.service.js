const { query } = require('../db/pool');

/**
 * Write an audit log entry.
 * @param {object} opts
 * @param {string} opts.organizationId
 * @param {string} opts.userId
 * @param {string} opts.entityType  — e.g. 'expense'
 * @param {string} opts.entityId
 * @param {string} opts.action      — create | update | delete | approve
 * @param {object} [opts.changes]   — JSONB diff
 */
async function writeAudit({ organizationId, userId, entityType, entityId, action, changes }) {
  await query(
    `INSERT INTO audit_logs (organization_id, user_id, entity_type, entity_id, action, changes)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [organizationId, userId, entityType, entityId, action, changes ? JSON.stringify(changes) : null]
  );
}

module.exports = { writeAudit };
