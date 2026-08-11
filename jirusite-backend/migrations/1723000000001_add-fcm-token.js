/**
 * Add FCM token column to users table for push notification targeting.
 */
exports.up = (pgm) => {
  pgm.addColumn('users', {
    fcm_token: { type: 'varchar(255)' },
  });
};

exports.down = (pgm) => {
  pgm.dropColumn('users', 'fcm_token');
};
