/**
 * JIRUSite — Initial database schema migration
 * Creates all core tables as defined in the product spec.
 */

exports.up = (pgm) => {
  // ── Enable pgcrypto for gen_random_uuid() ─────────────────────────────
  pgm.sql('CREATE EXTENSION IF NOT EXISTS "pgcrypto";');

  // ── organizations ──────────────────────────────────────────────────────
  pgm.createTable('organizations', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    name: { type: 'varchar(255)', notNull: true },
    tin_number: { type: 'varchar(50)' },
    subscription_tier: {
      type: 'varchar(20)',
      notNull: true,
      default: 'starter',
    },
    subscription_status: {
      type: 'varchar(20)',
      notNull: true,
      default: 'trial',
    },
    trial_ends_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
    updated_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── users ──────────────────────────────────────────────────────────────
  pgm.createTable('users', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    organization_id: {
      type: 'uuid',
      references: '"organizations"',
      onDelete: 'CASCADE',
    },
    full_name: { type: 'varchar(255)', notNull: true },
    phone_number: { type: 'varchar(20)', unique: true, notNull: true },
    email: { type: 'varchar(255)', unique: true },
    password_hash: { type: 'varchar(255)', notNull: true },
    role: { type: 'varchar(30)', notNull: true },
    preferred_language: { type: 'varchar(5)', default: "'am'" },
    is_active: { type: 'boolean', notNull: true, default: true },
    last_login_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
    updated_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── suppliers (defined before expenses/projects reference it) ─────────
  pgm.createTable('suppliers', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    name: { type: 'varchar(255)', notNull: true },
    phone_number: { type: 'varchar(20)' },
    location_text: { type: 'varchar(255)' },
    category: { type: 'varchar(50)' },
    is_verified: { type: 'boolean', default: false },
    verified_until: { type: 'date' },
    average_rating: { type: 'decimal(2,1)' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── projects ────────────────────────────────────────────────────────────
  pgm.createTable('projects', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    organization_id: {
      type: 'uuid',
      notNull: true,
      references: '"organizations"',
      onDelete: 'CASCADE',
    },
    name: { type: 'varchar(255)', notNull: true },
    location_text: { type: 'varchar(255)' },
    latitude: { type: 'decimal(10,7)' },
    longitude: { type: 'decimal(10,7)' },
    total_budget: { type: 'decimal(16,2)' },
    currency: { type: 'varchar(3)', notNull: true, default: "'ETB'" },
    start_date: { type: 'date' },
    target_end_date: { type: 'date' },
    status: { type: 'varchar(20)', notNull: true, default: "'active'" },
    created_by: { type: 'uuid', references: '"users"' },
    deleted_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
    updated_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── project_members ─────────────────────────────────────────────────────
  pgm.createTable('project_members', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    project_id: {
      type: 'uuid',
      notNull: true,
      references: '"projects"',
      onDelete: 'CASCADE',
    },
    user_id: {
      type: 'uuid',
      notNull: true,
      references: '"users"',
      onDelete: 'CASCADE',
    },
    role_on_project: { type: 'varchar(30)', notNull: true },
    added_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });
  pgm.addConstraint('project_members', 'project_members_project_user_unique', 'UNIQUE(project_id, user_id)');

  // ── cost_codes ──────────────────────────────────────────────────────────
  pgm.createTable('cost_codes', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    project_id: {
      type: 'uuid',
      notNull: true,
      references: '"projects"',
      onDelete: 'CASCADE',
    },
    code: { type: 'varchar(20)', notNull: true },
    name: { type: 'varchar(255)', notNull: true },
    budgeted_amount: { type: 'decimal(16,2)', notNull: true, default: 0 },
    parent_cost_code_id: { type: 'uuid', references: '"cost_codes"' },
    sort_order: { type: 'int', default: 0 },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── expenses ────────────────────────────────────────────────────────────
  pgm.createTable('expenses', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    project_id: {
      type: 'uuid',
      notNull: true,
      references: '"projects"',
      onDelete: 'CASCADE',
    },
    cost_code_id: { type: 'uuid', references: '"cost_codes"' },
    entered_by: {
      type: 'uuid',
      notNull: true,
      references: '"users"',
    },
    supplier_id: { type: 'uuid', references: '"suppliers"' },
    description: { type: 'text' },
    amount: { type: 'decimal(16,2)', notNull: true },
    quantity: { type: 'decimal(12,3)' },
    unit: { type: 'varchar(20)' },
    expense_type: { type: 'varchar(20)', notNull: true },
    receipt_photo_url: { type: 'text' },
    transaction_date: { type: 'date', notNull: true },
    sync_status: { type: 'varchar(20)', notNull: true, default: "'synced'" },
    client_generated_id: { type: 'uuid', unique: true },
    deleted_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
    updated_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── labor_entries ────────────────────────────────────────────────────────
  pgm.createTable('labor_entries', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    project_id: {
      type: 'uuid',
      notNull: true,
      references: '"projects"',
      onDelete: 'CASCADE',
    },
    cost_code_id: { type: 'uuid', references: '"cost_codes"' },
    entered_by: {
      type: 'uuid',
      notNull: true,
      references: '"users"',
    },
    worker_or_crew_name: { type: 'varchar(255)', notNull: true },
    work_description: { type: 'text' },
    number_of_workers: { type: 'int', default: 1 },
    daily_rate: { type: 'decimal(12,2)' },
    total_amount: { type: 'decimal(14,2)', notNull: true },
    work_date: { type: 'date', notNull: true },
    client_generated_id: { type: 'uuid', unique: true },
    sync_status: { type: 'varchar(20)', notNull: true, default: "'synced'" },
    deleted_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── materials ────────────────────────────────────────────────────────────
  pgm.createTable('materials', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    name: { type: 'varchar(255)', notNull: true },
    category: { type: 'varchar(50)', notNull: true },
    standard_unit: { type: 'varchar(20)', notNull: true },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── material_prices ──────────────────────────────────────────────────────
  pgm.createTable('material_prices', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    material_id: {
      type: 'uuid',
      notNull: true,
      references: '"materials"',
    },
    supplier_id: { type: 'uuid', references: '"suppliers"' },
    region: { type: 'varchar(100)', notNull: true },
    price: { type: 'decimal(12,2)', notNull: true },
    currency: { type: 'varchar(3)', notNull: true, default: "'ETB'" },
    source: { type: 'varchar(20)', notNull: true },
    reported_by: { type: 'uuid', references: '"users"' },
    observed_at: { type: 'date', notNull: true },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── quote_requests ───────────────────────────────────────────────────────
  pgm.createTable('quote_requests', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    project_id: { type: 'uuid', references: '"projects"' },
    requested_by: {
      type: 'uuid',
      notNull: true,
      references: '"users"',
    },
    material_id: { type: 'uuid', references: '"materials"' },
    quantity: { type: 'decimal(12,3)' },
    unit: { type: 'varchar(20)' },
    notes: { type: 'text' },
    status: { type: 'varchar(20)', notNull: true, default: "'open'" },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── quote_responses ──────────────────────────────────────────────────────
  pgm.createTable('quote_responses', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    quote_request_id: {
      type: 'uuid',
      notNull: true,
      references: '"quote_requests"',
      onDelete: 'CASCADE',
    },
    supplier_id: {
      type: 'uuid',
      notNull: true,
      references: '"suppliers"',
    },
    quoted_price: { type: 'decimal(12,2)', notNull: true },
    lead_fee_charged: { type: 'decimal(10,2)', default: 0 },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── purchase_orders ──────────────────────────────────────────────────────
  pgm.createTable('purchase_orders', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    project_id: {
      type: 'uuid',
      notNull: true,
      references: '"projects"',
      onDelete: 'CASCADE',
    },
    supplier_id: { type: 'uuid', references: '"suppliers"' },
    requested_by: {
      type: 'uuid',
      notNull: true,
      references: '"users"',
    },
    approved_by: { type: 'uuid', references: '"users"' },
    status: { type: 'varchar(20)', notNull: true, default: "'pending'" },
    total_amount: { type: 'decimal(16,2)' },
    notes: { type: 'text' },
    deleted_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
    approved_at: { type: 'timestamptz' },
  });

  // ── purchase_order_items ─────────────────────────────────────────────────
  pgm.createTable('purchase_order_items', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    purchase_order_id: {
      type: 'uuid',
      notNull: true,
      references: '"purchase_orders"',
      onDelete: 'CASCADE',
    },
    material_id: { type: 'uuid', references: '"materials"' },
    quantity: { type: 'decimal(12,3)', notNull: true },
    unit_price: { type: 'decimal(12,2)', notNull: true },
    line_total: { type: 'decimal(14,2)', notNull: true },
  });

  // ── schedule_tasks ───────────────────────────────────────────────────────
  pgm.createTable('schedule_tasks', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    project_id: {
      type: 'uuid',
      notNull: true,
      references: '"projects"',
      onDelete: 'CASCADE',
    },
    cost_code_id: { type: 'uuid', references: '"cost_codes"' },
    name: { type: 'varchar(255)', notNull: true },
    planned_start: { type: 'date' },
    planned_end: { type: 'date' },
    actual_start: { type: 'date' },
    actual_end: { type: 'date' },
    percent_complete: { type: 'int', default: 0 },
    status: { type: 'varchar(20)', default: "'not_started'" },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── subscription_payments ────────────────────────────────────────────────
  pgm.createTable('subscription_payments', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    organization_id: {
      type: 'uuid',
      notNull: true,
      references: '"organizations"',
      onDelete: 'CASCADE',
    },
    amount: { type: 'decimal(12,2)', notNull: true },
    currency: { type: 'varchar(3)', default: "'ETB'" },
    telebirr_transaction_id: { type: 'varchar(100)' },
    status: { type: 'varchar(20)', notNull: true, default: "'pending'" },
    billing_period_start: { type: 'date' },
    billing_period_end: { type: 'date' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── notifications ────────────────────────────────────────────────────────
  pgm.createTable('notifications', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    user_id: {
      type: 'uuid',
      notNull: true,
      references: '"users"',
      onDelete: 'CASCADE',
    },
    channel: { type: 'varchar(10)', notNull: true },
    title: { type: 'varchar(255)' },
    body: { type: 'text', notNull: true },
    is_read: { type: 'boolean', default: false },
    sent_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── audit_logs ───────────────────────────────────────────────────────────
  pgm.createTable('audit_logs', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    organization_id: { type: 'uuid', references: '"organizations"' },
    user_id: { type: 'uuid', references: '"users"' },
    entity_type: { type: 'varchar(50)', notNull: true },
    entity_id: { type: 'uuid', notNull: true },
    action: { type: 'varchar(20)', notNull: true },
    changes: { type: 'jsonb' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── refresh_tokens ───────────────────────────────────────────────────────
  pgm.createTable('refresh_tokens', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    user_id: {
      type: 'uuid',
      notNull: true,
      references: '"users"',
      onDelete: 'CASCADE',
    },
    token_hash: { type: 'varchar(255)', notNull: true },
    expires_at: { type: 'timestamptz', notNull: true },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── otp_codes ────────────────────────────────────────────────────────────
  pgm.createTable('otp_codes', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    phone_number: { type: 'varchar(20)', notNull: true },
    code_hash: { type: 'varchar(255)', notNull: true },
    purpose: { type: 'varchar(20)', notNull: true }, // verify, reset
    expires_at: { type: 'timestamptz', notNull: true },
    used_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── sync_conflicts (local conflicts from offline sync) ───────────────────
  // This is a server-side record of conflicts surfaced during sync
  pgm.createTable('sync_conflicts', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    organization_id: { type: 'uuid', references: '"organizations"' },
    user_id: { type: 'uuid', references: '"users"' },
    entity_type: { type: 'varchar(50)', notNull: true },
    client_generated_id: { type: 'uuid' },
    client_payload: { type: 'jsonb', notNull: true },
    server_payload: { type: 'jsonb' },
    resolution: { type: 'varchar(20)', default: "'server_wins'" },
    resolved_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  // ── Indexes (per spec section 3.2) ───────────────────────────────────────
  pgm.createIndex('expenses', ['project_id', 'transaction_date']);
  pgm.createIndex('expenses', ['client_generated_id']);
  pgm.createIndex('expenses', ['deleted_at']);
  pgm.createIndex('labor_entries', ['project_id', 'work_date']);
  pgm.createIndex('labor_entries', ['client_generated_id']);
  pgm.createIndex('material_prices', ['material_id', 'region', 'observed_at']);
  pgm.createIndex('users', ['phone_number']);
  pgm.createIndex('project_members', ['user_id']);
  pgm.createIndex('projects', ['organization_id']);
  pgm.createIndex('purchase_orders', ['project_id']);
  pgm.createIndex('purchase_orders', ['deleted_at']);
  pgm.createIndex('audit_logs', ['entity_type', 'entity_id']);
  pgm.createIndex('notifications', ['user_id', 'is_read']);
  pgm.createIndex('refresh_tokens', ['user_id']);
  pgm.createIndex('otp_codes', ['phone_number']);
};

exports.down = (pgm) => {
  pgm.dropTable('sync_conflicts');
  pgm.dropTable('otp_codes');
  pgm.dropTable('refresh_tokens');
  pgm.dropTable('audit_logs');
  pgm.dropTable('notifications');
  pgm.dropTable('subscription_payments');
  pgm.dropTable('schedule_tasks');
  pgm.dropTable('purchase_order_items');
  pgm.dropTable('purchase_orders');
  pgm.dropTable('quote_responses');
  pgm.dropTable('quote_requests');
  pgm.dropTable('material_prices');
  pgm.dropTable('materials');
  pgm.dropTable('labor_entries');
  pgm.dropTable('expenses');
  pgm.dropTable('cost_codes');
  pgm.dropTable('project_members');
  pgm.dropTable('projects');
  pgm.dropTable('suppliers');
  pgm.dropTable('users');
  pgm.dropTable('organizations');
};
