enum IntakeStatus { taken, skipped }

class MedicationReminder {
  const MedicationReminder({
    required this.id,
    required this.medicineId,
    required this.hour,
    required this.minute,
    required this.dose,
    required this.enabled,
  });

  final String id;
  final String medicineId;
  final int hour;
  final int minute;
  final String dose;
  final bool enabled;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
    'id': id,
    'medicineId': medicineId,
    'hour': hour,
    'minute': minute,
    'dose': dose,
    'enabled': enabled,
  };

  factory MedicationReminder.fromJson(Map<String, Object?> json) =>
      MedicationReminder(
        id: json['id']! as String,
        medicineId: json['medicineId']! as String,
        hour: json['hour']! as int,
        minute: json['minute']! as int,
        dose: json['dose']! as String,
        enabled: json['enabled']! as bool,
      );
}

class IntakeRecord {
  const IntakeRecord({
    required this.reminderId,
    required this.occurredAt,
    required this.status,
  });

  final String reminderId;
  final DateTime occurredAt;
  final IntakeStatus status;

  Map<String, Object?> toJson() => {
    'reminderId': reminderId,
    'occurredAt': occurredAt.toIso8601String(),
    'status': status.name,
  };

  factory IntakeRecord.fromJson(Map<String, Object?> json) => IntakeRecord(
    reminderId: json['reminderId']! as String,
    occurredAt: DateTime.parse(json['occurredAt']! as String),
    status: IntakeStatus.values.byName(json['status']! as String),
  );
}
