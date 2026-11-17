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
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
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

  Future<void> setTreatmentShopping(Set<String> ids) =>
      _commit(state.requireValue.copyWith(treatmentShoppingIds: ids.toList()));

  Future<void> saveCourse(
    TreatmentCourse course,
    List<MedicationReminder> reminders,
  ) async {
    final current = state.requireValue;
    if (course.name.trim().isEmpty || reminders.isEmpty) {
      throw StateError('Добавьте название и препарат');
    }
    for (final reminder in reminders) {
      if (!current.medicines.any((m) => m.id == reminder.medicineId)) {
        throw StateError('Препарат больше не находится в аптечке');
      }
    }
    final keptIds = reminders.map((r) => r.id).toSet();
    final removedIds = current.reminders
        .where((r) => r.courseId == course.id && !keptIds.contains(r.id))
        .map((r) => r.id)
        .toSet();
    // Preserve older schedules with history, but disable them when editing a course.
    final historical = current.reminders
        .where(
          (r) =>
              removedIds.contains(r.id) &&
              current.intakeRecords.any((i) => i.reminderId == r.id),
        )
        .map((r) => r.copyWith(enabled: false));
    await _commit(
      current.copyWith(
        courses: [...current.courses.where((c) => c.id != course.id), course],
        reminders: [
          ...current.reminders.where((r) => r.courseId != course.id),
          ...historical,
          ...reminders,
        ],
      ),
    );
  }

  Future<void> updateCourse(TreatmentCourse course) => _commit(
    state.requireValue.copyWith(
      courses: state.requireValue.courses
          .map((c) => c.id == course.id ? course : c)
          .toList(),
    ),
  );

  Future<void> deleteCourse(String id) async {
    final current = state.requireValue;
    final ids = current.reminders
        .where((r) => r.courseId == id)
        .map((r) => r.id)
        .toSet();
    await _commit(
      current.copyWith(
        courses: current.courses.where((c) => c.id != id).toList(),
        reminders: current.reminders.where((r) => !ids.contains(r.id)).toList(),
        intakeRecords: current.intakeRecords
            .where((r) => !ids.contains(r.reminderId))
            .toList(),
      ),
    );
  }

  Future<void> recordIntake(
    String reminderId,
    IntakeStatus status, {
    DateTime? scheduledDate,
    DateTime? occurredAt,
    DateTime? deferredUntil,
    String reason = '',
  }) async {
    final current = state.requireValue;
    final reminder = current.reminders
        .where((r) => r.id == reminderId)
        .firstOrNull;
    if (reminder == null) return;
    final day = treatmentDay(scheduledDate ?? DateTime.now());
    if (day.isAfter(treatmentDay(DateTime.now()))) {
      throw StateError('Будущий приём пока нельзя отметить');
    }
    final old = current.intakeRecords
        .where((r) => r.reminderId == reminderId && r.day == day)
        .firstOrNull;
    final medicine = current.medicines
        .where((m) => m.id == reminder.medicineId)
        .firstOrNull;
    final available = (medicine?.quantity ?? 0) + (old?.stockDelta ?? 0);
    // Only convert identical stock/dose units; drops cannot be subtracted from a bottle or ml.
    bool sameUnit(String a, String b) =>
        a == b ||
        (a.startsWith('таблет') && b.startsWith('таблет')) ||
        (a.startsWith('капсул') && b.startsWith('капсул')) ||
        (a.startsWith('флакон') && b.startsWith('флакон'));
    final canDeduct =
        reminder.courseId != null &&
        medicine != null &&
        sameUnit(reminder.unit.toLowerCase(), medicine.unit.toLowerCase());
    final delta = status == IntakeStatus.taken && canDeduct
        ? reminder.amount.clamp(0, available)
        : 0;
    await _commit(
      current.copyWith(
        medicines: current.medicines
            .map(
              (m) => m.id == reminder.medicineId
                  ? m.copyWith(quantity: available - delta)
                  : m,
            )
            .toList(),
        intakeRecords: [
          ...current.intakeRecords.where(
            (r) => r.reminderId != reminderId || r.day != day,
          ),
          IntakeRecord(
            reminderId: reminderId,
            scheduledDate: day,
            occurredAt: occurredAt ?? DateTime.now(),
            status: status,
            deferredUntil: deferredUntil,
            reason: reason,
            stockDelta: delta,
          ),
        ],
      ),
    );
  }

  Future<void> removePackage(String medicineId) async {
    final current = state.requireValue;
    final package = current.medicines
        .where((item) => item.id == medicineId)
        .firstOrNull;
    if (package == null) return;
    final pharmacy = current.pharmacies
        .where((item) => item.id == package.pharmacyId)
        .firstOrNull;
    if (pharmacy?.canEdit != true) return;
    final removedReminderIds = current.reminders
        .where((item) => item.medicineId == medicineId)
        .map((item) => item.id)
        .toSet();
    await _commit(
      current.copyWith(
        treatmentShoppingIds: current.treatmentShoppingIds
            .where((id) => id != medicineId)
            .toList(),
        medicines: current.medicines
            .where((item) => item.id != medicineId)
            .toList(),
        reminders: current.reminders
            .where((item) => item.medicineId != medicineId)
            .toList(),
        intakeRecords: current.intakeRecords
            .where((item) => !removedReminderIds.contains(item.reminderId))
            .toList(),
      ),
    );
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
      courses: const [],
      treatmentShoppingIds: const [],
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
              (item) => item.id != id ? item : item.copyWith(enabled: enabled),
            )
            .toList(),
      ),
    );
  }
}
