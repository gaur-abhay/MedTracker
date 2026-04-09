import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication_log.dart';
import '../services/supabase_service.dart';

class GuardianScreen extends StatefulWidget {
  const GuardianScreen({super.key});

  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen> {
  // Two tabs: "My Code" (share your ID) and "Watch Someone" (enter their ID)
  int _tab = 0;
  final _codeController = TextEditingController();
  String? _watchingUserId;
  String? _relationshipStatus;
  bool _triggering = false;

  @override
  void initState() {
    super.initState();
    _loadWatchedUser();
  }

  Future<void> _loadWatchedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final watchingUserId = prefs.getString('watching_user_id');
    setState(() => _watchingUserId = watchingUserId);
    if (watchingUserId != null) {
      final status = await SupabaseService.instance
          .getRelationshipStatusForGuardian(watchingUserId);
      if (mounted) setState(() => _relationshipStatus = status);
    }
  }

  Future<void> _saveWatchedUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('watching_user_id', userId);
    final status =
        await SupabaseService.instance.getRelationshipStatusForGuardian(userId);
    setState(() {
      _watchingUserId = userId;
      _relationshipStatus = status ?? 'pending';
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _TabButton(
                label: 'My Code',
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              _TabButton(
                label: 'Watch Someone',
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
      ),
      body: _tab == 0 ? _MyCodeTab() : _WatchTab(
        watchingUserId: _watchingUserId,
        onSave: _saveWatchedUser,
        triggering: _triggering,
        onTrigger: _triggerAlarm,
      ),
    );
  }

  Future<void> _triggerAlarm() async {
    if (_watchingUserId == null) return;
    if (_relationshipStatus != 'approved') return;
    setState(() => _triggering = true);
    try {
      await SupabaseService.instance.sendGuardianTrigger(_watchingUserId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert sent to user')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send alert: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }
}

// ── My Code tab (share your user ID) ─────────────────────────────────────────

class _MyCodeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.instance.currentUserId ?? 'Not connected';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.share, size: 48, color: Color(0xFF2E7D32)),
          const SizedBox(height: 16),
          const Text(
            'Share your code with a guardian',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'They can then watch your medication status and trigger an alarm if needed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                const Text(
                  'Your User ID',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  userId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: userId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy ID'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              side: const BorderSide(color: Color(0xFF2E7D32)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Watch tab (monitor another user) ─────────────────────────────────────────

class _WatchTab extends StatefulWidget {
  final String? watchingUserId;
  final Future<void> Function(String) onSave;
  final bool triggering;
  final Future<void> Function() onTrigger;

  const _WatchTab({
    required this.watchingUserId,
    required this.onSave,
    required this.triggering,
    required this.onTrigger,
  });

  @override
  State<_WatchTab> createState() => _WatchTabState();
}

class _WatchTabState extends State<_WatchTab> {
  final _controller = TextEditingController();
  String? _relationshipStatus;

  @override
  void initState() {
    super.initState();
    if (widget.watchingUserId != null) {
      _controller.text = widget.watchingUserId!;
    }
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final id = widget.watchingUserId;
    if (id == null) return;
    final status = await SupabaseService.instance.getRelationshipStatusForGuardian(id);
    if (mounted) setState(() => _relationshipStatus = status);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Paste user ID here',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.person_search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final id = _controller.text.trim();
                  if (id.isNotEmpty) widget.onSave(id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Watch'),
              ),
            ],
          ),
        ),
        if (widget.watchingUserId != null) ...[
          if (_relationshipStatus != 'approved')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: const Color(0xFFFFF3E0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Waiting for user approval before you can view logs or trigger alarms.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (widget.triggering || _relationshipStatus != 'approved')
                    ? null
                    : widget.onTrigger,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: widget.triggering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.alarm),
                label: const Text('Trigger Alarm Now', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Activity',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MedicationLog>>(
              stream: _relationshipStatus != 'approved'
                  ? const Stream.empty()
                  : SupabaseService.instance.watchUserLogs(widget.watchingUserId!),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final logs = snap.data ?? [];
                if (logs.isEmpty) {
                  return const Center(
                    child: Text('No data yet.', style: TextStyle(color: Colors.grey)),
                  );
                }

                // Group logs by date
                final grouped = <String, List<MedicationLog>>{};
                for (final log in logs) {
                  final dateStr = _formatGroupDate(log.scheduledTime);
                  grouped.putIfAbsent(dateStr, () => []).add(log);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, i) {
                    final date = grouped.keys.elementAt(i);
                    final dateLogs = grouped[date]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ...dateLogs.map((log) => _GuardianLogTile(log: log)).toList(),
                        const Divider(height: 32),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ] else
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Enter the user ID of the person you want to monitor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('d MMMM').format(date);
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

    final icon = log.isTaken
        ? Icons.check_circle
        : log.isMissed
            ? Icons.cancel
            : Icons.schedule;

    final label = log.isTaken
        ? 'Taken'
        : log.isMissed
            ? 'MISSED'
            : 'Pending';

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(log.medicationName),
      subtitle: Text(DateFormat('d MMM, h:mm a').format(log.scheduledTime)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
