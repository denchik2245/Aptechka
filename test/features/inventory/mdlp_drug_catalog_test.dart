import 'dart:convert';

import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

String fixture({bool duplicate = false}) {
  final values = [
    '04601669000675',
    'Цитрамон П',
    'МНН',
    'ТАБЛЕТКИ',
    '',
    'таблеток',
    'Производитель',
    'Блистер',
    'РУ',
    'Действующий',
  ];
  return jsonEncode({
    'schemaVersion': 1,
    'fields': [
      'gtin',
      'name',
      'activeIngredient',
      'form',
      'dosage',
      'unit',
      'manufacturer',
      'packageDescription',
      'registrationId',
      'registrationStatus',
    ],
    'metadata': {'recordCount': duplicate ? 2 : 1, 'validDate': '2026-10-01'},
    'strings': values,
    'entries': [
      List.generate(10, (i) => i),
      if (duplicate) List.generate(10, (i) => i),
    ],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fullCatalog = MdlpDrugCatalogService();

  test(
    'full catalog finds misspelled names and keeps exact matches first',
    () async {
      for (final query in ['ибупрафен', 'ибупрофн', 'ибупорфен', 'ибупрафн']) {
        final matches = await fullCatalog.search(query);
        expect(matches, isNotEmpty, reason: query);
        expect(matches.first.name, 'Ибупрофен', reason: query);
      }
      final exact = await fullCatalog.search('ибупрофен', limit: 12);
      expect(exact.every((entry) => entry.name == 'Ибупрофен'), isTrue);
    },
  );

  test(
    'alphabetical list retains the complete snapshot and every GTIN',
    () async {
      final entries = await fullCatalog.listAll();
      expect(entries, hasLength(74791));
      expect(entries.map((entry) => entry.gtin).toSet(), hasLength(74791));
      expect(entries.where((entry) => entry.isInactive), hasLength(6349));
      for (var i = 1; i < entries.length; i++) {
        expect(
          drugNameSortKey(entries[i - 1].name)
              .compareTo(drugNameSortKey(entries[i].name)),
          lessThanOrEqualTo(0),
        );
      }
      expect(identical(entries, await fullCatalog.listAll()), isTrue);
    },
  );

  test('bundled full snapshot searches real trade names and manufacturer/package terms', () async {
    final clock = Stopwatch()..start();
    final results = await fullCatalog.search('цитрамон п', limit: 12);
    expect(results, hasLength(12));
    expect(
      results.every(
        (item) => normalizeDrugQuery(item.name).contains('цитрамон п'),
      ),
      isTrue,
    );
    expect(results.every((item) => !item.isInactive), isTrue);
    expect(results.every((item) => item.manufacturer.isNotEmpty), isTrue);
    expect(fullCatalog.sourceLabel, contains('74791'));
    expect(fullCatalog.sourceLabel, contains('01.10.2026'));
    final refined = await fullCatalog.search('парацетамол таблетки озон');
    expect(refined, isNotEmpty);
    expect(
      refined.every(
        (item) => normalizeDrugQuery(item.manufacturer).contains('озон'),
      ),
      isTrue,
    );
    expect(refined.every((item) => item.sourceVersion == '2026-10-01'), isTrue);
    // Small queries return quickly without loading the asset.
    expect(await fullCatalog.search('а'), isEmpty);
    expect(await fullCatalog.search('нет-такого-препарата-xyz'), isEmpty);
    // Evidence for the actual complete snapshot, not a stub service.
    debugPrint('Full MDLP load + search: ${clock.elapsedMilliseconds} ms');
  });

  test('GTIN uses exact raw label dose, retains inactive status, and missing dose stays unknown', () async {
    final citramon = await fullCatalog.findByGtin('04601669000675');
    expect(citramon?.dosage, '240 мг+27.3 мг+180 мг');
    expect(citramon?.form, 'ТАБЛЕТКИ');
    final inactive = await fullCatalog.findByGtin('00000046225474');
    expect(inactive?.isInactive, isTrue);
    expect(inactive?.registrationStatus, 'Недействующий');
    final missing = await fullCatalog.findByGtin('03352712000197');
    expect(missing?.dosage, isEmpty);
    expect(missing?.dosageLabel, 'Дозировка не указана');
    expect(await fullCatalog.findByGtin('04600000000001'), isNull);
  });

  test('asset load is shared and failures are retryable; invalid snapshot is not silently replaced by demo', () async {
    var calls = 0;
    final service = MdlpDrugCatalogService(
      loadAsset: () async {
        if (++calls == 1) throw StateError('offline');
        return fixture();
      },
    );
    await expectLater(service.search('цитрамон'), throwsStateError);
    final results = await Future.wait([
      service.search('цитрамон'),
      service.findByGtin('04601669000675'),
    ]);
    expect(results.first, isNotNull);
    expect(calls, 2);
    final damaged = MdlpDrugCatalogService(
      loadAsset: () async => fixture(duplicate: true),
    );
    await expectLater(damaged.search('цитрамон'), throwsFormatException);
  });
}
