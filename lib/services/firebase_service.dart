import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

// Background FCM handler — fires alarm even when app is killed
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'guardian_trigger') {
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
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    return _token;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.data['type'] == 'guardian_trigger') {
      NotificationService.instance.triggerGuardianAlarm();
    }
  }

  String? get token => _token;
  bool get initialized => _initialized;
}
