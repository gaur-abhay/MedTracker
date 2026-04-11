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
  String? _relationshipStatus; // approved | pending | rejected | null
  bool _searching = false;
  bool _triggering = false;
  bool _refreshingStatus = false;
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
    if (_watchingUserId != null) {
      await _refreshRelationshipStatus();
    }
  }

  /// Fetches latest approval status from Supabase (no app restart needed).
  Future<void> _refreshRelationshipStatus() async {
    final id = _watchingUserId;
    if (id == null) return;
    setState(() => _refreshingStatus = true);
    try {
      final status =
          await SupabaseService.instance.getRelationshipStatusForGuardian(id);
      if (mounted) setState(() => _relationshipStatus = status);
    } finally {
      if (mounted) setState(() => _refreshingStatus = false);
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

      // Same user as already linked: refresh status instead of resending.
      if (_watchingUserId == targetUserId) {
        await _refreshRelationshipStatus();
        if (!mounted) return;
        final s = _relationshipStatus;
        final msg = s == 'approved'
            ? 'Already watching @$username — approved. Logs update live.'
            : s == 'pending'
                ? 'Request already sent to @$username. Pull down or tap refresh to check approval.'
                : s == 'rejected'
                    ? '@$username rejected this request. They can send a new one from their app.'
                    : 'Already linked to @$username — status refreshed.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        _relationshipStatus = 'pending';
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
    if (_relationshipStatus != 'approved') return;
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
        actions: [
          if (_watchingUserId != null)
            IconButton(
              tooltip: 'Refresh approval status',
              onPressed: _refreshingStatus ? null : _refreshRelationshipStatus,
              icon: _refreshingStatus
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
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
                if (_watchingUserId != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Refresh status',
                    onPressed: _refreshingStatus ? null : _refreshRelationshipStatus,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                    ),
                    icon: _refreshingStatus
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
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
                  onPressed: (_triggering || _relationshipStatus != 'approved')
                      ? null
                      : _triggerAlarm,
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

            if (_relationshipStatus != 'approved')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Card(
                  color: const Color(0xFFFFF3E0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _relationshipStatus == 'pending'
                              ? 'Request sent. Waiting for user approval.'
                              : _relationshipStatus == 'rejected'
                                  ? 'This request was rejected.'
                                  : 'Not approved yet. Ask the user to approve you in “Manage Guardians”.',
                          style: const TextStyle(color: Colors.orange),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down on this area or tap the refresh icon to update — no need to restart the app.',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
              child: (_relationshipStatus != 'approved')
                  ? RefreshIndicator(
                      onRefresh: _refreshRelationshipStatus,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        children: const [
                          SizedBox(height: 40),
                          Icon(Icons.hourglass_top, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Logs appear here after the user approves you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : StreamBuilder<List<MedicationLog>>(
                      stream: SupabaseService.instance
                          .watchUserLogs(_watchingUserId!),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting &&
                            (snap.data == null || snap.data!.isEmpty)) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final logs = snap.data ?? [];
                        if (logs.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: _refreshRelationshipStatus,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(32),
                              children: const [
                                SizedBox(height: 48),
                                Icon(Icons.medication_outlined,
                                    size: 56, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No doses logged yet.\nPull down to refresh status.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }
                        final grouped = _groupLogsByDay(logs);
                        return RefreshIndicator(
                          onRefresh: _refreshRelationshipStatus,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: grouped.length,
                            itemBuilder: (context, i) {
                              final item = grouped[i];
                              if (item.header != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      top: 16, bottom: 8),
                                  child: Text(
                                    item.header!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                );
                              }
                              return _GuardianLogTile(log: item.log!);
                            },
                          ),
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

class _GroupedLogItem {
  final String? header;
  final MedicationLog? log;

  _GroupedLogItem.header(this.header) : log = null;
  _GroupedLogItem.log(this.log) : header = null;
}

List<_GroupedLogItem> _groupLogsByDay(List<MedicationLog> logs) {
  final map = <DateTime, List<MedicationLog>>{};
  for (final log in logs) {
    final d = log.scheduledTime;
    final day = DateTime(d.year, d.month, d.day);
    map.putIfAbsent(day, () => []).add(log);
  }
  final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
  final out = <_GroupedLogItem>[];
  for (final day in days) {
    final dayLogs = map[day]!
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    out.add(_GroupedLogItem.header(_friendlyDayLabel(day)));
    for (final log in dayLogs) {
      out.add(_GroupedLogItem.log(log));
    }
  }
  return out;
}

String _friendlyDayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';
  if (today.difference(day).inDays < 7) {
    return DateFormat('EEEE').format(day);
  }
  return DateFormat('EEEE, d MMMM y').format(day);
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
        title: Text(
          log.medicationName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Scheduled ${DateFormat('h:mm a').format(log.scheduledTime)}'
          '${log.isTaken && log.takenTime != null ? ' · Taken ${DateFormat('h:mm a').format(log.takenTime!)}' : ''}',
        ),
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
