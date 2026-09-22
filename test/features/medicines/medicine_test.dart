import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Medicine medicineExpiringOn(DateTime expiry) => Medicine(
    id: 'test',
    name: 'Тест',
    form: 'Таблетки',
    dosage: '10 мг',
    quantity: 1,
    unit: 'таблетка',
    expiryDate: expiry,
    location: 'Шкаф',
  );

  test('expired when expiry date is before today', () {
    final now = DateTime(2026, 9, 17, 18);
    expect(
      medicineExpiringOn(DateTime(2026, 9, 16)).statusAt(now),
      MedicineStatus.expired,
    );
  });

  test('expiring soon within 30 days', () {
    final now = DateTime(2026, 9, 17);
    expect(
      medicineExpiringOn(DateTime(2026, 10, 17)).statusAt(now),
      MedicineStatus.expiringSoon,
    );
  });

  test('okay when expiry is more than 30 days away', () {
    final now = DateTime(2026, 9, 17);
    expect(
      medicineExpiringOn(DateTime(2026, 10, 18)).statusAt(now),
      MedicineStatus.okay,
    );
  });
}
