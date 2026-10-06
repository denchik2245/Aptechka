import 'dart:async';

import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/presentation/drug_name_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ControlledCatalog implements DrugCatalogService {
  final requests = <String, Completer<List<DrugCatalogEntry>>>{};
  @override
  String get sourceLabel => 'Тестовый справочник';
  @override
  Future<List<DrugCatalogEntry>> listAll() async => const [];
  @override
  Future<DrugCatalogEntry?> findByGtin(String gtin) async => null;
  @override
  Future<List<DrugCatalogEntry>> search(String query, {int limit = 6}) {
    final request = Completer<List<DrugCatalogEntry>>();
    requests[query] = request;
    return request.future;
  }
}

const first = DrugCatalogEntry(
  id: 'first',
  name: 'Первый препарат',
  activeIngredient: 'Первое вещество',
  form: 'Таблетки',
  dosage: '200 мг',
  unit: 'таблеток',
);
const second = DrugCatalogEntry(
  id: 'second',
  name: 'Второй препарат',
  activeIngredient: 'Второе вещество',
  form: 'Капсулы',
  dosage: '400 мг',
  unit: 'капсул',
);

void main() {
  Future<TextEditingController> mount(
    WidgetTester tester,
    ControlledCatalog catalog,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [drugCatalogServiceProvider.overrideWithValue(catalog)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DrugNameField(
                controller: controller,
                validator: (_) => null,
                onChanged: (_) {},
                onSelected: (entry) => controller.text = entry.name,
              ),
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets(
    'debounce avoids short queries; late replies cannot replace newer results',
    (tester) async {
      final catalog = ControlledCatalog();
      await mount(tester, catalog);
      await tester.enterText(find.byType(TextFormField), 'и');
      await tester.pump(const Duration(milliseconds: 300));
      expect(catalog.requests, isEmpty);
      await tester.enterText(find.byType(TextFormField), 'иб');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextFormField), 'ибу');
      await tester.pump(const Duration(milliseconds: 250));
      expect(catalog.requests.keys, ['ибу']);
      await tester.enterText(find.byType(TextFormField), 'лора');
      await tester.pump(const Duration(milliseconds: 250));
      catalog.requests['лора']!.complete([second]);
      await tester.pumpAndSettle();
      expect(find.text(second.name), findsOneWidget);
      catalog.requests['ибу']!.complete([first]);
      await tester.pumpAndSettle();
      expect(find.text(first.name), findsNothing);
      expect(find.text(second.name), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
    },
  );

  testWidgets(
    'error allows retry and manual input; dismiss ignores pending reply',
    (tester) async {
      final catalog = ControlledCatalog();
      final controller = await mount(tester, catalog);
      await tester.enterText(find.byType(TextFormField), 'ошибка');
      await tester.pump(const Duration(milliseconds: 250));
      catalog.requests['ошибка']!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Не удалось выполнить поиск'), findsOneWidget);
      await tester.tap(find.text('Повторить поиск'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Заполнить вручную'));
      catalog.requests['ошибка']!.complete([first]);
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(controller.text, 'ошибка');
      await tester.enterText(find.byType(TextFormField), 'нет вариантов');
      await tester.pump(const Duration(milliseconds: 250));
      catalog.requests['нет вариантов']!.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Совпадений не найдено'), findsOneWidget);
      expect(controller.text, 'нет вариантов');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending lookup can finish after the field is disposed', (
    tester,
  ) async {
    final catalog = ControlledCatalog();
    await mount(tester, catalog);
    await tester.enterText(find.byType(TextFormField), 'ибуп');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox());
    catalog.requests['ибуп']!.complete([first]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
