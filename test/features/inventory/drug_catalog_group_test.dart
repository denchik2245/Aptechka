import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DrugCatalogEntry entry(
    String id,
    String name, {
    String dosage = '200 мг',
    String form = 'Таблетки',
    String manufacturer = 'Завод',
    String package = '10 шт',
    String status = 'Действующий',
  }) => DrugCatalogEntry(
    id: id,
    gtin: id,
    name: name,
    dosage: dosage,
    form: form,
    manufacturer: manufacturer,
    packageDescription: package,
    registrationStatus: status,
    activeIngredient: 'Вещество',
    unit: 'шт.',
  );

  test('same name groups all forms, doses, packs, producers and statuses without merging distinct qualifiers', () {
    final entries = [
      entry('1', 'Препарат'),
      entry(
        '2',
        ' ПРЕПАРАТ ',
        dosage: '400 мг',
        form: 'Капсулы',
        manufacturer: 'Другой завод',
        package: '20 шт',
        status: 'Недействующий',
      ),
      entry('3', 'Препарат Форте'),
      entry('4', 'Препарат+'),
      entry('5', 'Препарат-А'),
      entry('6', 'Препарат А'),
    ];
    final groups = groupDrugCatalogEntries(entries);
    expect(groups, hasLength(5));
    expect(groups.first.entries.map((entry) => entry.id), ['1', '2']);
    expect(groups.first.forms, ['Таблетки', 'Капсулы']);
    expect(groups.first.entries.last.isInactive, isTrue);
    expect(groups.expand((group) => group.entries).toSet(), entries.toSet());
  });

  test(
    'complete MDLP snapshot groups trade names while preserving every GTIN',
    () async {
      final entries = await MdlpDrugCatalogService().listAll();
      final groups = groupDrugCatalogEntries(entries);
      expect(groups, hasLength(10292));
      expect(groups.expand((group) => group.entries), hasLength(74791));
      expect(
        groups
            .expand((group) => group.entries)
            .map((entry) => entry.gtin)
            .toSet(),
        hasLength(74791),
      );
      final ibuprofen = groups.singleWhere((group) => group.key == 'ибупрофен');
      expect(ibuprofen.entries.length, greaterThan(1));
      expect(
        ibuprofen.entries.map((entry) => entry.dosage).toSet().length,
        greaterThan(1),
      );
      expect(
        ibuprofen.entries
            .map((entry) => entry.packageDescription)
            .toSet()
            .length,
        greaterThan(1),
      );
      expect(
        ibuprofen.entries.map((entry) => entry.manufacturer).toSet().length,
        greaterThan(1),
      );
    },
  );
}
