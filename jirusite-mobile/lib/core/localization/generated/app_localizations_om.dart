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
  String get materials => 'Meeshaalee fi Gatii';

  @override
  String get suppliers => 'Dhiyeessitootaa';

  @override
  String get purchaseOrders => 'Ajaja Bitachuu';

  @override
  String get schedule => 'Sagantaa';

  @override
  String get notifications => 'Beeksisawwan';

  @override
  String get billing => 'Kafaltii';

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
  String get percentComplete => '% Xumurame';

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
}
