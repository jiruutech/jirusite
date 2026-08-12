// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'JIRUSite';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get email => 'Email (optional)';

  @override
  String get loginButton => 'Login';

  @override
  String get registerButton => 'Create Account';

  @override
  String get otpTitle => 'Enter Verification Code';

  @override
  String otpSubtitle(String phone) {
    return 'We sent a 6-digit code to $phone';
  }

  @override
  String get verify => 'Verify';

  @override
  String get resendCode => 'Resend Code';

  @override
  String get orgSetupTitle => 'Set Up Your Organization';

  @override
  String get orgName => 'Organization Name';

  @override
  String get tinNumber => 'TIN Number (optional)';

  @override
  String get continueButton => 'Continue';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get projects => 'Projects';

  @override
  String get expenses => 'Expenses';

  @override
  String get laborEntries => 'Labor';

  @override
  String get materials => 'Materials & Prices';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get purchaseOrders => 'Purchase Orders';

  @override
  String get schedule => 'Schedule';

  @override
  String get notifications => 'Notifications';

  @override
  String get billing => 'Billing';

  @override
  String get settings => 'Settings';

  @override
  String get newExpense => 'New Expense';

  @override
  String get newLaborEntry => 'New Labor Entry';

  @override
  String get amount => 'Amount (ETB)';

  @override
  String get description => 'Description';

  @override
  String get date => 'Date';

  @override
  String get costCode => 'Cost Code';

  @override
  String get expenseType => 'Expense Type';

  @override
  String get material => 'Material';

  @override
  String get labor => 'Labor';

  @override
  String get equipment => 'Equipment';

  @override
  String get other => 'Other';

  @override
  String get quantity => 'Quantity';

  @override
  String get unit => 'Unit';

  @override
  String get supplier => 'Supplier';

  @override
  String get addReceipt => 'Add Receipt Photo';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get pending => 'Pending';

  @override
  String get approved => 'Approved';

  @override
  String get synced => 'Synced';

  @override
  String syncPending(int count) {
    return '$count pending';
  }

  @override
  String get syncing => 'Syncing...';

  @override
  String get totalBudget => 'Total Budget';

  @override
  String get totalSpent => 'Total Spent';

  @override
  String get remaining => 'Remaining';

  @override
  String get budgetHealth => 'Budget Health';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get noProjects => 'No projects yet';

  @override
  String get noExpenses => 'No expenses yet';

  @override
  String get noLabor => 'No labor entries yet';

  @override
  String get loading => 'Loading...';

  @override
  String get errorOccurred => 'Something went wrong';

  @override
  String get retry => 'Retry';

  @override
  String get logout => 'Logout';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get amharic => 'Amharic (አማርኛ)';

  @override
  String get afaanOromo => 'Afaan Oromo';

  @override
  String get workerName => 'Worker / Crew Name';

  @override
  String get numberOfWorkers => 'Number of Workers';

  @override
  String get dailyRate => 'Daily Rate (ETB)';

  @override
  String get totalAmount => 'Total Amount (ETB)';

  @override
  String get workDate => 'Work Date';

  @override
  String get workDescription => 'Work Description';

  @override
  String get currentPrice => 'Current Price';

  @override
  String get priceHistory => 'Price History';

  @override
  String get region => 'Region';

  @override
  String get reportPrice => 'Report a Price';

  @override
  String get verified => 'Verified';

  @override
  String get requestQuote => 'Request Quote';

  @override
  String get submitPO => 'Submit Purchase Order';

  @override
  String get plannedStart => 'Planned Start';

  @override
  String get plannedEnd => 'Planned End';

  @override
  String get percentComplete => '% Complete';

  @override
  String get status => 'Status';

  @override
  String get teamMembers => 'Team Members';

  @override
  String get inviteMember => 'Invite Member';

  @override
  String get subscription => 'Subscription';

  @override
  String get currentPlan => 'Current Plan';

  @override
  String get upgradePlan => 'Upgrade Plan';

  @override
  String get payWithTelebirr => 'Pay with Telebirr';

  @override
  String get paymentHistory => 'Payment History';

  @override
  String formatEtb(String amount) {
    return 'ETB $amount';
  }
}
