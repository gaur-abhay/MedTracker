import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'providers/medication_provider.dart';
import 'screens/home_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase (database)
  await SupabaseService.initialize();

  // Local notifications + alarms (Android only)
  if (!kIsWeb) {
    await NotificationService.instance.init();
  }

  // Stable user ID
  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('userId');
  if (userId == null) {
    userId = const Uuid().v4();
    await prefs.setString('userId', userId);
  }

  // Firebase (FCM only — free, no Blaze needed)
  String? fcmToken;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    fcmToken = await FcmService.instance.init();
  } catch (_) {
    // Firebase not configured yet — runs without push notifications
  }

  // Supabase service (register user + FCM token)
  try {
    await SupabaseService.instance.init(userId, fcmToken: fcmToken);
  } catch (_) {}

  runApp(const MedicationApp());
}

class MedicationApp extends StatelessWidget {
  const MedicationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MedicationProvider()..load(),
      child: MaterialApp(
        title: 'MedTrack',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
