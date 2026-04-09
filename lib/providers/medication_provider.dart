import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/medication.dart';
import '../models/medication_log.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';


class MedicationProvider extends ChangeNotifier {
  List<Medication> _medications = [];
  List<MedicationLog> _logs = [];
  bool _loading = true;

  List<Medication> get medications => _medications;
  List<MedicationLog> get logs => _logs;
  bool get loading => _loading;

  List<MedicationLog> get todayLogs {
    final today = DateTime.now();
    return _logs.where((l) {
      final d = l.scheduledTime;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  Future<void> load() async {
    _medications = await StorageService.instance.loadMedications();
    _logs = await StorageService.instance.loadLogs();
    _loading = false;
    notifyListeners();
    
    // 1. Generate today's logs first
    await _generateTodayLogs();
    
    // 2. Ensure all logs for today are synced to Supabase
    // This fixes any "missed" syncs from earlier.
    for (final log in todayLogs) {
      try {
        await SupabaseService.instance.syncLog(log);
      } catch (_) {}
    }
  }

  // ── Generate log entries for today if not yet created ────────────────────

  Future<void> _generateTodayLogs() async {
    final today = DateTime.now();
    bool changed = false;

    for (final med in _medications) {
      for (final timeStr in med.times) {
        final parts = timeStr.split(':');
        final scheduled = DateTime(
          today.year,
          today.month,
          today.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        final exists = _logs.any(
          (l) =>
              l.medicationId == med.id &&
              l.scheduledTime.isAtSameMomentAs(scheduled),
        );

        if (!exists) {
          final log = MedicationLog(
            id: const Uuid().v4(),
            medicationId: med.id,
            medicationName: med.name,
            scheduledTime: scheduled,
          );
          _logs.add(log);
          changed = true;
          // Sync new logs immediately
          try {
            SupabaseService.instance.syncLog(log);
          } catch (_) {}
        }
      }
    }

    // Mark overdue scheduled entries as missed (including from previous days)
    final missedChanged = await _checkMissed();
    if (changed || missedChanged) {
      await StorageService.instance.saveLogs(_logs);
      notifyListeners();
    }
  }

  Future<bool> _checkMissed() async {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 20));
    bool changed = false;

    for (final log in _logs) {
      if (log.isPending && log.scheduledTime.isBefore(cutoff)) {
        log.status = MedicationStatus.missed;
        try {
          await SupabaseService.instance.syncLog(log);
        } catch (_) {}
        changed = true;
      }
    }
    return changed;
  }

  // ── Add medication ────────────────────────────────────────────────────────

  Future<void> addMedication(Medication med) async {
    _medications.add(med);
    await StorageService.instance.saveMedications(_medications);
    if (!kIsWeb) await NotificationService.instance.scheduleMedication(med);
    await _generateTodayLogs();
    notifyListeners();
  }

  // ── Remove medication ─────────────────────────────────────────────────────

  Future<void> removeMedication(String id) async {
    _medications.removeWhere((m) => m.id == id);
    _logs.removeWhere(
        (l) => l.medicationId == id && l.scheduledTime.isAfter(DateTime.now()));
    await StorageService.instance.saveMedications(_medications);
    await StorageService.instance.saveLogs(_logs);
    if (!kIsWeb) await NotificationService.instance.cancelMedication(id);
    notifyListeners();
  }

  // ── Mark as taken ─────────────────────────────────────────────────────────

  Future<void> markTaken(MedicationLog log) async {
    log.status = MedicationStatus.taken;
    log.takenTime = DateTime.now();
    await StorageService.instance.saveLogs(_logs);
    if (!kIsWeb) {
      try {
        await NotificationService.instance.cancelDose(
          log.medicationId,
          log.scheduledTime,
        );
      } catch (_) {}
    }
    // Sync to Supabase — guardians see it in real-time via their stream
    // No local self-notification (the guardian gets notified, not the user)
    try {
      await SupabaseService.instance.syncLog(log);
      final guardians = await SupabaseService.instance.getApprovedGuardianIds();
      for (final gid in guardians) {
        await SupabaseService.instance.sendLogTakenTrigger(gid);
      }
    } catch (_) {}
    notifyListeners();
  }

  // ── Snooze ────────────────────────────────────────────────────────────────

  Future<void> snooze(MedicationLog log) async {
    log.status = MedicationStatus.snoozed;
    await StorageService.instance.saveLogs(_logs);
    notifyListeners();
  }

  // ── Refresh (call periodically to check missed) ───────────────────────────

  Future<void> refresh() async {
    await _checkMissed();
    await _generateTodayLogs();
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  int get streakDays {
    if (_logs.isEmpty) return 0;
    int streak = 0;
    var day = DateTime.now();
    while (true) {
      final dayLogs = _logs.where((l) {
        final d = l.scheduledTime;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).toList();

      if (dayLogs.isEmpty) break;
      final allTaken = dayLogs.every((l) => l.isTaken);
      if (!allTaken) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
