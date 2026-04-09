import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/medication_log.dart';
import '../providers/medication_provider.dart';
import 'add_medication_screen.dart';
import 'history_screen.dart';
import 'guardian_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh missed status every minute
    Future.delayed(const Duration(minutes: 1), _periodicRefresh);
  }

  void _periodicRefresh() {
    if (!mounted) return;
    context.read<MedicationProvider>().refresh();
    Future.delayed(const Duration(minutes: 1), _periodicRefresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('My Medications'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Guardian',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GuardianScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<MedicationProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _StreakBanner(streak: provider.streakDays),
              Expanded(
                child: provider.medications.isEmpty
                    ? _EmptyState(
                        onAdd: () => _openAddMedication(context),
                      )
                    : _TodayList(provider: provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddMedication(context),
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Medication', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _openAddMedication(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
    );
  }
}

// ── Streak banner ─────────────────────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  final int streak;
  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF2E7D32),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Text(
            streak == 0
                ? 'Start your streak today!'
                : '$streak day streak — keep it up!',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Today's schedule list ─────────────────────────────────────────────────────

class _TodayList extends StatelessWidget {
  final MedicationProvider provider;
  const _TodayList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final logs = provider.todayLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            DateFormat('EEEE, d MMMM').format(DateTime.now()),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: logs.isEmpty ? 1 : logs.length,
            itemBuilder: (context, i) {
              if (logs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'No doses scheduled for today.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return _LogCard(log: logs[i], provider: provider);
            },
          ),
        ),
      ],
    );
  }
}

// ── Individual log card ───────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final MedicationLog log;
  final MedicationProvider provider;

  const _LogCard({required this.log, required this.provider});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(log.scheduledTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _StatusIcon(status: log.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.medicationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusText(log),
                    style: TextStyle(
                      fontSize: 13,
                      color: _statusColor(log.status),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            if (log.isPending) ...[
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => provider.markTaken(log),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Taken'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusText(MedicationLog log) {
    switch (log.status) {
      case MedicationStatus.taken:
        final t = log.takenTime;
        if (t != null) return 'Taken at ${DateFormat('h:mm a').format(t)}';
        return 'Taken';
      case MedicationStatus.missed:
        return 'Missed';
      case MedicationStatus.snoozed:
        return 'Snoozed';
      default:
        final now = DateTime.now();
        if (log.scheduledTime.isAfter(now)) {
          return 'Upcoming';
        }
        return 'Due now';
    }
  }

  Color _statusColor(MedicationStatus status) {
    switch (status) {
      case MedicationStatus.taken:
        return const Color(0xFF2E7D32);
      case MedicationStatus.missed:
        return Colors.red;
      case MedicationStatus.snoozed:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final MedicationStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MedicationStatus.taken:
        return const CircleAvatar(
          radius: 20,
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.check, color: Color(0xFF2E7D32), size: 20),
        );
      case MedicationStatus.missed:
        return const CircleAvatar(
          radius: 20,
          backgroundColor: Color(0xFFFFEBEE),
          child: Icon(Icons.close, color: Colors.red, size: 20),
        );
      case MedicationStatus.snoozed:
        return const CircleAvatar(
          radius: 20,
          backgroundColor: Color(0xFFFFF3E0),
          child: Icon(Icons.snooze, color: Colors.orange, size: 20),
        );
      default:
        return const CircleAvatar(
          radius: 20,
          backgroundColor: Color(0xFFF5F5F5),
          child: Icon(Icons.medication, color: Colors.grey, size: 20),
        );
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No medications yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to add your first medication',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Medication'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
