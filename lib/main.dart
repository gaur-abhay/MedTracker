import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models/user_profile.dart';
import 'providers/medication_provider.dart';
import 'screens/home_screen.dart';
import 'screens/guardian_home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  if (!kIsWeb) {
    await NotificationService.instance.init();
  }

  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('userId');
  if (userId == null) {
    userId = const Uuid().v4();
    await prefs.setString('userId', userId);
  }

  String? fcmToken;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    fcmToken = await FcmService.instance.init();
  } catch (_) {}

  try {
    await SupabaseService.instance.init(userId, fcmToken: fcmToken);
  } catch (_) {}

  if (!kIsWeb) {
    bool guardianAlarmRinging = false;

    Alarm.ringStream.stream.listen((alarmSettings) {
      if (alarmSettings.id == 88888) {
        guardianAlarmRinging = true;
      }
    });

    Alarm.updateStream.stream.listen((_) async {
      if (!guardianAlarmRinging) return;
      final active = await Alarm.getAlarms();
      final stillActive = active.any((a) => a.id == 88888);
      if (stillActive) return;

      guardianAlarmRinging = false;
      final guardianId = prefs.getString('last_guardian_id');
      if (guardianId != null && guardianId.isNotEmpty) {
        await SupabaseService.instance.sendAlarmAckTrigger(guardianId);
        await prefs.remove('last_guardian_id');
      }
    });
  }

  // Determine start screen
  final username = prefs.getString('username');
  final roleStr = prefs.getString('role');
  final isOnboarded = username != null && roleStr != null;

  Widget home;
  if (!isOnboarded) {
    home = const OnboardingScreen();
  } else if (roleStr == UserRole.guardian.name) {
    home = const GuardianHomeScreen();
  } else {
    home = const HomeScreen();
  }

  runApp(MedicationApp(home: home));
}

class MedicationApp extends StatelessWidget {
  final Widget home;
  const MedicationApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MedicationProvider()..load(),
      child: MaterialApp(
        title: 'MedTrack',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
          useMaterial3: true,
        ),
        home: home,
      ),
    );
  }
}
