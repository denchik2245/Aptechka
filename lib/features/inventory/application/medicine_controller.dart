import 'package:aptechka/features/accounts/application/account_controller.dart';
import 'package:aptechka/features/accounts/data/local_profile_import.dart';
import 'package:aptechka/features/inventory/data/medicine_repository.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends AsyncNotifier<AppState> {
  MedicineRepository? _repository;
  final _uuid = const Uuid();

  @override
  Future<AppState> build() async {
    final scopeId = ref.watch(activeProfileIdProvider);
    final preferences = await SharedPreferences.getInstance();
    _repository = LocalMedicineRepository(preferences, profileScopeId: scopeId);
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
    String? catalogEntryId,
    String? manufacturer,
    String? packageDescription,
    String? registrationId,
    String? registrationStatus,
    String? catalogVersion,
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
      catalogEntryId: catalogEntryId,
      manufacturer: manufacturer,
      packageDescription: packageDescription,
      registrationId: registrationId,
      registrationStatus: registrationStatus,
      catalogVersion: catalogVersion,
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
    await _commit(updated);
  }

  Future<void> selectPharmacy(String pharmacyId) async {
    final current = state.requireValue;
    if (!current.pharmacies.any((item) => item.id == pharmacyId)) return;
    final updated = current.copyWith(selectedPharmacyId: pharmacyId);
    await _commit(updated);
  }

  Future<void> createPharmacy(String name) async {
    final current = state.requireValue;
    final pharmacy = Pharmacy(
      id: _uuid.v4(),
      name: name.trim(),
      ownerLabel: 'Вы',
      isShared: false,
      canEdit: true,
      ownerAccountId: current.profileScopeId == 'guest'
          ? null
          : current.profileScopeId,
    );
    final updated = current.copyWith(
      pharmacies: [...current.pharmacies, pharmacy],
      selectedPharmacyId: pharmacy.id,
    );
    await _commit(updated);
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
    await _commit(updated);
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
    await _commit(updated);
  }

  Future<void> _commit(AppState updated) async {
    final scopeId = updated.profileScopeId;
    if (scopeId != ref.read(activeProfileIdProvider)) {
      throw StateError('Профиль изменился. Повторите действие.');
    }
    final repository = _repository!;
    await repository.save(updated);
    if (ref.read(activeProfileIdProvider) == scopeId) {
      state = AsyncData(updated);
    }
  }

  Future<void> updateSettings(AppSettings settings) =>
      _commit(state.requireValue.copyWith(settings: settings));

  Future<void> restoreBackup(AppState backup) {
    final scopeId = state.requireValue.profileScopeId;
    return _commit(
      backup.copyWith(
        profileScopeId: scopeId,
        pharmacies: backup.pharmacies
            .map((item) => scopeId == 'guest' ? item : item.withOwner(scopeId))
            .toList(),
      ),
    );
  }

  Future<AppState> guestData() async =>
      LocalMedicineRepository(await SharedPreferences.getInstance()).load();

  Future<void> copyGuestPharmacies(Set<String> ids) async {
    final current = state.requireValue;
    if (current.profileScopeId == 'guest') {
      throw StateError('Сначала войдите в демо-профиль');
    }
    final guest = await guestData();
    await _commit(
      LocalProfileImport.copy(guest: guest, target: current, pharmacyIds: ids),
    );
  }

  Future<void> clearInventory() => _commit(
    state.requireValue.copyWith(
      medicines: const [],
      reminders: const [],
      intakeRecords: const [],
    ),
  );

  Future<void> setReminderEnabled(String id, bool enabled) {
    final current = state.requireValue;
    return _commit(
      current.copyWith(
        reminders: current.reminders
            .map(
              (item) => item.id != id
                  ? item
                  : MedicationReminder(
                      id: item.id,
                      medicineId: item.medicineId,
                      hour: item.hour,
                      minute: item.minute,
                      dose: item.dose,
                      enabled: enabled,
                    ),
            )
            .toList(),
      ),
    );
  }
}
