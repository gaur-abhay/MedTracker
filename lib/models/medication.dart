import 'package:uuid/uuid.dart';

class Medication {
  final String id;
  final String name;
  final List<String> times; // "HH:mm" format

  Medication({
    String? id,
    required this.name,
    required this.times,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'times': times,
      };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as String,
        name: json['name'] as String,
        times: List<String>.from(json['times'] as List),
      );
}
