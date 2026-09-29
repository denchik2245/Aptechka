import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old local records migrate into the home pharmacy', () {
    final state = AppState.fromJson({
      'medicines': [
        {
          'id': 'old-package',
          'name': 'Ибупрофен',
          'form': 'Таблетки',
          'dosage': '200 мг',
          'quantity': 10,
          'unit': 'таблеток',
          'expiryDate': '2027-01-01T00:00:00.000',
          'location': 'Шкаф',
        },
      ],
      'reminders': [],
      'intakeRecords': [],
    });

    expect(state.selectedPharmacyId, 'home');
    expect(state.pharmacies.single.name, 'Дом');
    expect(state.medicinesIn('home').single.id, 'old-package');
  });
}
