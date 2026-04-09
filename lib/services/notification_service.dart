import 'package:alarm/alarm.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/medication.dart';
import '../models/medication_log.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await Alarm.init();
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handled by the app's navigation layer
  }

  // ── Schedule all alarms for a medication ─────────────────────────────────

  Future<void> scheduleMedication(Medication med) async {
    await cancelMedication(med.id);

    final now = DateTime.now();

    for (final timeStr in med.times) {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final alarmId = _alarmId(med.id, timeStr);

      await Alarm.set(
        alarmSettings: AlarmSettings(
          id: alarmId,
          dateTime: scheduled,
          assetAudioPath: 'assets/alarm.mp3',
          loopAudio: true,
          vibrate: true,
          volume: 1.0,
          fadeDuration: 0,
          warningNotificationOnKill: true,
          androidFullScreenIntent: true,
          notificationSettings: NotificationSettings(
            title: 'Time for your medicine',
            body: '💊 Take ${med.name} now',
            stopButton: 'Dismiss',
          ),
        ),
      );

      // Follow-up reminder after 10 min
      await _scheduleFollowUp(med, scheduled, timeStr, delayMinutes: 10);

      // Missed escalation after 20 min
      await _scheduleFollowUp(med, scheduled, timeStr, delayMinutes: 20, isMissed: true);
    }
  }

  Future<void> _scheduleFollowUp(
    Medication med,
    DateTime base,
    String timeStr, {
    required int delayMinutes,
    bool isMissed = false,
  }) async {
    final triggerAt = tz.TZDateTime.from(
      base.add(Duration(minutes: delayMinutes)),
      tz.local,
    );

    final notifId = _notifId(med.id, timeStr, delayMinutes);

    await _plugin.zonedSchedule(
      notifId,
      isMissed ? '❗ Medication not taken' : '⚠️ Reminder',
      isMissed
          ? '${med.name} was scheduled ${delayMinutes} minutes ago'
          : 'Please take ${med.name}',
      triggerAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_followup',
          'Medication Follow-up',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Cancel all alarms/notifications for a medication ─────────────────────

  Future<void> cancelMedication(String medId) async {
    // Cancel alarms — we don't track exact IDs stored, so cancel by range
    // IDs are deterministic from medId hash + timeStr
    final pending = await Alarm.getAlarms();
    for (final alarm in pending) {
      if (alarm.id >> 16 == medId.hashCode.abs() & 0xFFFF) {
        await Alarm.stop(alarm.id);
      }
    }
    await _plugin.cancelAll(); // Simpler: cancel all follow-ups and reschedule
  }

  // ── One-shot "taken" confirmation notification ────────────────────────────

  Future<void> notifyTaken(MedicationLog log) async {
    final timeStr = _formatTime(log.takenTime ?? DateTime.now());
    await _plugin.show(
      99999,
      '✅ Medication taken',
      '${log.medicationName} taken at $timeStr',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_taken',
          'Medication Confirmed',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  // ── Guardian-triggered alarm ──────────────────────────────────────────────

  Future<void> triggerGuardianAlarm() async {
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: 88888,
        dateTime: DateTime.now().add(const Duration(seconds: 2)),
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volume: 1.0,
        fadeDuration: 0,
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,
        notificationSettings: const NotificationSettings(
          title: '🚨 Guardian Alert',
          body: 'Your guardian is asking you to take your medicine NOW',
          stopButton: 'I will take it',
        ),
      ),
    );
  }

  Future<void> stopAlarm(int id) => Alarm.stop(id);

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _alarmId(String medId, String timeStr) {
    return (((medId.hashCode.abs() & 0x3FFF) << 16) |
            (timeStr.hashCode.abs() & 0xFFFF))
        .toSigned(32);
  }

  int _notifId(String medId, String timeStr, int delay) {
    return (((medId.hashCode.abs() & 0x7F) << 24) |
            ((timeStr.hashCode.abs() & 0x7F) << 16) |
            (delay & 0xFFFF))
        .toSigned(32);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
