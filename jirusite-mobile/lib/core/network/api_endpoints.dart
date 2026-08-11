class ApiEndpoints {
  /// Base URL:
  ///   - Production (default): https://jirusite.onrender.com/api
  ///   - Local dev override: --dart-define=API_BASE_URL=http://localhost:3000/api
  ///   - Android emulator:   --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
  ///   - Android device:     --dart-define=API_BASE_URL=http://<your-ip>:3000/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://jirusite.onrender.com/api',
  );

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const refresh = '/auth/refresh';
  static const otpRequest = '/auth/otp/request';
  static const otpVerify = '/auth/otp/verify';
  static const logout = '/auth/logout';

  // ── Organizations ─────────────────────────────────────────────────────────
  static const orgMe = '/organizations/me';
  static const orgCreate = '/organizations';
  static const orgMembers = '/organizations/me/members';

  // ── Projects ──────────────────────────────────────────────────────────────
  static const projects = '/projects';
  static String projectById(String id) => '/projects/$id';
  static String projectDashboard(String id) => '/projects/$id/dashboard';
  static String projectCostCodes(String id) => '/projects/$id/cost-codes';
  static String projectTeam(String id) => '/projects/$id/team';

  // ── Expenses ──────────────────────────────────────────────────────────────
  static String projectExpenses(String id) => '/expenses/project/$id';
  static const expenseSyncBatch = '/expenses/sync-batch';
  static String expenseReceipt(String id) => '/expenses/$id/receipt';

  // ── Labor ─────────────────────────────────────────────────────────────────
  static String projectLabor(String id) => '/labor/project/$id';
  static const laborSyncBatch = '/labor/sync-batch';

  // ── Materials ─────────────────────────────────────────────────────────────
  static const materials = '/materials';
  static String materialById(String id) => '/materials/$id';
  static String materialPriceHistory(String id) => '/materials/$id/price-history';
  static const materialPrices = '/materials/prices';

  // ── Suppliers ─────────────────────────────────────────────────────────────
  static const suppliers = '/suppliers';
  static String supplierById(String id) => '/suppliers/$id';

  // ── Quotes ────────────────────────────────────────────────────────────────
  static const quoteRequests = '/quote-requests';
  static String quoteResponses(String id) => '/quote-requests/$id/responses';

  // ── Purchase Orders ───────────────────────────────────────────────────────
  static String projectPurchaseOrders(String id) =>
      '/purchase-orders/project/$id';
  static String approvePO(String id) => '/purchase-orders/$id/approve';

  // ── Schedule ──────────────────────────────────────────────────────────────
  static String projectSchedule(String id) => '/schedule/project/$id';
  static String scheduleTask(String id) => '/schedule-tasks/$id';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const notifications = '/notifications';
  static String markRead(String id) => '/notifications/$id/read';
  static const readAll = '/notifications/read-all';
  static const registerFcmToken = '/notifications/register-token';

  // ── Billing ───────────────────────────────────────────────────────────────
  static const subscription = '/billing/subscription';
  static const telebirrInitiate = '/billing/telebirr/initiate';
}
