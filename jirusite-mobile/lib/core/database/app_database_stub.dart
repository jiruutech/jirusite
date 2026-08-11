// Stub used when dart.library.io is not available (web).
library;
import 'app_database.dart';

AppDatabase createNativeDatabase() => WebAppDatabase();
