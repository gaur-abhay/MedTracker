import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medication_log.dart';

// Fill these in from your Supabase project settings → API
const _supabaseUrl = 'https://uhwnxshftquopnxtfsnl.supabase.co';
const _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVod254c2hmdHF1b3BueHRmc25sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2OTg1OTYsImV4cCI6MjA5MTI3NDU5Nn0.SSZRI5F6RtV_1y5i4kMUSW0LfY417SkcEwW0QOXjIZg';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  bool _initialized = false;
  String? _userId;

  static Future<void> initialize() async {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  }

  Future<void> init(String userId, {String? fcmToken}) async {
    _userId = userId;
    _initialized = true;

    try {
      // Register this device in the users table
      await _db.from('users').upsert({
        'user_id': userId, // Correct column name in SQL
        'fcm_token': fcmToken,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Supabase init error: $e');
    }
  }

  // ── Sync a log so guardians can see it ───────────────────────────────────

  Future<void> syncLog(MedicationLog log) async {
    if (!_initialized || _userId == null) return;
    try {
      await _db.from('medication_logs').upsert({
        ...log.toJson(),
        'user_id': _userId,
      });
    } catch (e) {
      print('Supabase sync error: $e');
    }
  }

  // ── Guardian: stream another user's logs in real-time ────────────────────

  Stream<List<MedicationLog>> watchUserLogs(String targetUserId) {
    if (!_initialized) return const Stream.empty();
    
    return _db
        .from('medication_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', targetUserId)
        .order('scheduled_time', ascending: false)
        .limit(50)
        .map((rows) => rows.map((r) => MedicationLog.fromJson(r)).toList());
  }

  // ── Guardian: write a trigger — Edge Function picks it up → sends FCM ────

  Future<void> sendGuardianTrigger(String targetUserId) async {
    if (!_initialized) return;
    try {
      await _db.from('triggers').insert({
        'target_user_id': targetUserId,
        'from_user_id': _userId,
        'type': 'guardian_trigger',
      });
    } catch (e) {
      print('Supabase trigger error: $e');
    }
  }

  bool get initialized => _initialized;
  String? get currentUserId => _userId;
}
