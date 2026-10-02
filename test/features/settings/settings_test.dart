import 'dart:convert';

import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/medicine_repository.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'legacy data gets defaults; settings persist and startup pharmacy applies',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = LocalMedicineRepository(prefs);
      final original = await repository.load();
      final oldJson = original.toJson()..remove('settings');
      await prefs.setString('aptechka_state_v1', jsonEncode(oldJson));
      final migrated = await repository.load();
      expect(migrated.settings.expiryWarningDays, 30);
      final updated = migrated.copyWith(
        settings: const AppSettings(
          appearance: AppAppearance.dark,
          textScale: 1.3,
          expiryWarningDays: 7,
          defaultPharmacyId: 'mother',
          stockAlerts: false,
          inventorySort: InventorySort.expiry,
        ),
      );
      await repository.save(updated);
      final loaded = await repository.load();
      expect(loaded.settings.toJson(), updated.settings.toJson());
      expect(loaded.selectedPharmacyId, 'mother');
    },
  );

  test(
    'backup preserves all data and rejects corruption and orphan references',
    () async {
      final repository = LocalMedicineRepository(
        await SharedPreferences.getInstance(),
      );
      final original = (await repository.load()).copyWith(
        settings: const AppSettings(
          appearance: AppAppearance.dark,
          expiryWarningDays: 14,
        ),
        intakeRecords: [
          IntakeRecord(
            reminderId: 'reminder-loratadine',
            occurredAt: DateTime(2026, 10, 1),
            status: IntakeStatus.taken,
          ),
        ],
      );
      expect(
        BackupCodec.decode(BackupCodec.encode(original)).toJson(),
        original.toJson(),
      );
      expect(() => BackupCodec.decode('{oops'), throwsFormatException);
      expect(
        () => BackupCodec.decode('{"app":"aptechka","version":2}'),
        throwsFormatException,
      );
      final copy = jsonDecode(BackupCodec.encode(original)) as Map;
      ((copy['data'] as Map)['medicines'] as List).first['pharmacyId'] =
          'missing';
      expect(() => BackupCodec.decode(jsonEncode(copy)), throwsFormatException);
      final invalidSettings = jsonDecode(BackupCodec.encode(original)) as Map;
      ((invalidSettings['data'] as Map)['settings']
              as Map)['expiryWarningDays'] =
          -5;
      expect(
        () => BackupCodec.decode(jsonEncode(invalidSettings)),
        throwsFormatException,
      );
      final duplicate = jsonDecode(BackupCodec.encode(original)) as Map;
      final medicines = (duplicate['data'] as Map)['medicines'] as List;
      medicines.add(medicines.first);
      expect(
        () => BackupCodec.decode(jsonEncode(duplicate)),
        throwsFormatException,
      );
    },
  );

  test(
    'pausing reminder preserves history; clearing persists an empty inventory',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final original = await container.read(appControllerProvider.future);
      final controller = container.read(appControllerProvider.notifier);
      await controller.recordIntake(
        original.reminders.first.id,
        IntakeStatus.taken,
      );
      await controller.setReminderEnabled(original.reminders.first.id, false);
      expect(
        container
            .read(appControllerProvider)
            .requireValue
            .reminders
            .first
            .enabled,
        false,
      );
      expect(
        container.read(appControllerProvider).requireValue.intakeRecords,
        hasLength(1),
      );
      await controller.clearInventory();
      final loaded = await LocalMedicineRepository(
        await SharedPreferences.getInstance(),
      ).load();
      expect(loaded.medicines, isEmpty);
      expect(loaded.reminders, isEmpty);
      expect(loaded.intakeRecords, isEmpty);
      expect(loaded.pharmacies, hasLength(original.pharmacies.length));
    },
  );

  test('warning window includes the earlier expiry after opening', () async {
    final original = await LocalMedicineRepository(
      await SharedPreferences.getInstance(),
    ).load();
    final drops = original.medicines.firstWhere(
      (item) => item.id == 'drops-demo',
    );
    expect(drops.statusAt(DateTime.now(), warningDays: 7).name, 'okay');
    expect(
      drops.statusAt(DateTime.now(), warningDays: 14).name,
      'expiringSoon',
    );
  });
}
