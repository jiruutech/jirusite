/**
 * Migration: Add Chapa payment fields to subscription_payments
 * Replaces the Telebirr integration with Chapa.
 */

exports.up = (pgm) => {
  // Add Chapa-specific columns to subscription_payments
  pgm.addColumns('subscription_payments', {
    chapa_tx_ref: { type: 'varchar(200)', unique: true },
    chapa_ref_id: { type: 'varchar(200)' },
    chapa_tier:   { type: 'varchar(30)' },
  });

  pgm.createIndex('subscription_payments', 'chapa_tx_ref');
};

exports.down = (pgm) => {
  pgm.dropIndex('subscription_payments', 'chapa_tx_ref');
  pgm.dropColumns('subscription_payments', ['chapa_tx_ref', 'chapa_ref_id', 'chapa_tier']);
};
