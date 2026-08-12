import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';
import 'app_localizations_om.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en'),
    Locale('om')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'JIRUSite'**
  String get appName;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get email;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerButton;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Verification Code'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}'**
  String otpSubtitle(String phone);

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @orgSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Up Your Organization'**
  String get orgSetupTitle;

  /// No description provided for @orgName.
  ///
  /// In en, this message translates to:
  /// **'Organization Name'**
  String get orgName;

  /// No description provided for @tinNumber.
  ///
  /// In en, this message translates to:
  /// **'TIN Number (optional)'**
  String get tinNumber;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @laborEntries.
  ///
  /// In en, this message translates to:
  /// **'Labor'**
  String get laborEntries;

  /// No description provided for @materials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materials;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// No description provided for @purchaseOrders.
  ///
  /// In en, this message translates to:
  /// **'Purchase Orders'**
  String get purchaseOrders;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @billing.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billing;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @newExpense.
  ///
  /// In en, this message translates to:
  /// **'New Expense'**
  String get newExpense;

  /// No description provided for @newLaborEntry.
  ///
  /// In en, this message translates to:
  /// **'New Labor Entry'**
  String get newLaborEntry;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount (ETB)'**
  String get amount;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @costCode.
  ///
  /// In en, this message translates to:
  /// **'Cost Code'**
  String get costCode;

  /// No description provided for @expenseType.
  ///
  /// In en, this message translates to:
  /// **'Expense Type'**
  String get expenseType;

  /// No description provided for @material.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get material;

  /// No description provided for @labor.
  ///
  /// In en, this message translates to:
  /// **'Labor'**
  String get labor;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplier;

  /// No description provided for @addReceipt.
  ///
  /// In en, this message translates to:
  /// **'Add Receipt Photo'**
  String get addReceipt;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String syncPending(int count);

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @totalBudget.
  ///
  /// In en, this message translates to:
  /// **'Total Budget'**
  String get totalBudget;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get totalSpent;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @budgetHealth.
  ///
  /// In en, this message translates to:
  /// **'Budget Health'**
  String get budgetHealth;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjects;

  /// No description provided for @noExpenses.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpenses;

  /// No description provided for @noLabor.
  ///
  /// In en, this message translates to:
  /// **'No labor entries yet'**
  String get noLabor;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorOccurred;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @amharic.
  ///
  /// In en, this message translates to:
  /// **'Amharic (አማርኛ)'**
  String get amharic;

  /// No description provided for @afaanOromo.
  ///
  /// In en, this message translates to:
  /// **'Afaan Oromo'**
  String get afaanOromo;

  /// No description provided for @tigrinya.
  ///
  /// In en, this message translates to:
  /// **'Tigrinya (ትግርኛ)'**
  String get tigrinya;

  /// No description provided for @workerName.
  ///
  /// In en, this message translates to:
  /// **'Worker / Crew Name'**
  String get workerName;

  /// No description provided for @numberOfWorkers.
  ///
  /// In en, this message translates to:
  /// **'Number of Workers'**
  String get numberOfWorkers;

  /// No description provided for @dailyRate.
  ///
  /// In en, this message translates to:
  /// **'Daily Rate (ETB)'**
  String get dailyRate;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount (ETB)'**
  String get totalAmount;

  /// No description provided for @workDate.
  ///
  /// In en, this message translates to:
  /// **'Work Date'**
  String get workDate;

  /// No description provided for @workDescription.
  ///
  /// In en, this message translates to:
  /// **'Work Description'**
  String get workDescription;

  /// No description provided for @currentPrice.
  ///
  /// In en, this message translates to:
  /// **'Current Price'**
  String get currentPrice;

  /// No description provided for @priceHistory.
  ///
  /// In en, this message translates to:
  /// **'Price History'**
  String get priceHistory;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @reportPrice.
  ///
  /// In en, this message translates to:
  /// **'Report a Price'**
  String get reportPrice;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @requestQuote.
  ///
  /// In en, this message translates to:
  /// **'Request Quote'**
  String get requestQuote;

  /// No description provided for @submitPO.
  ///
  /// In en, this message translates to:
  /// **'Submit Purchase Order'**
  String get submitPO;

  /// No description provided for @plannedStart.
  ///
  /// In en, this message translates to:
  /// **'Planned Start'**
  String get plannedStart;

  /// No description provided for @plannedEnd.
  ///
  /// In en, this message translates to:
  /// **'Planned End'**
  String get plannedEnd;

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'% Complete'**
  String get percentComplete;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @teamMembers.
  ///
  /// In en, this message translates to:
  /// **'Team Members'**
  String get teamMembers;

  /// No description provided for @inviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get inviteMember;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get currentPlan;

  /// No description provided for @upgradePlan.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Plan'**
  String get upgradePlan;

  /// No description provided for @payWithTelebirr.
  ///
  /// In en, this message translates to:
  /// **'Pay with Telebirr'**
  String get payWithTelebirr;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistory;

  /// No description provided for @formatEtb.
  ///
  /// In en, this message translates to:
  /// **'ETB {amount}'**
  String formatEtb(String amount);

  /// No description provided for @noOrganisation.
  ///
  /// In en, this message translates to:
  /// **'No organisation set up'**
  String get noOrganisation;

  /// No description provided for @completeOrgSetup.
  ///
  /// In en, this message translates to:
  /// **'Complete your organisation setup to get started'**
  String get completeOrgSetup;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set Up'**
  String get setUp;

  /// No description provided for @activeProjects.
  ///
  /// In en, this message translates to:
  /// **'Active Projects'**
  String get activeProjects;

  /// No description provided for @portfolioHealth.
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health'**
  String get portfolioHealth;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick Add'**
  String get quickAdd;

  /// No description provided for @newExpenseShort.
  ///
  /// In en, this message translates to:
  /// **'New Expense'**
  String get newExpenseShort;

  /// No description provided for @laborEntryShort.
  ///
  /// In en, this message translates to:
  /// **'Labour Entry'**
  String get laborEntryShort;

  /// No description provided for @purchaseOrderShort.
  ///
  /// In en, this message translates to:
  /// **'Purchase Order'**
  String get purchaseOrderShort;

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'spent'**
  String get spent;

  /// No description provided for @outOf.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get outOf;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get newProject;

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Project Name'**
  String get projectName;

  /// No description provided for @totalBudgetEtb.
  ///
  /// In en, this message translates to:
  /// **'Total Budget (ETB)'**
  String get totalBudgetEtb;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @noProjectsInFilter.
  ///
  /// In en, this message translates to:
  /// **'No projects in this filter'**
  String get noProjectsInFilter;

  /// No description provided for @createFirstProject.
  ///
  /// In en, this message translates to:
  /// **'Create your first project to start tracking costs'**
  String get createFirstProject;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @trendingOverBudget.
  ///
  /// In en, this message translates to:
  /// **'Trending over budget'**
  String get trendingOverBudget;

  /// No description provided for @approachingBudgetLimit.
  ///
  /// In en, this message translates to:
  /// **'Approaching budget limit'**
  String get approachingBudgetLimit;

  /// No description provided for @onTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get onTrack;

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @labour.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get labour;

  /// No description provided for @team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// No description provided for @budgetByCostCode.
  ///
  /// In en, this message translates to:
  /// **'Budget by Cost Code'**
  String get budgetByCostCode;

  /// No description provided for @sortedByVariance.
  ///
  /// In en, this message translates to:
  /// **'Sorted by variance'**
  String get sortedByVariance;

  /// No description provided for @seeAllActivity.
  ///
  /// In en, this message translates to:
  /// **'See all activity'**
  String get seeAllActivity;

  /// No description provided for @noRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get noRecentActivity;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'Days left'**
  String get daysLeft;

  /// No description provided for @pendingSyncCount.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get pendingSyncCount;

  /// No description provided for @loadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingEllipsis;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpense;

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpensesYet;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get pendingSync;

  /// No description provided for @syncConflict.
  ///
  /// In en, this message translates to:
  /// **'Sync conflict'**
  String get syncConflict;

  /// No description provided for @saveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save Expense'**
  String get saveExpense;

  /// No description provided for @expenseTypeCaps.
  ///
  /// In en, this message translates to:
  /// **'Expense Type'**
  String get expenseTypeCaps;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount *'**
  String get amountRequired;

  /// No description provided for @etb.
  ///
  /// In en, this message translates to:
  /// **'ETB'**
  String get etb;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @transactionDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Transaction Date *'**
  String get transactionDateRequired;

  /// No description provided for @enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get enterValidAmount;

  /// No description provided for @offlineWillSync.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — expense will sync automatically when connected'**
  String get offlineWillSync;

  /// No description provided for @expenseSavedSyncing.
  ///
  /// In en, this message translates to:
  /// **'Expense saved & syncing'**
  String get expenseSavedSyncing;

  /// No description provided for @expenseSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Expense saved — will sync when online'**
  String get expenseSavedOffline;

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get failedToSave;

  /// No description provided for @laborEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Labor Entries'**
  String get laborEntriesTitle;

  /// No description provided for @addLabor.
  ///
  /// In en, this message translates to:
  /// **'Add Labor'**
  String get addLabor;

  /// No description provided for @noLaborEntriesYet.
  ///
  /// In en, this message translates to:
  /// **'No labor entries yet'**
  String get noLaborEntriesYet;

  /// No description provided for @addLaborEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Labor Entry'**
  String get addLaborEntry;

  /// No description provided for @workersCount.
  ///
  /// In en, this message translates to:
  /// **'workers'**
  String get workersCount;

  /// No description provided for @workerCrewNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Worker / Crew Name *'**
  String get workerCrewNameRequired;

  /// No description provided for @workerCrewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Rebar Crew (Gebru & team)'**
  String get workerCrewPlaceholder;

  /// No description provided for @workDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Work Description'**
  String get workDescriptionLabel;

  /// No description provided for @workDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Foundation rebar installation, ground floor'**
  String get workDescriptionPlaceholder;

  /// No description provided for @workersLabel.
  ///
  /// In en, this message translates to:
  /// **'Workers'**
  String get workersLabel;

  /// No description provided for @dailyRateEtb.
  ///
  /// In en, this message translates to:
  /// **'Daily Rate (ETB)'**
  String get dailyRateEtb;

  /// No description provided for @totalAmountEtb.
  ///
  /// In en, this message translates to:
  /// **'Total Amount (ETB) *'**
  String get totalAmountEtb;

  /// No description provided for @workDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Work Date *'**
  String get workDateRequired;

  /// No description provided for @offlineWillSyncShort.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — will sync when connected'**
  String get offlineWillSyncShort;

  /// No description provided for @enterTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter total amount'**
  String get enterTotalAmount;

  /// No description provided for @saveLaborEntry.
  ///
  /// In en, this message translates to:
  /// **'Save Labor Entry'**
  String get saveLaborEntry;

  /// No description provided for @laborEntrySaved.
  ///
  /// In en, this message translates to:
  /// **'Labor entry saved & syncing'**
  String get laborEntrySaved;

  /// No description provided for @laborEntrySavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Labor entry saved — will sync when online'**
  String get laborEntrySavedOffline;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get invalidNumber;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en', 'om'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
    case 'om':
      return AppLocalizationsOm();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
