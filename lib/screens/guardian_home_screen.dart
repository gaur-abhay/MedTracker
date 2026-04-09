import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication_log.dart';
import '../services/supabase_service.dart';

class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  final _searchController = TextEditingController();
  String? _watchingUsername;
  String? _watchingUserId;
  bool _searching = false;
  bool _triggering = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadWatching();
  }

  Future<void> _loadWatching() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _watchingUsername = prefs.getString('watching_username');
      _watchingUserId = prefs.getString('watching_user_id');
    });
    if (_watchingUsername != null) {
      _searchController.text = _watchingUsername!;
    }
  }

  Future<void> _search() async {
    final username = _searchController.text.trim().toLowerCase();
    if (username.isEmpty) return;

    setState(() { _searching = true; _searchError = null; });

    try {
      final result = await SupabaseService.instance.findUserByUsername(username);
      if (result == null) {
        setState(() => _searchError = 'User "$username" not found.');
        return;
      }

      final targetUserId = result['user_id'] as String?;
      if (targetUserId == null || targetUserId.isEmpty) {
        setState(() => _searchError = 'User record is missing user_id.');
        return;
      }

      // If already watching this user, don't resend request.
      if (_watchingUserId == targetUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Already watching @$username')),
          );
        }
        return;
      }

      // Send a watch request
      await SupabaseService.instance.sendWatchRequest(targetUserId, username);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('watching_username', username);
      await prefs.setString('watching_user_id', targetUserId);

      setState(() {
        _watchingUsername = username;
        _watchingUserId = targetUserId;
        _searchError = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Watch request sent to $username')),
        );
      }
    } catch (e) {
      setState(() => _searchError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _triggerAlarm() async {
    if (_watchingUserId == null) return;
    setState(() => _triggering = true);
    try {
      await SupabaseService.instance.sendGuardianTrigger(_watchingUserId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarm triggered on their device')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Guardian View'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter username to watch...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      errorText: _searchError,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Watch'),
                ),
              ],
            ),
          ),

          if (_watchingUserId == null)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Enter a username above to start watching someone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Trigger alarm button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _triggering ? null : _triggerAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _triggering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.alarm),
                  label: Text(
                    'Trigger Alarm on ${_watchingUsername ?? "their"} device',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Watching: @$_watchingUsername',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<List<MedicationLog>>(
                stream: SupabaseService.instance.watchUserLogs(_watchingUserId!),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final logs = snap.data ?? [];
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text('No medication data yet.',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => _GuardianLogTile(log: logs[i]),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuardianLogTile extends StatelessWidget {
  final MedicationLog log;
  const _GuardianLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = log.isTaken
        ? const Color(0xFF2E7D32)
        : log.isMissed
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            log.isTaken
                ? Icons.check
                : log.isMissed
                    ? Icons.close
                    : Icons.schedule,
            color: color,
          ),
        ),
        title: Text(log.medicationName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(DateFormat('d MMM, h:mm a').format(log.scheduledTime)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Text(
            log.isTaken
                ? 'Taken'
                : log.isMissed
                    ? 'MISSED'
                    : 'Pending',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
