/**
 * Add updated_at to tables that were missing it.
 */
exports.up = (pgm) => {
  pgm.addColumn('purchase_orders', {
    updated_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });

  pgm.addColumn('labor_entries', {
    updated_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
};

exports.down = (pgm) => {
  pgm.dropColumn('purchase_orders', 'updated_at');
  pgm.dropColumn('labor_entries', 'updated_at');
};
