import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';

class AppState {
  const AppState({
    required this.medicines,
    required this.reminders,
    required this.intakeRecords,
  });

  final List<Medicine> medicines;
  final List<MedicationReminder> reminders;
  final List<IntakeRecord> intakeRecords;

  AppState copyWith({
    List<Medicine>? medicines,
    List<MedicationReminder>? reminders,
    List<IntakeRecord>? intakeRecords,
  }) => AppState(
    medicines: medicines ?? this.medicines,
    reminders: reminders ?? this.reminders,
    intakeRecords: intakeRecords ?? this.intakeRecords,
  );

  Map<String, Object?> toJson() => {
    'medicines': medicines.map((item) => item.toJson()).toList(),
    'reminders': reminders.map((item) => item.toJson()).toList(),
    'intakeRecords': intakeRecords.map((item) => item.toJson()).toList(),
  };

  factory AppState.fromJson(Map<String, Object?> json) => AppState(
    medicines: (json['medicines']! as List<Object?>)
        .map(
          (item) => Medicine.fromJson(Map<String, Object?>.from(item! as Map)),
        )
        .toList(),
    reminders: (json['reminders']! as List<Object?>)
        .map(
          (item) => MedicationReminder.fromJson(
            Map<String, Object?>.from(item! as Map),
          ),
        )
        .toList(),
    intakeRecords: (json['intakeRecords']! as List<Object?>)
        .map(
          (item) =>
              IntakeRecord.fromJson(Map<String, Object?>.from(item! as Map)),
        )
        .toList(),
  );
}
