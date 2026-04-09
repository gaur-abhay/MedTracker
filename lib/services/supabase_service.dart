import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medication_log.dart';

const _supabaseUrl = 'https://uhwnxshftquopnxtfsnl.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVod254c2hmdHF1b3BueHRmc25sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2OTg1OTYsImV4cCI6MjA5MTI3NDU5Nn0.SSZRI5F6RtV_1y5i4kMUSW0LfY417SkcEwW0QOXjIZg';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  bool _initialized = false;
  String? _userId;
  String? _username;

  static Future<void> initialize() async {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  }

  Future<void> init(String userId, {String? fcmToken}) async {
    _userId = userId;
    _initialized = true;
    try {
      await _db.from('users').upsert({
        'user_id': userId,
        'fcm_token': fcmToken,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Supabase init error: $e');
    }
  }

  // ── Username ──────────────────────────────────────────────────────────────

  Future<void> setUsername(String username) async {
    if (_userId == null) return;
    await _db.from('users').upsert({
      'user_id': _userId,
      'username': username.toLowerCase(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    _username = username.toLowerCase();
  }

  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    final res = await _db
        .from('users')
        .select('user_id, username')
        .eq('username', username.toLowerCase())
        .maybeSingle();
    return res;
  }

  // ── Medication logs ───────────────────────────────────────────────────────

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

  // ── Guardian relationships ────────────────────────────────────────────────

  Future<void> sendWatchRequest(String targetUserId, String targetUsername) async {
    if (_userId == null) return;
    await _db.from('guardian_relationships').upsert(
      {
        'user_id': targetUserId,
        'guardian_id': _userId,
        'guardian_username': _username,
        'user_username': targetUsername.toLowerCase(),
        'status': 'pending',
      },
      onConflict: 'user_id,guardian_id',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingGuardianRequests() async {
    if (_userId == null) return [];
    final res = await _db
        .from('guardian_relationships')
        .select()
        .eq('user_id', _userId!)
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> getApprovedGuardians() async {
    if (_userId == null) return [];
    final res = await _db
        .from('guardian_relationships')
        .select()
        .eq('user_id', _userId!)
        .eq('status', 'approved');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> respondToGuardianRequest(String relationshipId,
      {required bool approve}) async {
    await _db
        .from('guardian_relationships')
        .update({'status': approve ? 'approved' : 'rejected'}).eq('id', relationshipId);
  }

  // ── Guardian trigger ──────────────────────────────────────────────────────

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
  String? get username => _username;
}
