import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';

abstract final class LocalProfileImport {
  // Copies rather than removes guest data. Stable origin IDs make retries idempotent.
  static AppState copy({
    required AppState guest,
    required AppState target,
    required Set<String> pharmacyIds,
  }) {
    if (guest.profileScopeId != 'guest' || target.profileScopeId == 'guest') {
      throw StateError('Неверный источник переноса');
    }
    String mapped(String id) => 'guest:${target.profileScopeId}:$id';
    final selected = guest.pharmacies
        .where((item) => pharmacyIds.contains(item.id) && item.canEdit)
        .toList();
    final selectedIds = selected.map((item) => item.id).toSet();
    final packages = guest.medicines
        .where((item) => selectedIds.contains(item.pharmacyId))
        .toList();
    final packageIds = packages.map((item) => item.id).toSet();
    final reminders = guest.reminders
        .where((item) => packageIds.contains(item.medicineId))
        .toList();
    final reminderIds = reminders.map((item) => item.id).toSet();
    final existingPharmacies = target.pharmacies.map((item) => item.id).toSet();
    final existingPackages = target.medicines.map((item) => item.id).toSet();
    final existingReminders = target.reminders.map((item) => item.id).toSet();
    final records = target.intakeRecords
        .map(
          (item) => '${item.reminderId}:${item.occurredAt.toIso8601String()}',
        )
        .toSet();
    return target.copyWith(
      pharmacies: [
        ...target.pharmacies,
        ...selected
            .where((item) => !existingPharmacies.contains(mapped(item.id)))
            .map(
              (item) => Pharmacy(
                id: mapped(item.id),
                name: item.name,
                ownerLabel: 'Вы',
                isShared: item.isShared,
                canEdit: true,
                ownerAccountId: target.profileScopeId,
              ),
            ),
      ],
      medicines: [
        ...target.medicines,
        ...packages
            .where((item) => !existingPackages.contains(mapped(item.id)))
            .map(
              (item) => item.copyWith(
                id: mapped(item.id),
                pharmacyId: mapped(item.pharmacyId),
              ),
            ),
      ],
      reminders: [
        ...target.reminders,
        ...reminders
            .where((item) => !existingReminders.contains(mapped(item.id)))
            .map(
              (item) => MedicationReminder(
                id: mapped(item.id),
                medicineId: mapped(item.medicineId),
                hour: item.hour,
                minute: item.minute,
                dose: item.dose,
                enabled: item.enabled,
              ),
            ),
      ],
      intakeRecords: [
        ...target.intakeRecords,
        ...guest.intakeRecords
            .where(
              (item) =>
                  reminderIds.contains(item.reminderId) &&
                  !records.contains(
                    '${mapped(item.reminderId)}:${item.occurredAt.toIso8601String()}',
                  ),
            )
            .map(
              (item) => IntakeRecord(
                reminderId: mapped(item.reminderId),
                occurredAt: item.occurredAt,
                status: item.status,
              ),
            ),
      ],
      selectedPharmacyId: selected.isEmpty
          ? target.selectedPharmacyId
          : mapped(selected.first.id),
    );
  }
}
