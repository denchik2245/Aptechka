import 'dart:convert';

import 'package:aptechka/features/inventory/data/drug_photo_catalog.dart';
import 'package:aptechka/features/inventory/presentation/widgets/drug_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const gtin = '04601669000675';
final asset = 'assets/drug_photos/${'a' * 64}.png';

String fixture({bool duplicate = false, String? path, String usage = 'demo'}) =>
    jsonEncode({
      'schemaVersion': 1,
      'source': 'РЛС Аврора',
      'usage': usage,
      'rightsReference': usage == 'licensed' ? 'Test agreement' : '',
      'entries': [
        {'gtin': gtin, 'asset': path ?? asset},
        if (duplicate) {'gtin': gtin, 'asset': asset},
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'photo catalog is shared and matches only the exact package GTIN',
    () async {
      var loads = 0;
      final catalog = DrugPhotoCatalog(
        loadAsset: () async {
          loads++;
          return fixture();
        },
      );
      expect(await catalog.find(null), isNull);
      expect(await catalog.find('Цитрамон'), isNull);
      final photos = await Future.wait([
        catalog.find(gtin),
        catalog.find(gtin),
      ]);
      expect(photos.first?.asset, asset);
      expect(photos.first?.isDemo, isTrue);
      expect(await catalog.find('03352712000197'), isNull);
      expect(loads, 1);
    },
  );

  test('damaged or external photo references are rejected and loading is retryable', () async {
    var calls = 0;
    final catalog = DrugPhotoCatalog(
      loadAsset: () async {
        if (++calls == 1) throw StateError('asset unavailable');
        return fixture(usage: 'licensed');
      },
    );
    await expectLater(catalog.find(gtin), throwsStateError);
    expect((await catalog.find(gtin))?.isDemo, isFalse);
    for (final source in [
      fixture(duplicate: true),
      fixture(path: 'https://example.test/image.png'),
    ]) {
      await expectLater(
        DrugPhotoCatalog(loadAsset: () async => source).find(gtin),
        throwsFormatException,
      );
    }
  });

  test('bundled manifest honestly contains no photos until supplier access is granted', () async {
    expect(await DrugPhotoCatalog().find(gtin), isNull);
  });

  testWidgets(
    'missing photo does not occupy the form and switching package removes old photo',
    (tester) async {
      final catalog = DrugPhotoCatalog(loadAsset: () async => fixture());
      Widget app(String? barcode) => ProviderScope(
        overrides: [drugPhotoCatalogProvider.overrideWithValue(catalog)],
        child: MaterialApp(
          home: Scaffold(body: DrugPhotoPanel(gtin: barcode)),
        ),
      );
      await tester.pumpWidget(app(gtin));
      await tester.pumpAndSettle();
      expect(find.text('РЛС Аврора · тестовый доступ'), findsOneWidget);
      // The test has no supplier image asset; decode/load errors have a visible fallback.
      expect(find.text('Фотография недоступна'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app('03352712000197'));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
