enum CourseStatus { active, paused, completed }

enum IntakeFrequency { daily, alternate, weekdays, cycles }

DateTime treatmentDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);
int treatmentDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

class TreatmentCourse {
  const TreatmentCourse({
    required this.id,
    required this.name,
    required this.person,
    required this.startsAt,
    this.durationDays = 7,
    this.status = CourseStatus.active,
    this.notifications = true,
    this.repeatMinutes = 10,
    this.stockAlert = true,
    this.notifyFamily = false,
    this.visibility = 'Только я',
    this.prescription,
    this.completedAt,
  });
  final String id, name, person, visibility;
  final DateTime startsAt;
  final int? durationDays;
  final CourseStatus status;
  final bool notifications, stockAlert, notifyFamily;
  final int repeatMinutes;

  /// A local data URI, included in profile storage and backups.
  final String? prescription;
  final DateTime? completedAt;
  DateTime? get endsAt => durationDays == null
      ? null
      : DateTime(
          startsAt.year,
          startsAt.month,
          startsAt.day + durationDays! - 1,
        );
  bool isCompletedAt(DateTime day) =>
      status == CourseStatus.completed ||
      (endsAt != null && treatmentDay(day).isAfter(endsAt!));
  bool includes(DateTime day) =>
      !treatmentDay(day).isBefore(treatmentDay(startsAt)) &&
      (endsAt == null || !treatmentDay(day).isAfter(endsAt!)) &&
      (completedAt == null ||
          !treatmentDay(day).isAfter(treatmentDay(completedAt!)));
  int dayNumber(DateTime day) => (treatmentDaysBetween(startsAt, day) + 1)
      .clamp(0, durationDays ?? 100000);
  TreatmentCourse copyWith({
    String? name,
    String? person,
    DateTime? startsAt,
    int? durationDays,
    bool indefinite = false,
    CourseStatus? status,
    bool? notifications,
    int? repeatMinutes,
    bool? stockAlert,
    bool? notifyFamily,
    String? visibility,
    String? prescription,
    DateTime? completedAt,
  }) => TreatmentCourse(
    id: id,
    name: name ?? this.name,
    person: person ?? this.person,
    startsAt: startsAt ?? this.startsAt,
    durationDays: indefinite ? null : durationDays ?? this.durationDays,
    status: status ?? this.status,
    notifications: notifications ?? this.notifications,
    repeatMinutes: repeatMinutes ?? this.repeatMinutes,
    stockAlert: stockAlert ?? this.stockAlert,
    notifyFamily: notifyFamily ?? this.notifyFamily,
    visibility: visibility ?? this.visibility,
    prescription: prescription ?? this.prescription,
    completedAt: completedAt ?? this.completedAt,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'person': person,
    'startsAt': startsAt.toIso8601String(),
    'durationDays': durationDays,
    'status': status.name,
    'notifications': notifications,
    'repeatMinutes': repeatMinutes,
    'stockAlert': stockAlert,
    'notifyFamily': notifyFamily,
    'visibility': visibility,
    'prescription': prescription,
    'completedAt': completedAt?.toIso8601String(),
  };
  factory TreatmentCourse.fromJson(Map<String, Object?> j) => TreatmentCourse(
    id: j['id']! as String,
    name: j['name']! as String,
    person: j['person']! as String,
    startsAt: DateTime.parse(j['startsAt']! as String),
    durationDays: j['durationDays'] as int?,
    status: CourseStatus.values.byName(j['status'] as String? ?? 'active'),
    notifications: j['notifications'] as bool? ?? true,
    repeatMinutes: j['repeatMinutes'] as int? ?? 10,
    stockAlert: j['stockAlert'] as bool? ?? true,
    notifyFamily: j['notifyFamily'] as bool? ?? false,
    visibility: j['visibility'] as String? ?? 'Только я',
    prescription: j['prescription'] as String?,
    completedAt: j['completedAt'] == null
        ? null
        : DateTime.parse(j['completedAt']! as String),
  );
}
