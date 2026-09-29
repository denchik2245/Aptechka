import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';

class AppState {
  const AppState({
    required this.pharmacies,
    required this.selectedPharmacyId,
    required this.medicines,
    required this.reminders,
    required this.intakeRecords,
  });

  final List<Pharmacy> pharmacies;
  final String selectedPharmacyId;
  final List<Medicine> medicines;
  final List<MedicationReminder> reminders;
  final List<IntakeRecord> intakeRecords;

  Pharmacy get selectedPharmacy => pharmacies.firstWhere(
    (pharmacy) => pharmacy.id == selectedPharmacyId,
    orElse: () => pharmacies.first,
  );

  List<Medicine> medicinesIn(String pharmacyId) =>
      medicines.where((medicine) => medicine.pharmacyId == pharmacyId).toList();

  AppState copyWith({
    List<Pharmacy>? pharmacies,
    String? selectedPharmacyId,
    List<Medicine>? medicines,
    List<MedicationReminder>? reminders,
    List<IntakeRecord>? intakeRecords,
  }) => AppState(
    pharmacies: pharmacies ?? this.pharmacies,
    selectedPharmacyId: selectedPharmacyId ?? this.selectedPharmacyId,
    medicines: medicines ?? this.medicines,
    reminders: reminders ?? this.reminders,
    intakeRecords: intakeRecords ?? this.intakeRecords,
  );

  Map<String, Object?> toJson() => {
    'pharmacies': pharmacies.map((item) => item.toJson()).toList(),
    'selectedPharmacyId': selectedPharmacyId,
    'medicines': medicines.map((item) => item.toJson()).toList(),
    'reminders': reminders.map((item) => item.toJson()).toList(),
    'intakeRecords': intakeRecords.map((item) => item.toJson()).toList(),
  };

  factory AppState.fromJson(Map<String, Object?> json) {
    final rawPharmacies = json['pharmacies'] as List<Object?>?;
    final pharmacies = rawPharmacies == null || rawPharmacies.isEmpty
        ? const [
            Pharmacy(
              id: 'home',
              name: 'Дом',
              ownerLabel: 'Вы',
              isShared: false,
              canEdit: true,
            ),
          ]
        : rawPharmacies
              .map(
                (item) =>
                    Pharmacy.fromJson(Map<String, Object?>.from(item! as Map)),
              )
              .toList();
    final selected = json['selectedPharmacyId'] as String?;
    return AppState(
      pharmacies: pharmacies,
      selectedPharmacyId: pharmacies.any((item) => item.id == selected)
          ? selected!
          : pharmacies.first.id,
      medicines: (json['medicines'] as List<Object?>? ?? const [])
          .map(
            (item) =>
                Medicine.fromJson(Map<String, Object?>.from(item! as Map)),
          )
          .toList(),
      reminders: (json['reminders'] as List<Object?>? ?? const [])
          .map(
            (item) => MedicationReminder.fromJson(
              Map<String, Object?>.from(item! as Map),
            ),
          )
          .toList(),
      intakeRecords: (json['intakeRecords'] as List<Object?>? ?? const [])
          .map(
            (item) =>
                IntakeRecord.fromJson(Map<String, Object?>.from(item! as Map)),
          )
          .toList(),
    );
  }
}
