import 'dart:convert';

import 'package:aptechka/features/inventory/domain/app_state.dart';

abstract final class BackupCodec {
  static String encode(AppState state) => const JsonEncoder.withIndent('  ')
      .convert({
        'app': 'aptechka',
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'data': state.toJson(),
      });

  static AppState decode(String source) {
    try {
      final envelope = jsonDecode(source) as Map;
      if (envelope['app'] != 'aptechka' || envelope['version'] != 1) {
        throw const FormatException(
          'Нужна резервная копия «Аптечки» версии 1.',
        );
      }
      final data = Map<String, Object?>.from(envelope['data'] as Map);
      for (final key in [
        'pharmacies',
        'medicines',
        'reminders',
        'intakeRecords',
      ]) {
        if (data[key] is! List) throw const FormatException();
      }
      if ((data['pharmacies'] as List).isEmpty || data['settings'] is! Map) {
        throw const FormatException();
      }
      final state = AppState.fromJson(data);
      final rawSettings = data['settings'] as Map;
      final normalizedSettings = state.settings.toJson();
      if (normalizedSettings.entries.any(
        (entry) =>
            !rawSettings.containsKey(entry.key) ||
            rawSettings[entry.key] != entry.value,
      )) {
        throw const FormatException();
      }
      bool unique(Iterable<String> ids) =>
          ids.every((id) => id.trim().isNotEmpty) &&
          ids.toSet().length == ids.length;
      if (!unique(state.pharmacies.map((item) => item.id)) ||
          !unique(state.medicines.map((item) => item.id)) ||
          !unique(state.reminders.map((item) => item.id)) ||
          !state.pharmacies.any(
            (item) => item.id == data['selectedPharmacyId'],
          ) ||
          (state.settings.defaultPharmacyId != null &&
              !state.pharmacies.any(
                (item) => item.id == state.settings.defaultPharmacyId,
              )) ||
          state.pharmacies.any((item) => item.name.trim().isEmpty) ||
          state.medicines.any(
            (item) =>
                !state.pharmacies.any(
                  (pharmacy) => pharmacy.id == item.pharmacyId,
                ) ||
                item.name.trim().isEmpty ||
                item.form.trim().isEmpty ||
                item.unit.trim().isEmpty ||
                item.quantity < 0 ||
                (item.afterOpeningDays != null && item.afterOpeningDays! <= 0),
          ) ||
          state.reminders.any(
            (item) =>
                !state.medicines.any(
                  (medicine) => medicine.id == item.medicineId,
                ) ||
                item.hour < 0 ||
                item.hour > 23 ||
                item.minute < 0 ||
                item.minute > 59 ||
                item.dose.trim().isEmpty,
          ) ||
          state.intakeRecords.any(
            (item) => !state.reminders.any(
              (reminder) => reminder.id == item.reminderId,
            ),
          )) {
        throw const FormatException();
      }
      return state;
    } on FormatException catch (error) {
      if (error.message == 'Нужна резервная копия «Аптечки» версии 1.') rethrow;
      throw const FormatException(
        'Копия повреждена или содержит некорректные записи.',
      );
    } catch (_) {
      throw const FormatException(
        'Не удалось прочитать копию. Вставьте полный JSON резервной копии.',
      );
    }
  }
}
