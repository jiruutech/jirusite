// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Oromo (`om`).
class AppLocalizationsOm extends AppLocalizations {
  AppLocalizationsOm([String locale = 'om']) : super(locale);

  @override
  String get appName => 'JIRUSite';

  @override
  String get login => 'Seeni';

  @override
  String get register => 'Galmaa\'i';

  @override
  String get phoneNumber => 'Lakkoofsa Bilbilaa';

  @override
  String get password => 'Jecha Darbii';

  @override
  String get confirmPassword => 'Jecha Darbii Mirkaneessi';

  @override
  String get fullName => 'Maqaa Guutuu';

  @override
  String get email => 'Imeelii (dirqama miti)';

  @override
  String get loginButton => 'Seeni';

  @override
  String get registerButton => 'Herreegaa Bani';

  @override
  String get otpTitle => 'Koodii Mirkaneessaa Galchi';

  @override
  String otpSubtitle(String phone) {
    return 'Koodii lakkoofsa 6 $phone ergine';
  }

  @override
  String get verify => 'Mirkaneessi';

  @override
  String get resendCode => 'Koodii Irra Ergi';

  @override
  String get orgSetupTitle => 'Dhaabbata Kee Qindeessi';

  @override
  String get orgName => 'Maqaa Dhaabbataa';

  @override
  String get tinNumber => 'Lakkoofsa TIN (dirqama miti)';

  @override
  String get continueButton => 'Itti Fufi';

  @override
  String get dashboard => 'Gabatee';

  @override
  String get projects => 'Pirojektiwwan';

  @override
  String get expenses => 'Baasii';

  @override
  String get laborEntries => 'Hojjettoota';

  @override
  String get materials => 'Meeshaalee';

  @override
  String get suppliers => 'Dhiyeessitootaa';

  @override
  String get purchaseOrders => 'Ajaja Bitachuu';

  @override
  String get schedule => 'Sagantaa';

  @override
  String get notifications => 'Beeksisawwan';

  @override
  String get billing => 'Kaffaltii';

  @override
  String get settings => 'Qindaa\'inaa';

  @override
  String get newExpense => 'Baasii Haaraa';

  @override
  String get newLaborEntry => 'Galma Hojjettoo Haaraa';

  @override
  String get amount => 'Baasii (ETB)';

  @override
  String get description => 'Ibsa';

  @override
  String get date => 'Guyyaa';

  @override
  String get costCode => 'Koodii Baasii';

  @override
  String get expenseType => 'Gosa Baasii';

  @override
  String get material => 'Meeshaa';

  @override
  String get labor => 'Hojjettoo';

  @override
  String get equipment => 'Meeshaa Hojii';

  @override
  String get other => 'Kan Biraa';

  @override
  String get quantity => 'Baay\'ina';

  @override
  String get unit => 'Lakkoofsa';

  @override
  String get supplier => 'Dhiyeessituu';

  @override
  String get addReceipt => 'Suuraa Rasiidhaa Dabaluu';

  @override
  String get save => 'Olkaa\'i';

  @override
  String get cancel => 'Dhiisi';

  @override
  String get delete => 'Haqi';

  @override
  String get approve => 'Hayyami';

  @override
  String get reject => 'Didi';

  @override
  String get pending => 'Eeggachaa';

  @override
  String get approved => 'Hayyamameera';

  @override
  String get synced => 'Walmadaalee';

  @override
  String syncPending(int count) {
    return '$count eeggachaa';
  }

  @override
  String get syncing => 'Walmadaallaa...';

  @override
  String get totalBudget => 'Bajatii Walii Galaa';

  @override
  String get totalSpent => 'Waliigala Bahe';

  @override
  String get remaining => 'Hafee';

  @override
  String get budgetHealth => 'Fayyaa Bajataa';

  @override
  String get recentActivity => 'Hojii Dhiyoo';

  @override
  String get noProjects => 'Pirojektiin hin jiru';

  @override
  String get noExpenses => 'Baasiin hin jiru';

  @override
  String get noLabor => 'Galma hojjettoo hin jiru';

  @override
  String get loading => 'Fe\'aa jira...';

  @override
  String get errorOccurred => 'Dogoggorri uumame';

  @override
  String get retry => 'Irra deebi\'i yaali';

  @override
  String get logout => 'Bahi';

  @override
  String get language => 'Afaan';

  @override
  String get english => 'English';

  @override
  String get amharic => 'Amharic (አማርኛ)';

  @override
  String get afaanOromo => 'Afaan Oromo';

  @override
  String get tigrinya => 'Tigrinya (ትግርኛ)';

  @override
  String get workerName => 'Maqaa Hojjettoo / Garee';

  @override
  String get numberOfWorkers => 'Lakkoofsa Hojjettootaa';

  @override
  String get dailyRate => 'Kaffaltii Guyyaa (ETB)';

  @override
  String get totalAmount => 'Baasii Waliigalaa (ETB)';

  @override
  String get workDate => 'Guyyaa Hojii';

  @override
  String get workDescription => 'Ibsa Hojii';

  @override
  String get currentPrice => 'Gatii Ammaa';

  @override
  String get priceHistory => 'Seenaa Gatii';

  @override
  String get region => 'Godinaa';

  @override
  String get reportPrice => 'Gatii Gabaasi';

  @override
  String get verified => 'Mirkanaa\'e';

  @override
  String get requestQuote => 'Gatii Gaafadhu';

  @override
  String get submitPO => 'Ajaja Bitachuu Ergi';

  @override
  String get plannedStart => 'Jalqaba Karoorfame';

  @override
  String get plannedEnd => 'Xumura Karoorfame';

  @override
  String get percentComplete => '% xumurame';

  @override
  String get status => 'Haala';

  @override
  String get teamMembers => 'Miseensota Garee';

  @override
  String get inviteMember => 'Miseensa Affeeri';

  @override
  String get subscription => 'Miseensummaa';

  @override
  String get currentPlan => 'Karoora Ammaa';

  @override
  String get upgradePlan => 'Karoora Fooyi\'i';

  @override
  String get payWithTelebirr => 'Telebirr Itti Kafali';

  @override
  String get paymentHistory => 'Seenaa Kaffaltii';

  @override
  String formatEtb(String amount) {
    return 'ETB $amount';
  }

  @override
  String get noOrganisation => 'Dhaabbanni hin jiru';

  @override
  String get completeOrgSetup => 'Jalqabuuf dhaabbata kee qindeessi';

  @override
  String get setUp => 'Qindeessi';

  @override
  String get activeProjects => 'Pirojektiwwan Socho\'aa';

  @override
  String get portfolioHealth => 'Fayyaa Pirojektiwwanii';

  @override
  String get thisMonth => 'Ji\'a Kana';

  @override
  String get all => 'Hunda';

  @override
  String get active => 'Socho\'aa';

  @override
  String get needsAttention => 'Xiyyeeffannoo barbaada';

  @override
  String get quickAdd => 'Saffisaan Dabali';

  @override
  String get newExpenseShort => 'Baasii Haaraa';

  @override
  String get laborEntryShort => 'Galma Hojjettoo';

  @override
  String get purchaseOrderShort => 'Ajaja Bitachuu';

  @override
  String get spent => 'bahe';

  @override
  String get outOf => 'irraa';

  @override
  String get completed => 'Xumurameera';

  @override
  String get newProject => 'Pirojektii Haaraa';

  @override
  String get projectName => 'Maqaa Pirojektii';

  @override
  String get totalBudgetEtb => 'Bajatii Waliigalaa (ETB)';

  @override
  String get create => 'Uumi';

  @override
  String get noProjectsInFilter => 'Pirojektiin filannoo kana keessa hin jiru';

  @override
  String get createFirstProject =>
      'Baasii hordofuuf pirojektii kee jalqabaa uumi';

  @override
  String get project => 'Pirojektii';

  @override
  String get trendingOverBudget => 'Bajatii ol ta\'aa jira';

  @override
  String get approachingBudgetLimit => 'Daangaa bajaatii bira ga\'aa jira';

  @override
  String get onTrack => 'Karaa sirrii irra jira';

  @override
  String get budget => 'Bajatii';

  @override
  String get overview => 'Waliigala';

  @override
  String get labour => 'Hojjettoota';

  @override
  String get team => 'Garee';

  @override
  String get budgetByCostCode => 'Bajatii Koodii Baasiin';

  @override
  String get sortedByVariance => 'Jijjiiramaan tartiibame';

  @override
  String get seeAllActivity => 'Hojii hunda ilaali';

  @override
  String get noRecentActivity => 'Hojiin dhiyoo hin jiru';

  @override
  String get daysLeft => 'Guyyoonni hafan';

  @override
  String get pendingSyncCount => 'Walmadaaluu eeggachaa';

  @override
  String get loadingEllipsis => 'Fe\'aa jira…';

  @override
  String get addExpense => 'Baasii Dabaluu';

  @override
  String get noExpensesYet => 'Baasiin hin jiru';

  @override
  String get pendingSync => 'Walmadaaluu eeggachaa';

  @override
  String get syncConflict => 'Waldorgommii walmadaallii';

  @override
  String get saveExpense => 'Baasii Olkaa\'i';

  @override
  String get expenseTypeCaps => 'Gosa Baasii';

  @override
  String get amountRequired => 'Baasii *';

  @override
  String get etb => 'ETB';

  @override
  String get quantityLabel => 'Baay\'ina';

  @override
  String get unitLabel => 'Lakkoofsa';

  @override
  String get select => 'Filadhu';

  @override
  String get transactionDateRequired => 'Guyyaa Daldalaa *';

  @override
  String get enterValidAmount => 'Baasii sirrii galchi';

  @override
  String get offlineWillSync =>
      'Toora ala jirta — baasiin yeroo walitti qabamu ofumaan walmadaala';

  @override
  String get expenseSavedSyncing => 'Baasiin olkaa\'ame fi walmadaalaa jira';

  @override
  String get expenseSavedOffline =>
      'Baasiin olkaa\'ame — yeroo toora irra jirtu walmadaala';

  @override
  String get failedToSave => 'Olkaa\'uun dhabame';

  @override
  String get laborEntriesTitle => 'Galma Hojjettootaa';

  @override
  String get addLabor => 'Hojjettoo Dabaluu';

  @override
  String get noLaborEntriesYet => 'Galma hojjettoo hin jiru';

  @override
  String get addLaborEntry => 'Galma Hojjettoo Dabaluu';

  @override
  String get workersCount => 'hojjettootaa';

  @override
  String get workerCrewNameRequired => 'Maqaa Hojjettoo / Garee *';

  @override
  String get workerCrewPlaceholder => 'Garee Sibiila (Gebruu fi garee)';

  @override
  String get workDescriptionLabel => 'Ibsa Hojii';

  @override
  String get workDescriptionPlaceholder =>
      'Sibiila bu\'uuraa kaa\'uu, sadarkaa jalqabaa';

  @override
  String get workersLabel => 'Hojjettootaa';

  @override
  String get dailyRateEtb => 'Kaffaltii Guyyaa (ETB)';

  @override
  String get totalAmountEtb => 'Baasii Waliigalaa (ETB) *';

  @override
  String get workDateRequired => 'Guyyaa Hojii *';

  @override
  String get offlineWillSyncShort =>
      'Toora ala jirta — yeroo walitti qabamu walmadaala';

  @override
  String get enterTotalAmount => 'Baasii waliigalaa galchi';

  @override
  String get saveLaborEntry => 'Galma Hojjettoo Olkaa\'i';

  @override
  String get laborEntrySaved =>
      'Galma hojjettoo olkaa\'ame fi walmadaalaa jira';

  @override
  String get laborEntrySavedOffline =>
      'Galma hojjettoo olkaa\'ame — yeroo toora irra jirtu walmadaala';

  @override
  String get invalidNumber => 'Sirrii miti';

  @override
  String get required => 'Dirqama';

  @override
  String get hintQuantity => '0.0';

  @override
  String get hintDescription => 'Fkf. Simentoo bitachuu — kuintaala 50';

  @override
  String get back => 'Duubatti Deebi\'i';

  @override
  String get schedulePercentage => 'Sagantaa';

  @override
  String viewTab(String tab) {
    return '$tab Ilaali';
  }

  @override
  String minutesAgo(int count) {
    return 'daqiiqaa $count dura';
  }

  @override
  String hoursAgo(int count) {
    return 'sa\'aatii $count dura';
  }

  @override
  String daysAgo(int count) {
    return 'guyyaa $count dura';
  }

  @override
  String weeksAgo(int count) {
    return 'torban $count dura';
  }

  @override
  String get markAllRead => 'Hunda Dubbifame Godhi';

  @override
  String get noNotifications => 'Beeksisawwan hin jiru';

  @override
  String get materialsAndPrices => 'Meeshaalee fi Gatii';

  @override
  String get searchMaterials => 'Meeshaalee barbaadi...';

  @override
  String get noMaterialsFound => 'Meeshaan hin argamne';

  @override
  String get priceReportingComingSoon => 'Unka gabaasaa gatii — dhiyootti';

  @override
  String get currentPriceAddis => 'Gatii Ammaa (Finfinnee)';

  @override
  String get noPriceHistory => 'Godinaa kanaaf seenaan gatii amma hin jiru.';

  @override
  String get failedToLoadPrices => 'Gatii fe\'uun dhabame';

  @override
  String get billingAndSubscription => 'Kaffaltii fi Miseensummaa';

  @override
  String get month => '/ji\'a';

  @override
  String upgradeTo(String tier) {
    return 'Gara $tier fooyi\'i';
  }

  @override
  String upgradeMessage(String amount) {
    return '$amount ji\'aa ji\'aan Telebirr itti kaffalama.';
  }

  @override
  String get telebirrInitiated =>
      'Kaffaltiin Telebirr jalqabameera — bilbila kee ilaali';

  @override
  String get failed => 'Dhabame';

  @override
  String get upgrade => 'Fooyi\'i';

  @override
  String get starter => 'Jalqaba';

  @override
  String get growth => 'Guddina';

  @override
  String get professional => 'Ogeessa';

  @override
  String get enterprise => 'Dhaabbata';

  @override
  String get trial => 'Yaalii';

  @override
  String get expired => 'Xumurameera';

  @override
  String get supplierDirectory => 'Galmee Dhiyeessitootaa';

  @override
  String get searchSuppliers => 'Dhiyeessitootaa barbaadi...';

  @override
  String get noSuppliersFound => 'Dhiyeessituun hin argamne';

  @override
  String get call => 'Bilbili';

  @override
  String get sms => 'SMS';

  @override
  String get newPO => 'Ajaja Haaraa';

  @override
  String get noPurchaseOrders => 'Ajajni bitaa hin jiru';

  @override
  String get createPO => 'Ajaja Uumi';

  @override
  String get addTask => 'Hojii Dabaluu';

  @override
  String get noTasksScheduled => 'Hojiin karoorfame hin jiru';

  @override
  String get newTask => 'Hojii Haaraa';

  @override
  String get taskName => 'Maqaa Hojii';

  @override
  String get add => 'Dabali';

  @override
  String get notStarted => 'Hin jalqabne';

  @override
  String get inProgress => 'Adeemsa irra jira';

  @override
  String get complete => 'Xumurame';

  @override
  String get delayed => 'Turu';

  @override
  String get constructionCostTracking => 'Hordoffii Baasii Ijaarsa';

  @override
  String get welcomeBack => 'Baga Deebittan';

  @override
  String get signInWithPhone => 'Lakkoofsa bilbilaan seeni';

  @override
  String get dontHaveAccount => 'Herreegaa hin qabduu?';

  @override
  String get forgotPassword => 'Jecha darbii dagatte?';

  @override
  String fieldRequired(String field) {
    return '$field dirqama';
  }

  @override
  String minCharacters(int count) {
    return 'Xiqqaate qubee $count';
  }

  @override
  String get alreadyHaveAccount => 'Herreegaa qabdaa?';

  @override
  String get chooseYourLanguage => 'Afaan Kee Filadhu';

  @override
  String changeLanguageLater(String settings) {
    return 'Kana booda $settings keessatti jijjiiruu dandeessa.';
  }

  @override
  String get enterAllDigits => 'Lakkoofsa 6 hunda galchi';

  @override
  String get orgSetupTagline =>
      'Odeeffannoon kun dhaabbata keetiif app qindeessuuf nu gargaara.';

  @override
  String get organization => 'Dhaabbata';

  @override
  String get about => 'Waa\'ee';

  @override
  String version(String version) {
    return 'Versiyon $version';
  }

  @override
  String spentAmount(String amount) {
    return '$amount bahe';
  }

  @override
  String ofAmount(String amount) {
    return '$amount keessaa';
  }

  @override
  String get newPurchaseOrder => 'Ajaja Bitachuu Haaraa';

  @override
  String get lineItems => 'Meeshaalee Tarreeffaman';

  @override
  String get addLineItem => 'Meeshaa Dabaluu';

  @override
  String get notes => 'Yaadannoo (dirqama miti)';

  @override
  String get total => 'Waliigala';

  @override
  String get submitForApproval => 'Hayyamaaf Ergi';

  @override
  String get poSubmitted => 'Ajajni bitachuu hayyamaaf ergameera';

  @override
  String itemNumber(int number) {
    return 'Meeshaa $number';
  }

  @override
  String get qty => 'Baay\'ina';

  @override
  String get unitPriceEtb => 'Gatii Ahadaa (ETB)';

  @override
  String lineTotal(String amount) {
    return 'Waliigala saree: $amount';
  }

  @override
  String get receiptPhoto => 'Suuraa Rasiidhaa';

  @override
  String get tapToAddReceipt => 'Suuraa dabaluuf tuqi';

  @override
  String get takePhoto => 'Suuraa Ka\'i';

  @override
  String get chooseFromGallery => 'Galarii irraa Filadhu';

  @override
  String get syncTriggered => 'Walmadaaluu jalqabame';

  @override
  String get syncingEllipsis => 'Walmadaalaa...';

  @override
  String pendingCount(int count) {
    return '$count eeggachaa';
  }
}
