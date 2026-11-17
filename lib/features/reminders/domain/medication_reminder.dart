import 'treatment_course.dart';

enum IntakeStatus { taken, skipped, deferred }

class MedicationReminder {
  const MedicationReminder({
    required this.id,
    required this.medicineId,
    required this.hour,
    required this.minute,
    required this.dose,
    required this.enabled,
    this.courseId,
    this.amount = 1,
    this.unit = '',
    this.condition = '',
    this.hint = '',
    this.frequency = IntakeFrequency.daily,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.cycleDays = 60,
    this.breakDays = 30,
    this.durationDays,
  });
  final String id, medicineId, dose, unit, condition, hint;
  final String? courseId;
  final int hour, minute, amount, cycleDays, breakDays;
  final int? durationDays;
  final bool enabled;
  final IntakeFrequency frequency;
  final List<int> weekdays;
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  bool occursOn(DateTime day, DateTime start) {
    final offset = treatmentDaysBetween(start, day);
    if (offset < 0 || (durationDays != null && offset >= durationDays!)) {
      return false;
    }
    return switch (frequency) {
      IntakeFrequency.daily => true,
      IntakeFrequency.alternate => offset.isEven,
      IntakeFrequency.weekdays => weekdays.contains(day.weekday),
      IntakeFrequency.cycles => offset % (cycleDays + breakDays) < cycleDays,
    };
  }

  MedicationReminder copyWith({
    String? id,
    String? medicineId,
    String? courseId,
    bool? enabled,
    int? hour,
    int? minute,
    String? dose,
  }) => MedicationReminder(
    id: id ?? this.id,
    medicineId: medicineId ?? this.medicineId,
    courseId: courseId ?? this.courseId,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    dose: dose ?? this.dose,
    enabled: enabled ?? this.enabled,
    amount: amount,
    unit: unit,
    condition: condition,
    hint: hint,
    frequency: frequency,
    weekdays: weekdays,
    cycleDays: cycleDays,
    breakDays: breakDays,
    durationDays: durationDays,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'medicineId': medicineId,
    'hour': hour,
    'minute': minute,
    'dose': dose,
    'enabled': enabled,
    'courseId': courseId,
    'amount': amount,
    'unit': unit,
    'condition': condition,
    'hint': hint,
    'frequency': frequency.name,
    'weekdays': weekdays,
    'cycleDays': cycleDays,
    'breakDays': breakDays,
    'durationDays': durationDays,
  };
  factory MedicationReminder.fromJson(Map<String, Object?> j) =>
      MedicationReminder(
        id: j['id']! as String,
        medicineId: j['medicineId']! as String,
        hour: j['hour']! as int,
        minute: j['minute']! as int,
        dose: j['dose']! as String,
        enabled: j['enabled']! as bool,
        courseId: j['courseId'] as String?,
        amount: j['amount'] as int? ?? 1,
        unit: j['unit'] as String? ?? '',
        condition: j['condition'] as String? ?? '',
        hint: j['hint'] as String? ?? '',
        frequency: IntakeFrequency.values.byName(
          j['frequency'] as String? ?? 'daily',
        ),
        weekdays:
            (j['weekdays'] as List?)?.cast<int>() ??
            const [1, 2, 3, 4, 5, 6, 7],
        cycleDays: j['cycleDays'] as int? ?? 60,
        breakDays: j['breakDays'] as int? ?? 30,
        durationDays: j['durationDays'] as int?,
      );
}

class IntakeRecord {
  const IntakeRecord({
    required this.reminderId,
    required this.occurredAt,
    required this.status,
    this.scheduledDate,
    this.deferredUntil,
    this.reason = '',
    this.stockDelta = 0,
  });
  final String reminderId, reason;
  final DateTime occurredAt;
  final DateTime? scheduledDate, deferredUntil;
  final IntakeStatus status;

  /// Actual inventory units removed, so correcting an entry can safely undo it.
  final int stockDelta;
  DateTime get day => treatmentDay(scheduledDate ?? occurredAt);
  Map<String, Object?> toJson() => {
    'reminderId': reminderId,
    'occurredAt': occurredAt.toIso8601String(),
    'status': status.name,
    'scheduledDate': scheduledDate?.toIso8601String(),
    'deferredUntil': deferredUntil?.toIso8601String(),
    'reason': reason,
    'stockDelta': stockDelta,
  };
  factory IntakeRecord.fromJson(Map<String, Object?> j) => IntakeRecord(
    reminderId: j['reminderId']! as String,
    occurredAt: DateTime.parse(j['occurredAt']! as String),
    status: IntakeStatus.values.byName(j['status']! as String),
    scheduledDate: j['scheduledDate'] == null
        ? null
        : DateTime.parse(j['scheduledDate']! as String),
    deferredUntil: j['deferredUntil'] == null
        ? null
        : DateTime.parse(j['deferredUntil']! as String),
    reason: j['reason'] as String? ?? '',
    stockDelta: j['stockDelta'] as int? ?? 0,
  );
}
