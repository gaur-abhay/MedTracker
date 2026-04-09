import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication.dart';
import '../models/medication_log.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  static const _medsKey = 'medications';
  static const _logsKey = 'logs';

  // ── Medications ──────────────────────────────────────────────────────────

  Future<List<Medication>> loadMedications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_medsKey);
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw) as List;
      return data.map((e) => Medication.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMedications(List<Medication> medications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _medsKey,
      jsonEncode(medications.map((m) => m.toJson()).toList()),
    );
  }

  // ── Logs ─────────────────────────────────────────────────────────────────

  Future<List<MedicationLog>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_logsKey);
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw) as List;
      return data.map((e) => MedicationLog.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLogs(List<MedicationLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    // Keep only last 90 days
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    final recent = logs.where((l) => l.scheduledTime.isAfter(cutoff)).toList();
    await prefs.setString(
      _logsKey,
      jsonEncode(recent.map((l) => l.toJson()).toList()),
    );
  }
}
