import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app/app.dart';
import 'app/splash_screen.dart';
import 'core/database/app_database.dart';
import 'core/notifications/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase — gracefully disabled if not configured
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      // Register top-level background message handler BEFORE runApp
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[Firebase] init skipped: $e');
    }
  }

  // Create the right DB implementation for the current platform
  final db = createAppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const _RootApp(),
    ),
  );
}

/// Root widget that shows the splash screen on first load,
/// then switches to the real JiruSiteApp once the splash completes.
class _RootApp extends StatefulWidget {
  const _RootApp();

  @override
  State<_RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<_RootApp> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(
          onComplete: () => setState(() => _splashDone = true),
        ),
      );
    }
    return const JiruSiteApp();
  }
}
