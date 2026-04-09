enum MedicationStatus { scheduled, alarmTriggered, taken, missed, snoozed }

class MedicationLog {
  final String id;
  final String medicationId;
  final String medicationName;
  final DateTime scheduledTime;
  DateTime? takenTime;
  MedicationStatus status;

  MedicationLog({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.scheduledTime,
    this.takenTime,
    this.status = MedicationStatus.scheduled,
  });

  bool get isTaken => status == MedicationStatus.taken;
  bool get isMissed => status == MedicationStatus.missed;
  bool get isPending =>
      status == MedicationStatus.scheduled ||
      status == MedicationStatus.alarmTriggered ||
      status == MedicationStatus.snoozed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'medication_id': medicationId,
        'medication_name': medicationName,
        'scheduled_time': scheduledTime.toIso8601String(),
        'taken_time': takenTime?.toIso8601String(),
        'status': status.name,
      };

  factory MedicationLog.fromJson(Map<String, dynamic> json) => MedicationLog(
        id: json['id'] as String,
        medicationId: (json['medication_id'] ?? json['medicationId']) as String,
        medicationName: (json['medication_name'] ?? json['medicationName']) as String,
        scheduledTime: DateTime.parse((json['scheduled_time'] ?? json['scheduledTime']) as String),
        takenTime: (json['taken_time'] ?? json['takenTime']) != null
            ? DateTime.parse((json['taken_time'] ?? json['takenTime']) as String)
            : null,
        status: MedicationStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => MedicationStatus.scheduled,
        ),
      );
}
