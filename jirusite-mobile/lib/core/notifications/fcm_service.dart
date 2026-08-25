import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_endpoints.dart';
import '../network/dio_client.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  final dio = ref.read(dioClientProvider);
  return FcmService(dio: dio);
});

/// Handles Firebase Cloud Messaging setup, token registration, and
/// foreground/background message routing.
class FcmService {
  FcmService({required this.dio});
  final DioClient dio;

  /// Call once after login/auth is confirmed.
  /// Requests permission, gets the FCM token, registers it with the server,
  /// and sets up message handlers.
  Future<void> initialize() async {
    // Web and desktop don't need FCM setup
    if (kIsWeb) return;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS prompts; Android 13+ prompts)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Permission denied by user');
      return;
    }

    // Get token and register with server
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // Refresh token when it rotates
    messaging.onTokenRefresh.listen(_registerToken);

    // Foreground messages — show a local notification or in-app banner
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
      // TODO: show in-app banner when local_notifications package is added
    });

    // Background/terminated tap — app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Opened from notification: ${message.data}');
      // TODO: navigate to relevant screen based on message.data['type']
    });

    // Check if app was opened from a terminated state via notification
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] Launched from notification: ${initial.data}');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await dio.post(ApiEndpoints.registerFcmToken, data: {'fcm_token': token});
      debugPrint('[FCM] Token registered');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }
}

/// Top-level handler required for background messages (must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.notification?.title}');
  // Firebase.initializeApp() is called in main.dart before this handler runs
}
