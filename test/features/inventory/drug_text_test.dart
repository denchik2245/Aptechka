import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all-capital source text reads normally with abbreviations intact', () {
    expect(readableDrugName('МЕНАКТРА'), 'Менактра');
    expect(readableDrugName('МЕТОТРЕКСАТ-ПРОМОМЕД'), 'Метотрексат-Промомед');
    expect(readableDrugName('ЦИТРАМОН П'), 'Цитрамон П');
    expect(readableDrugName('БЦЖ-М'), 'БЦЖ-М');
    expect(readableDrugName('АЦЦ ЛОНГ'), 'АЦЦ лонг');
    expect(
      readableDrugText('ТАБЛЕТКИ, ПОКРЫТЫЕ ОБОЛОЧКОЙ'),
      'Таблетки, покрытые оболочкой',
    );
    expect(
      readableDrugText('ФАКТОР СВЕРТЫВАНИЯ КРОВИ VIII'),
      'Фактор свертывания крови VIII',
    );
    expect(
      readableDrugText('2 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 15 шт'),
      '2 x упаковка ячейковая контурная по 15 шт',
    );
    expect(readableManufacturer('АО ВЕРТЕКС'), 'АО Вертекс');
    expect(readableManufacturer('ООО «ОЗОН»'), 'ООО «Озон»');
    expect(readableDrugText('500 МЕ+10 мг/мл'), '500 МЕ+10 мг/мл');
    expect(readableDrugText('МНН / РУ / GTIN'), 'МНН / РУ / GTIN');
  });

  test('mixed-case spelling, identifiers and original catalog records survive display', () {
    for (final text in [
      'аАКДС-Геп B+Hib',
      'Haemophilus influenzae',
      'Нурофен Экспресс Форте',
      '04607027768027',
    ]) {
      expect(readableDrugText(text), text);
    }
    const entry = DrugCatalogEntry(
      id: 'raw',
      gtin: '04600000000001',
      name: 'ПРЕПАРАТ',
      activeIngredient: 'ФЛУОЦИНОЛОНА АЦЕТОНИД',
      form: 'ТАБЛЕТКИ',
      dosage: '500 МЕ',
      unit: 'таблеток',
      manufacturer: 'АО ВЕРТЕКС',
      packageDescription: 'ТУБА по 30.000 г',
      registrationId: 'ЛП-002969',
    );
    expect(entry.displayName, 'Препарат');
    expect(entry.displayIngredient, 'Флуоцинолона ацетонид');
    expect(entry.displayForm, 'Таблетки');
    expect(entry.displayManufacturer, 'АО Вертекс');
    expect(entry.displayPackage, 'Туба по 30.000 г');
    expect(entry.name, 'ПРЕПАРАТ');
    expect(entry.form, 'ТАБЛЕТКИ');
    expect(entry.dosage, '500 МЕ');
    expect(entry.registrationId, 'ЛП-002969');
    expect(entry.gtin, '04600000000001');
  });
}
