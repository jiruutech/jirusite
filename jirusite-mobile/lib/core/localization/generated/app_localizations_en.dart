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
  String get materials => 'Materials';

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
  String get tigrinya => 'Tigrinya (ትግርኛ)';

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
  String get reportPrice => 'Report Price';

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
  String get percentComplete => '% complete';

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

  @override
  String get noOrganisation => 'No organisation set up';

  @override
  String get completeOrgSetup =>
      'Complete your organisation setup to get started';

  @override
  String get setUp => 'Set Up';

  @override
  String get activeProjects => 'Active Projects';

  @override
  String get portfolioHealth => 'Portfolio Health';

  @override
  String get thisMonth => 'This Month';

  @override
  String get all => 'All';

  @override
  String get active => 'Active';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get quickAdd => 'Quick Add';

  @override
  String get newExpenseShort => 'New Expense';

  @override
  String get laborEntryShort => 'Labour Entry';

  @override
  String get purchaseOrderShort => 'Purchase Order';

  @override
  String get spent => 'spent';

  @override
  String get outOf => 'of';

  @override
  String get completed => 'Completed';

  @override
  String get newProject => 'New Project';

  @override
  String get projectName => 'Project Name';

  @override
  String get totalBudgetEtb => 'Total Budget (ETB)';

  @override
  String get create => 'Create';

  @override
  String get noProjectsInFilter => 'No projects in this filter';

  @override
  String get createFirstProject =>
      'Create your first project to start tracking costs';

  @override
  String get project => 'Project';

  @override
  String get trendingOverBudget => 'Trending over budget';

  @override
  String get approachingBudgetLimit => 'Approaching budget limit';

  @override
  String get onTrack => 'On track';

  @override
  String get budget => 'Budget';

  @override
  String get overview => 'Overview';

  @override
  String get labour => 'Labour';

  @override
  String get team => 'Team';

  @override
  String get budgetByCostCode => 'Budget by Cost Code';

  @override
  String get sortedByVariance => 'Sorted by variance';

  @override
  String get seeAllActivity => 'See all activity';

  @override
  String get noRecentActivity => 'No recent activity';

  @override
  String get daysLeft => 'Days left';

  @override
  String get pendingSyncCount => 'Pending sync';

  @override
  String get loadingEllipsis => 'Loading…';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get noExpensesYet => 'No expenses yet';

  @override
  String get pendingSync => 'Pending sync';

  @override
  String get syncConflict => 'Sync conflict';

  @override
  String get saveExpense => 'Save Expense';

  @override
  String get expenseTypeCaps => 'Expense Type';

  @override
  String get amountRequired => 'Amount *';

  @override
  String get etb => 'ETB';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get unitLabel => 'Unit';

  @override
  String get select => 'Select';

  @override
  String get transactionDateRequired => 'Transaction Date *';

  @override
  String get enterValidAmount => 'Enter a valid amount';

  @override
  String get offlineWillSync =>
      'You\'re offline — expense will sync automatically when connected';

  @override
  String get expenseSavedSyncing => 'Expense saved & syncing';

  @override
  String get expenseSavedOffline => 'Expense saved — will sync when online';

  @override
  String get failedToSave => 'Failed to save';

  @override
  String get laborEntriesTitle => 'Labor Entries';

  @override
  String get addLabor => 'Add Labor';

  @override
  String get noLaborEntriesYet => 'No labor entries yet';

  @override
  String get addLaborEntry => 'Add Labor Entry';

  @override
  String get workersCount => 'workers';

  @override
  String get workerCrewNameRequired => 'Worker / Crew Name *';

  @override
  String get workerCrewPlaceholder => 'Rebar Crew (Gebru & team)';

  @override
  String get workDescriptionLabel => 'Work Description';

  @override
  String get workDescriptionPlaceholder =>
      'Foundation rebar installation, ground floor';

  @override
  String get workersLabel => 'Workers';

  @override
  String get dailyRateEtb => 'Daily Rate (ETB)';

  @override
  String get totalAmountEtb => 'Total Amount (ETB) *';

  @override
  String get workDateRequired => 'Work Date *';

  @override
  String get offlineWillSyncShort =>
      'You\'re offline — will sync when connected';

  @override
  String get enterTotalAmount => 'Enter total amount';

  @override
  String get saveLaborEntry => 'Save Labor Entry';

  @override
  String get laborEntrySaved => 'Labor entry saved & syncing';

  @override
  String get laborEntrySavedOffline =>
      'Labor entry saved — will sync when online';

  @override
  String get invalidNumber => 'Invalid';

  @override
  String get required => 'Required';

  @override
  String get hintQuantity => '0.0';

  @override
  String get hintDescription => 'e.g. Cement purchase — 50 quintals';

  @override
  String get back => 'Back';

  @override
  String get schedulePercentage => 'Schedule';

  @override
  String viewTab(String tab) {
    return 'View $tab';
  }

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String weeksAgo(int count) {
    return '${count}w ago';
  }

  @override
  String get markAllRead => 'Mark All Read';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get materialsAndPrices => 'Materials & Prices';

  @override
  String get searchMaterials => 'Search materials...';

  @override
  String get noMaterialsFound => 'No materials found';

  @override
  String get priceReportingComingSoon => 'Price reporting form — coming soon';

  @override
  String get currentPriceAddis => 'Current Price (Addis Ababa)';

  @override
  String get noPriceHistory => 'No price history yet for this region.';

  @override
  String get failedToLoadPrices => 'Failed to load prices';

  @override
  String get billingAndSubscription => 'Billing & Subscription';

  @override
  String get month => '/month';

  @override
  String upgradeTo(String tier) {
    return 'Upgrade to $tier';
  }

  @override
  String upgradeMessage(String amount) {
    return 'You will be charged $amount per month via Telebirr.';
  }

  @override
  String get telebirrInitiated =>
      'Telebirr payment initiated — check your phone';

  @override
  String get failed => 'Failed';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get starter => 'Starter';

  @override
  String get growth => 'Growth';

  @override
  String get professional => 'Professional';

  @override
  String get enterprise => 'Enterprise';

  @override
  String get trial => 'Trial';

  @override
  String get expired => 'Expired';

  @override
  String get supplierDirectory => 'Supplier Directory';

  @override
  String get searchSuppliers => 'Search suppliers...';

  @override
  String get noSuppliersFound => 'No suppliers found';

  @override
  String get call => 'Call';

  @override
  String get sms => 'SMS';

  @override
  String get newPO => 'New PO';

  @override
  String get noPurchaseOrders => 'No purchase orders';

  @override
  String get createPO => 'Create PO';

  @override
  String get addTask => 'Add Task';

  @override
  String get noTasksScheduled => 'No tasks scheduled yet';

  @override
  String get newTask => 'New Task';

  @override
  String get taskName => 'Task Name';

  @override
  String get add => 'Add';

  @override
  String get notStarted => 'Not Started';

  @override
  String get inProgress => 'In Progress';

  @override
  String get complete => 'Complete';

  @override
  String get delayed => 'Delayed';

  @override
  String get constructionCostTracking => 'Construction Cost Tracking';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInWithPhone => 'Sign in with your phone number';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String fieldRequired(String field) {
    return '$field is required';
  }

  @override
  String minCharacters(int count) {
    return 'Min $count characters';
  }

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get chooseYourLanguage => 'Choose Your Language';

  @override
  String changeLanguageLater(String settings) {
    return 'You can change this later in $settings.';
  }

  @override
  String get enterAllDigits => 'Enter all 6 digits';

  @override
  String get orgSetupTagline =>
      'This helps us tailor the app for your business.';

  @override
  String get organization => 'Organization';

  @override
  String get about => 'About';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String spentAmount(String amount) {
    return '$amount spent';
  }

  @override
  String ofAmount(String amount) {
    return 'of $amount';
  }

  @override
  String get newPurchaseOrder => 'New Purchase Order';

  @override
  String get lineItems => 'Line Items';

  @override
  String get addLineItem => 'Add Line Item';

  @override
  String get notes => 'Notes (optional)';

  @override
  String get total => 'Total';

  @override
  String get submitForApproval => 'Submit for Approval';

  @override
  String get poSubmitted => 'Purchase order submitted for approval';

  @override
  String itemNumber(int number) {
    return 'Item $number';
  }

  @override
  String get qty => 'Qty';

  @override
  String get unitPriceEtb => 'Unit Price (ETB)';

  @override
  String lineTotal(String amount) {
    return 'Line total: $amount';
  }

  @override
  String get receiptPhoto => 'Receipt Photo';

  @override
  String get tapToAddReceipt => 'Tap to add receipt photo';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get syncTriggered => 'Sync triggered';

  @override
  String get syncingEllipsis => 'Syncing...';

  @override
  String pendingCount(int count) {
    return '$count pending';
  }
}
