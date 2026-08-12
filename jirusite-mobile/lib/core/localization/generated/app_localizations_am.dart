// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appName => 'ጂሩሳይት';

  @override
  String get login => 'ግባ';

  @override
  String get register => 'ምዝገባ';

  @override
  String get phoneNumber => 'ስልክ ቁጥር';

  @override
  String get password => 'የምስጢር ቁጥር';

  @override
  String get confirmPassword => 'የምስጢር ቁጥሩን አረጋግጥ';

  @override
  String get fullName => 'ሙሉ ስም';

  @override
  String get email => 'ኢሜይል (አማራጭ)';

  @override
  String get loginButton => 'ግባ';

  @override
  String get registerButton => 'አካውንት ፍጠር';

  @override
  String get otpTitle => 'የማረጋገጫ ኮድ አስገባ';

  @override
  String otpSubtitle(String phone) {
    return 'ወደ $phone 6-አሃዝ ኮድ ልከናል';
  }

  @override
  String get verify => 'አረጋግጥ';

  @override
  String get resendCode => 'ኮድ እንደገና ላክ';

  @override
  String get orgSetupTitle => 'ድርጅትዎን ያዋቅሩ';

  @override
  String get orgName => 'የድርጅት ስም';

  @override
  String get tinNumber => 'የቲን ቁጥር (አማራጭ)';

  @override
  String get continueButton => 'ቀጥል';

  @override
  String get dashboard => 'ዳሽቦርድ';

  @override
  String get projects => 'ፕሮጀክቶች';

  @override
  String get expenses => 'ወጪዎች';

  @override
  String get laborEntries => 'የሰው ኃይል';

  @override
  String get materials => 'ቁሳቁሶች';

  @override
  String get suppliers => 'አቅራቢዎች';

  @override
  String get purchaseOrders => 'የግዢ ትዕዛዞች';

  @override
  String get schedule => 'የጊዜ ሰሌዳ';

  @override
  String get notifications => 'ማሳወቂያዎች';

  @override
  String get billing => 'ክፍያ';

  @override
  String get settings => 'ቅንብሮች';

  @override
  String get newExpense => 'አዲስ ወጪ';

  @override
  String get newLaborEntry => 'አዲስ የሠራተኛ ግቤት';

  @override
  String get amount => 'መጠን (ብር)';

  @override
  String get description => 'መግለጫ';

  @override
  String get date => 'ቀን';

  @override
  String get costCode => 'የወጪ ኮድ';

  @override
  String get expenseType => 'የወጪ ዓይነት';

  @override
  String get material => 'ቁሳቁስ';

  @override
  String get labor => 'የሰው ኃይል';

  @override
  String get equipment => 'መሳሪያ';

  @override
  String get other => 'ሌላ';

  @override
  String get quantity => 'ብዛት';

  @override
  String get unit => 'ክፍል';

  @override
  String get supplier => 'አቅራቢ';

  @override
  String get addReceipt => 'የደረሰኝ ፎቶ ጨምር';

  @override
  String get save => 'አስቀምጥ';

  @override
  String get cancel => 'ሰርዝ';

  @override
  String get delete => 'አጥፋ';

  @override
  String get approve => 'ፍቀድ';

  @override
  String get reject => 'አሳፍር';

  @override
  String get pending => 'በመጠባበቅ ላይ';

  @override
  String get approved => 'ፀድቋል';

  @override
  String get synced => 'ተመሳስሏል';

  @override
  String syncPending(int count) {
    return '$count በመጠባበቅ';
  }

  @override
  String get syncing => 'በመመሳሰል ላይ...';

  @override
  String get totalBudget => 'ጠቅላላ በጀት';

  @override
  String get totalSpent => 'ጠቅላላ ወጪ';

  @override
  String get remaining => 'የቀረው';

  @override
  String get budgetHealth => 'የበጀት ሁኔታ';

  @override
  String get recentActivity => 'የቅርብ ጊዜ እንቅስቃሴ';

  @override
  String get noProjects => 'ምንም ፕሮጀክት የለም';

  @override
  String get noExpenses => 'ምንም ወጪ የለም';

  @override
  String get noLabor => 'ምንም የሰው ኃይል ግቤት የለም';

  @override
  String get loading => 'በመጫን ላይ...';

  @override
  String get errorOccurred => 'ስህተት ተፈጥሯል';

  @override
  String get retry => 'እንደገና ሞክር';

  @override
  String get logout => 'ውጣ';

  @override
  String get language => 'ቋንቋ';

  @override
  String get english => 'English';

  @override
  String get amharic => 'አማርኛ';

  @override
  String get afaanOromo => 'Afaan Oromo';

  @override
  String get tigrinya => 'ትግርኛ';

  @override
  String get workerName => 'ሠራተኛ / ቡድን ስም';

  @override
  String get numberOfWorkers => 'የሠራተኞች ቁጥር';

  @override
  String get dailyRate => 'ዕለታዊ ክፍያ (ብር)';

  @override
  String get totalAmount => 'ጠቅላላ መጠን (ብር)';

  @override
  String get workDate => 'የሥራ ቀን';

  @override
  String get workDescription => 'የሥራ መግለጫ';

  @override
  String get currentPrice => 'አሁናዊ ዋጋ';

  @override
  String get priceHistory => 'ዋጋ ታሪክ';

  @override
  String get region => 'ክልል';

  @override
  String get reportPrice => 'ዋጋ ዘግብ';

  @override
  String get verified => 'የተረጋገጠ';

  @override
  String get requestQuote => 'ዋጋ ጠይቅ';

  @override
  String get submitPO => 'የግዢ ትዕዛዝ አስቀምጥ';

  @override
  String get plannedStart => 'የታቀደ መጀመሪያ';

  @override
  String get plannedEnd => 'የታቀደ ፍጻሜ';

  @override
  String get percentComplete => '% ተጠናቋል';

  @override
  String get status => 'ሁኔታ';

  @override
  String get teamMembers => 'የቡድን አባላት';

  @override
  String get inviteMember => 'አባል ጋብዝ';

  @override
  String get subscription => 'ደንበኝነት';

  @override
  String get currentPlan => 'አሁናዊ ዕቅድ';

  @override
  String get upgradePlan => 'ዕቅድ አሻሽል';

  @override
  String get payWithTelebirr => 'ተሌቢር ይክፈሉ';

  @override
  String get paymentHistory => 'የክፍያ ታሪክ';

  @override
  String formatEtb(String amount) {
    return 'ብር $amount';
  }

  @override
  String get noOrganisation => 'ድርጅት አልተዘጋጀም';

  @override
  String get completeOrgSetup => 'ለመጀመር የድርጅትዎን ማዋቀር ያጠናቅቁ';

  @override
  String get setUp => 'አዋቅር';

  @override
  String get activeProjects => 'ንቁ ፕሮጀክቶች';

  @override
  String get portfolioHealth => 'የፕሮጀክቶች ጤንነት';

  @override
  String get thisMonth => 'ይህን ወር';

  @override
  String get all => 'ሁሉም';

  @override
  String get active => 'ንቁ';

  @override
  String get needsAttention => 'ትኩረት ያስፈልጋል';

  @override
  String get quickAdd => 'ፈጣን ጨምር';

  @override
  String get newExpenseShort => 'አዲስ ወጪ';

  @override
  String get laborEntryShort => 'የሠራተኛ ግቤት';

  @override
  String get purchaseOrderShort => 'የግዥ ትዕዛዝ';

  @override
  String get spent => 'ወጪ';

  @override
  String get outOf => 'ከ';

  @override
  String get completed => 'ተጠናቅቋል';

  @override
  String get newProject => 'አዲስ ፕሮጀክት';

  @override
  String get projectName => 'የፕሮጀክት ስም';

  @override
  String get totalBudgetEtb => 'ጠቅላላ በጀት (ብር)';

  @override
  String get create => 'ፍጠር';

  @override
  String get noProjectsInFilter => 'በዚህ ማጣሪያ ውስጥ ፕሮጀክቶች የሉም';

  @override
  String get createFirstProject => 'ወጪዎችን ለመከታተል የመጀመሪያ ፕሮጀክትዎን ይፍጠሩ';

  @override
  String get project => 'ፕሮጀክት';

  @override
  String get trendingOverBudget => 'ከበጀት በላይ እየሆነ ነው';

  @override
  String get approachingBudgetLimit => 'የበጀት ገደብ እየቀረበ ነው';

  @override
  String get onTrack => 'በትክክለኛው መንገድ ላይ';

  @override
  String get budget => 'በጀት';

  @override
  String get overview => 'አጠቃላይ እይታ';

  @override
  String get labour => 'ሠራተኞች';

  @override
  String get team => 'ቡድን';

  @override
  String get budgetByCostCode => 'በወጪ ኮድ በጀት';

  @override
  String get sortedByVariance => 'በልዩነት ተለይቷል';

  @override
  String get seeAllActivity => 'ሁሉንም እንቅስቃሴ ይመልከቱ';

  @override
  String get noRecentActivity => 'የቅርብ ጊዜ እንቅስቃሴ የለም';

  @override
  String get daysLeft => 'የቀሩ ቀናት';

  @override
  String get pendingSyncCount => 'መመሳሰል በመጠባበቅ ላይ';

  @override
  String get loadingEllipsis => 'በመጫን ላይ…';

  @override
  String get addExpense => 'ወጪ ጨምር';

  @override
  String get noExpensesYet => 'ወጪዎች የሉም';

  @override
  String get pendingSync => 'መመሳሰል በመጠባበቅ ላይ';

  @override
  String get syncConflict => 'የመመሳሰል ግጭት';

  @override
  String get saveExpense => 'ወጪን አስቀምጥ';

  @override
  String get expenseTypeCaps => 'የወጪ አይነት';

  @override
  String get amountRequired => 'መጠን *';

  @override
  String get etb => 'ብር';

  @override
  String get quantityLabel => 'ብዛት';

  @override
  String get unitLabel => 'አሃድ';

  @override
  String get select => 'ምረጥ';

  @override
  String get transactionDateRequired => 'የግብይት ቀን *';

  @override
  String get enterValidAmount => 'ትክክለኛ መጠን ያስገቡ';

  @override
  String get offlineWillSync => 'ከመስመር ውጭ ነዎት — ወጪው ሲገናኙ በራስሰር ይመሳሰላል';

  @override
  String get expenseSavedSyncing => 'ወጪ ተቀምጧል እና እየተመሳሰለ ነው';

  @override
  String get expenseSavedOffline => 'ወጪ ተቀምጧል — ሲገናኙ ይመሳሰላል';

  @override
  String get failedToSave => 'ማስቀመጥ አልተሳካም';

  @override
  String get laborEntriesTitle => 'የሠራተኛ ግቤቶች';

  @override
  String get addLabor => 'ሠራተኛ ጨምር';

  @override
  String get noLaborEntriesYet => 'የሠራተኛ ግቤቶች የሉም';

  @override
  String get addLaborEntry => 'የሠራተኛ ግቤት ጨምር';

  @override
  String get workersCount => 'ሠራተኞች';

  @override
  String get workerCrewNameRequired => 'ሠራተኛ / የቡድን ስም *';

  @override
  String get workerCrewPlaceholder => 'የብረት ቡድን (ገብሩ እና ቡድን)';

  @override
  String get workDescriptionLabel => 'የሥራ መግለጫ';

  @override
  String get workDescriptionPlaceholder => 'የመሠረት ብረት መትከል፣ የመሬት ወለል';

  @override
  String get workersLabel => 'ሠራተኞች';

  @override
  String get dailyRateEtb => 'ዕለታዊ ክፍያ (ብር)';

  @override
  String get totalAmountEtb => 'ጠቅላላ መጠን (ብር) *';

  @override
  String get workDateRequired => 'የሥራ ቀን *';

  @override
  String get offlineWillSyncShort => 'ከመስመር ውጭ ነዎት — ሲገናኙ ይመሳሰላል';

  @override
  String get enterTotalAmount => 'ጠቅላላ መጠን ያስገቡ';

  @override
  String get saveLaborEntry => 'የሠራተኛ ግቤት አስቀምጥ';

  @override
  String get laborEntrySaved => 'የሠራተኛ ግቤት ተቀምጧል እና እየተመሳሰለ ነው';

  @override
  String get laborEntrySavedOffline => 'የሠራተኛ ግቤት ተቀምጧል — ሲገናኙ ይመሳሰላል';

  @override
  String get invalidNumber => 'ልክ ያልሆነ';

  @override
  String get required => 'ያስፈልጋል';
}
