import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _bg(RemoteMessage m) async {
  await Firebase.initializeApp();
}

/// FCM so labour get job offers even when the app is closed.
/// Safe no-op until google-services.json is added (see README).
class PushService {
  static bool _ready = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_bg);
      _ready = true;
    } catch (e) {
      debugPrint('Push disabled (Firebase not configured): $e');
    }
  }

  static Future<void> register(Dio dio) async {
    if (!_ready) return;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      Future<void> send(String t) =>
          dio.post('/api/notifications/device-token', data: {'token': t}); // needs backend patch
      final t = await fm.getToken();
      if (t != null) await send(t);
      fm.onTokenRefresh.listen(send);
    } catch (e) {
      debugPrint('FCM register failed: $e');
    }
  }
}
