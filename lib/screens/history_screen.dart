import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/medication_log.dart';
import '../providers/medication_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<MedicationProvider>(
        builder: (context, provider, _) {
          final logs = provider.logs
            ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

          if (logs.isEmpty) {
            return const Center(
              child: Text('No history yet.', style: TextStyle(color: Colors.grey)),
            );
          }

          // Group by date
          final grouped = <String, List<MedicationLog>>{};
          for (final log in logs) {
            final key = DateFormat('EEEE, d MMM yyyy').format(log.scheduledTime);
            grouped.putIfAbsent(key, () => []).add(log);
          }

          final dates = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dates.length,
            itemBuilder: (context, i) {
              final date = dates[i];
              final dayLogs = grouped[date]!;
              final taken = dayLogs.where((l) => l.isTaken).length;
              final total = dayLogs.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          date,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$taken / $total taken',
                          style: TextStyle(
                            fontSize: 13,
                            color: taken == total ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dayLogs.map((log) => _HistoryTile(log: log)),
                  const Divider(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final MedicationLog log;
  const _HistoryTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _icon(),
      title: Text(log.medicationName),
      subtitle: Text(
        DateFormat('h:mm a').format(log.scheduledTime),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        _label(),
        style: TextStyle(
          color: _color(),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _icon() {
    switch (log.status) {
      case MedicationStatus.taken:
        return const Icon(Icons.check_circle, color: Color(0xFF2E7D32));
      case MedicationStatus.missed:
        return const Icon(Icons.cancel, color: Colors.red);
      default:
        return const Icon(Icons.radio_button_unchecked, color: Colors.grey);
    }
  }

  String _label() {
    switch (log.status) {
      case MedicationStatus.taken:
        final t = log.takenTime;
        if (t != null) return 'Taken ${DateFormat('h:mm a').format(t)}';
        return 'Taken';
      case MedicationStatus.missed:
        return 'Missed';
      case MedicationStatus.snoozed:
        return 'Snoozed';
      default:
        return 'Pending';
    }
  }

  Color _color() {
    switch (log.status) {
      case MedicationStatus.taken:
        return const Color(0xFF2E7D32);
      case MedicationStatus.missed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
