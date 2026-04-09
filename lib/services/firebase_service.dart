import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// Background FCM handler — fires alarm even when app is killed
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'guardian_trigger') {
    final guardianId = message.data['from_user_id'] as String?;
    if (guardianId != null && guardianId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_guardian_id', guardianId);
    }
    await NotificationService.instance.triggerGuardianAlarm();
  }
}

class FcmService {
  static FcmService? _instance;
  static FcmService get instance => _instance ??= FcmService._();
  FcmService._();

  bool _initialized = false;
  String? _token;

  Future<String?> init() async {
    if (kIsWeb) return null;
    _initialized = true;

    await FirebaseMessaging.instance.requestPermission();
    _token = await FirebaseMessaging.instance.getToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((t) => _token = t);
    FirebaseMessaging.onMessage.listen((m) async => _handleForegroundMessage(m));

    return _token;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (message.data['type'] == 'guardian_trigger') {
      final guardianId = message.data['from_user_id'] as String?;
      if (guardianId != null && guardianId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_guardian_id', guardianId);
      }
      NotificationService.instance.triggerGuardianAlarm();
    }
  }

  String? get token => _token;
  bool get initialized => _initialized;
}
