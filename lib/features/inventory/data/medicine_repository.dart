import 'dart:convert';

import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class MedicineRepository {
  Future<AppState> load();
  Future<void> save(AppState state);
}

class LocalMedicineRepository implements MedicineRepository {
  LocalMedicineRepository(this._preferences);

  static const _storageKey = 'aptechka_state_v1';
  final SharedPreferences _preferences;

  @override
  Future<AppState> load() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null) return _seedState();
    return AppState.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
  }

  @override
  Future<void> save(AppState state) async {
    await _preferences.setString(_storageKey, jsonEncode(state.toJson()));
  }

  AppState _seedState() {
    final today = DateTime.now();
    final medicines = [
      Medicine(
        id: 'ibuprofen-demo',
        name: 'Ибупрофен',
        activeIngredient: 'Ибупрофен',
        form: 'Таблетки',
        dosage: '200 мг',
        quantity: 14,
        unit: 'таблеток',
        expiryDate: today.add(const Duration(days: 18)),
        location: 'Верхняя полка',
        gtin: '04600000000001',
        notes: 'Информация о применении — только по официальной инструкции.',
      ),
      Medicine(
        id: 'loratadine-demo',
        name: 'Лоратадин',
        activeIngredient: 'Лоратадин',
        form: 'Таблетки',
        dosage: '10 мг',
        quantity: 8,
        unit: 'таблеток',
        expiryDate: DateTime(today.year + 1, today.month, today.day),
        location: 'Верхняя полка',
        gtin: '04600000000002',
      ),
      Medicine(
        id: 'saline-demo',
        name: 'Натрия хлорид',
        activeIngredient: 'Натрия хлорид',
        form: 'Раствор',
        dosage: '0,9%',
        quantity: 2,
        unit: 'флакона',
        expiryDate: today.subtract(const Duration(days: 5)),
        location: 'Нижний ящик',
        gtin: '04600000000003',
      ),
    ];

    return AppState(
      medicines: medicines,
      reminders: const [
        MedicationReminder(
          id: 'reminder-loratadine',
          medicineId: 'loratadine-demo',
          hour: 9,
          minute: 0,
          dose: '1 таблетка',
          enabled: true,
        ),
      ],
      intakeRecords: const [],
    );
  }
}
