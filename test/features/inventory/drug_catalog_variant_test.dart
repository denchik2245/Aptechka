import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:flutter_test/flutter_test.dart';

DrugCatalogEntry record({
  String id = 'a',
  String? gtin,
  String form = 'КАПСУЛЫ',
  String dosage = '2 мг',
  String manufacturer = 'АО ОБНОВЛЕНИЕ',
  String package = '2 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт',
  String registration = 'ЛП-005975',
  String status = 'Действующий',
  String ingredient = 'Лоперамид',
  String version = '2026-10-01',
}) => DrugCatalogEntry(
  id: id,
  gtin: gtin,
  name: 'Лоперамид',
  activeIngredient: ingredient,
  form: form,
  dosage: dosage,
  unit: 'капсул',
  manufacturer: manufacturer,
  packageDescription: package,
  registrationId: registration,
  registrationStatus: status,
  sourceVersion: version,
);

void main() {
  test('only GTIN and record ID can differ in one display group', () {
    final entries = [
      record(id: 'a', gtin: '04600000000001'),
      record(id: 'b', gtin: '04600000000002'),
      record(id: 'dose', dosage: '4 мг'),
      record(id: 'form', form: 'ТАБЛЕТКИ'),
      record(id: 'manufacturer', manufacturer: 'АО БИОКОМ'),
      record(id: 'pack', package: 'УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт'),
      record(id: 'ru', registration: 'ЛП-123456'),
      record(id: 'inactive', status: 'Недействующий'),
      record(id: 'ingredient', ingredient: 'Другое вещество'),
      record(id: 'version', version: '2025-01-01'),
    ];
    final variants = groupDrugCatalogVariants(entries);
    expect(variants, hasLength(entries.length - 1));
    expect(
      variants.singleWhere((v) => v.isAmbiguous).entries.map((e) => e.id),
      ['a', 'b'],
    );
    expect(variants.expand((v) => v.entries), hasLength(entries.length));
  });

  test('blister count uses total units and Russian plural forms', () {
    for (final count in [1, 2, 5]) {
      final package = describeDrugPackage(
        record(package: '$count × УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт'),
      );
      expect(package.quantity, count * 10);
      expect(package.title, '${count * 10} капсул');
      expect(package.detail, switch (count) {
        1 => '1 блистер по 10',
        2 => '2 блистера по 10',
        _ => '5 блистеров по 10',
      });
    }
    expect(describeDrugPackage(record(form: 'ТАБЛЕТКИ')).title, '20 таблеток');
    expect(
      describeDrugPackage(
        record(package: 'УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 1 шт'),
      ).title,
      '1 капсула',
    );
  });

  test('ambiguous packs and liquids keep source text', () {
    for (final entry in [
      record(package: 'ФЛАКОН 10 мл'),
      record(
        package: '2 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт + растворитель',
      ),
      record(form: 'Раствор', package: 'УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт'),
      record(package: '0 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт'),
    ]) {
      final package = describeDrugPackage(entry);
      expect(package.quantity, isNull);
      expect(package.title, entry.displayPackage);
    }
    expect(
      describeDrugPackage(record(package: '')).title,
      'Упаковка не указана',
    );
  });
  test('counts coated tablets, modified capsules and explicit container quantities', () {
    final coated = describeDrugPackage(
      record(form: 'ТАБЛЕТКИ, ПОКРЫТЫЕ ОБОЛОЧКОЙ', package: 'БАНКА по 30 шт'),
    );
    expect(coated.quantity, 30);
    expect(coated.quantityUnit, 'таблеток');
    expect(coated.title, '30 таблеток');
    expect(coated.detail, '1 банка по 30');
    expect(
      describeDrugPackage(
        record(form: 'Капсулы с модифицированным высвобождением'),
      ).quantity,
      20,
    );
    expect(
      describeDrugPackage(record(package: '3 x УПАКОВКА по 10 шт')).quantity,
      30,
    );
    expect(
      describeDrugPackage(record(package: 'ФЛАКОН по 10.000 мл')).quantity,
      isNull,
    );
    expect(
      describeDrugPackage(record(package: 'УПАКОВКА по 2.5 шт')).quantity,
      isNull,
    );
  });
}
