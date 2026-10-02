import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = DemoDrugCatalogService();

  test(
    'partial search ranks names before ingredients and keeps distinct variants',
    () async {
      final matches = await catalog.search('  ИБУП  ');
      expect(
        matches.take(2).map((item) => item.name),
        everyElement('Ибупрофен'),
      );
      expect(matches.take(2).map((item) => item.dosage), ['200 мг', '400 мг']);
      expect(matches.map((item) => item.id).toSet(), hasLength(matches.length));
      expect(matches.any((item) => item.name == 'Нурофен'), isTrue);
      expect((await catalog.search('нуро', limit: 2)), hasLength(2));
    },
  );

  test(
    'multiple terms, whitespace and ё normalization refine results',
    () async {
      final capsules = await catalog.search('  НУРОФЁН   капсулы 400 ');
      expect(capsules, hasLength(1));
      expect(capsules.single.name, 'Нурофен Экспресс Форте');
      expect((await catalog.search('хлорид 0.9')).single.dosage, '0,9%');
      expect(await catalog.search('и'), isEmpty);
      expect(await catalog.search('несуществующее название'), isEmpty);
      expect(await catalog.search('ибупрофен', limit: 0), isEmpty);
    },
  );

  test(
    'scanner demo codes still resolve independently of name search',
    () async {
      expect((await catalog.findByGtin('04600000000001'))?.dosage, '200 мг');
      expect((await catalog.findByGtin('04600000000002'))?.name, 'Лоратадин');
      expect(await catalog.findByGtin('unknown'), isNull);
      final tradeName = await catalog.search('Нурофен Экспресс');
      expect(tradeName.every((item) => item.gtin == null), isTrue);
    },
  );
}
