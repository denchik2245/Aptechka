import 'package:aptechka/features/inventory/data/medicine_repository.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends AsyncNotifier<AppState> {
  MedicineRepository? _repository;
  final _uuid = const Uuid();

  @override
  Future<AppState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = LocalMedicineRepository(preferences);
    return _repository!.load();
  }

  Future<void> addMedicine({
    required String name,
    required String form,
    required String dosage,
    required int quantity,
    required String unit,
    DateTime? expiryDate,
    required String location,
    DateTime? openedAt,
    int? afterOpeningDays,
    String? activeIngredient,
    String? gtin,
    bool createReminder = false,
    int reminderHour = 9,
    int reminderMinute = 0,
    String reminderDose = '1 доза',
  }) async {
    final current = state.requireValue;
    if (!current.selectedPharmacy.canEdit) return;
    final medicineId = _uuid.v4();
    final medicine = Medicine(
      id: medicineId,
      pharmacyId: current.selectedPharmacyId,
      name: name.trim(),
      activeIngredient: activeIngredient?.trim().isEmpty == true
          ? null
          : activeIngredient?.trim(),
      form: form.trim(),
      dosage: dosage.trim(),
      quantity: quantity,
      unit: unit.trim(),
      expiryDate: expiryDate,
      openedAt: openedAt,
      afterOpeningDays: afterOpeningDays,
      location: location.trim(),
      gtin: gtin?.trim().isEmpty == true ? null : gtin?.trim(),
    );
    final updatedReminders = [...current.reminders];
    if (createReminder) {
      updatedReminders.add(
        MedicationReminder(
          id: _uuid.v4(),
          medicineId: medicineId,
          hour: reminderHour,
          minute: reminderMinute,
          dose: reminderDose.trim(),
          enabled: true,
        ),
      );
    }
    final updated = current.copyWith(
      medicines: [...current.medicines, medicine],
      reminders: updatedReminders,
    );
    state = AsyncData(updated);
    await _repository!.save(updated);
  }

  Future<void> selectPharmacy(String pharmacyId) async {
    final current = state.requireValue;
    if (!current.pharmacies.any((item) => item.id == pharmacyId)) return;
    final updated = current.copyWith(selectedPharmacyId: pharmacyId);
    state = AsyncData(updated);
    await _repository!.save(updated);
  }

  Future<void> createPharmacy(String name) async {
    final current = state.requireValue;
    final pharmacy = Pharmacy(
      id: _uuid.v4(),
      name: name.trim(),
      ownerLabel: 'Вы',
      isShared: false,
      canEdit: true,
    );
    final updated = current.copyWith(
      pharmacies: [...current.pharmacies, pharmacy],
      selectedPharmacyId: pharmacy.id,
    );
    state = AsyncData(updated);
    await _repository!.save(updated);
  }

  Future<void> updatePackage({
    required String medicineId,
    int? quantity,
    String? location,
    DateTime? expiryDate,
    DateTime? openedAt,
    int? afterOpeningDays,
  }) async {
    final current = state.requireValue;
    final package = current.medicines
        .where((item) => item.id == medicineId)
        .firstOrNull;
    if (package == null) return;
    final pharmacy = current.pharmacies
        .where((item) => item.id == package.pharmacyId)
        .firstOrNull;
    if (pharmacy?.canEdit != true) return;
    final updated = current.copyWith(
      medicines: current.medicines
          .map(
            (item) => item.id == medicineId
                ? item.copyWith(
                    quantity: quantity,
                    location: location,
                    expiryDate: expiryDate,
                    clearExpiryDate: expiryDate == null,
                    openedAt: openedAt,
                    clearOpenedAt: openedAt == null,
                    afterOpeningDays: afterOpeningDays,
                    clearAfterOpeningDays: afterOpeningDays == null,
                  )
                : item,
          )
          .toList(),
    );
    state = AsyncData(updated);
    await _repository!.save(updated);
  }

  Future<void> recordIntake(String reminderId, IntakeStatus status) async {
    final current = state.requireValue;
    final today = DateTime.now();
    final recordsWithoutToday = current.intakeRecords.where((record) {
      return record.reminderId != reminderId ||
          record.occurredAt.year != today.year ||
          record.occurredAt.month != today.month ||
          record.occurredAt.day != today.day;
    }).toList();
    final updated = current.copyWith(
      intakeRecords: [
        ...recordsWithoutToday,
        IntakeRecord(reminderId: reminderId, occurredAt: today, status: status),
      ],
    );
    state = AsyncData(updated);
    await _repository!.save(updated);
  }
}
