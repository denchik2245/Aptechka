import 'dart:async';

import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:aptechka/features/inventory/presentation/drug_catalog_variants_screen.dart';
import 'package:aptechka/features/inventory/presentation/drug_name_field.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _entries = [
  DrugCatalogEntry(
    id: 'a',
    gtin: '04603988017259',
    name: 'Лоперамид',
    activeIngredient: 'Лоперамид',
    form: 'Капсулы',
    dosage: '2 мг',
    unit: 'капсул',
    manufacturer: 'АО Обновление',
    packageDescription: '2 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт',
    registrationId: 'ЛП-005975',
    registrationStatus: 'Действующий',
  ),
  DrugCatalogEntry(
    id: 'b',
    gtin: '04603988017242',
    name: 'Лоперамид',
    activeIngredient: 'Лоперамид',
    form: 'Капсулы',
    dosage: '2 мг',
    unit: 'капсул',
    manufacturer: 'АО Обновление',
    packageDescription: '2 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт',
    registrationId: 'ЛП-005975',
    registrationStatus: 'Действующий',
  ),
  DrugCatalogEntry(
    id: 'c',
    gtin: '04605949000195',
    name: 'Лоперамид',
    activeIngredient: 'Лоперамид',
    form: 'Таблетки',
    dosage: '2 мг',
    unit: 'таблеток',
    manufacturer: 'ЗАО Биоком',
    packageDescription: 'УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт',
    registrationId: 'ЛС-001166',
    registrationStatus: 'Недействующий',
  ),
];

class _Catalog implements DrugCatalogService {
  _Catalog({this.resolver});
  final Future<DrugCatalogEntry?> Function(String)? resolver;
  @override
  String get sourceLabel => 'Тестовый справочник';
  @override
  Future<List<DrugCatalogEntry>> listAll() async => _entries;
  @override
  Future<DrugCatalogEntry?> findByGtin(String gtin) async {
    if (resolver != null) return resolver!(gtin);
    for (final entry in _entries) {
      if (entry.gtin == gtin) return entry;
    }
    return null;
  }

  @override
  Future<List<DrugCatalogEntry>> search(String query, {int limit = 6}) async =>
      _entries.take(limit).toList();
}

void main() {
  final group = DrugCatalogGroup(key: 'лоперамид', entries: _entries);

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    DrugCatalogService? catalog,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        drugCatalogServiceProvider.overrideWithValue(catalog ?? _Catalog()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .updateSettings(
          const AppSettings(appearance: AppAppearance.dark, textScale: 1.3),
        );
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go('/inventory');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.push('/medicine/variants?name=лоперамид', extra: group);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final location = find.byKey(const ValueKey('package-location-input'));
    await reveal(tester, location);
    await tester.enterText(location, 'Шкаф');
    await reveal(tester, find.text('Добавить упаковку').last);
    await tester.tap(find.text('Добавить упаковку').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'groups identical rows, hides technical codes, exposes all codes in details',
    (tester) async {
      await mount(tester);
      expect(find.text('Лоперамид · 2 мг'), findsOneWidget);
      expect(find.text('Дозировка'), findsNothing);
      expect(find.textContaining('GTIN:'), findsNothing);
      expect(find.textContaining('РУ:'), findsNothing);
      expect(find.text('2 варианта упаковки'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('catalog-details-a')));
      expect(find.byKey(const ValueKey('catalog-entry-b')), findsNothing);
      expect(find.text('АО Обновление · 20 капсул'), findsOneWidget);
      expect(find.text('2 блистера по 10'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('catalog-details-a')));
      await tester.pumpAndSettle();
      expect(find.text('РУ: ЛП-005975'), findsOneWidget);
      expect(find.text('GTIN: 04603988017259'), findsOneWidget);
      expect(find.text('GTIN: 04603988017242'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GTIN:'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'form and manufacturer filters reset incompatible choices and search total count',
    (tester) async {
      await mount(tester);
      await reveal(
        tester,
        find.byKey(const ValueKey('variant-manufacturer-filter')),
      );
      await tester.tap(
        find.byKey(const ValueKey('variant-manufacturer-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('АО Обновление').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('variant-filter-Форма-Таблетки')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('variant-filter-Форма-Таблетки')),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('catalog-entry-c')));
      expect(find.text('Запись в справочнике недействующая'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalog-entry-a')), findsNothing);
      await tester.ensureVisible(find.text('Сбросить фильтры'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сбросить фильтры'));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('catalog-variant-input'));
      await tester.enterText(input, '20 капсул');
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('catalog-entry-a')));
      expect(find.byKey(const ValueKey('catalog-entry-c')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'group selection fills full package quantity without inventing record identity',
    (tester) async {
      final container = await mount(tester);
      await reveal(tester, find.byKey(const ValueKey('catalog-entry-a')));
      await tester.tap(find.byKey(const ValueKey('catalog-entry-a')));
      await tester.pumpAndSettle();
      await save(tester);
      final added = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(added.gtin, isNull);
      expect(added.catalogEntryId, isNull);
      expect(added.manufacturer, 'АО Обновление');
      expect(added.packageDescription, _entries.first.packageDescription);
      expect(added.registrationId, 'ЛП-005975');
      expect(added.quantity, 20);
      expect(added.expiryDate, isNull);
      expect(find.byTooltip('Добавить упаковку'), findsOneWidget);
      expect(find.text('Дом'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'group selection restores from URL without choosing the first GTIN',
    (tester) async {
      final container = await mount(tester);
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new?candidates=04603988017259,04603988017242');
      await tester.pumpAndSettle();
      await save(tester);
      final added = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(added.name, 'Лоперамид');
      expect(added.catalogEntryId, isNull);
      expect(added.gtin, isNull);
      expect(added.quantity, 20);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scanner result assigns exact identity and GTIN, including a grouped member',
    (tester) async {
      final container = await mount(tester);
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new?scanned=04603988017242');
      await tester.pumpAndSettle();
      expect(find.text('Код упаковки считан'), findsOneWidget);
      await save(tester);
      final added = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(added.catalogEntryId, 'b');
      expect(added.gtin, '04603988017242');
      expect(added.quantity, 20);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late scan lookup cannot replace manual name or scanned identity',
    (tester) async {
      final response = Completer<DrugCatalogEntry?>();
      await mount(tester, catalog: _Catalog(resolver: (_) => response.future));
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new?scanned=04603988017242');
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('drug-name-input')));
      await tester.enterText(
        find.byKey(const ValueKey('drug-name-input')),
        'Другой',
      );
      response.complete(_entries[1]);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-name-input')),
            )
            .controller!
            .text,
        'Другой',
      );
      expect(find.text('Код упаковки считан'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manual escape retains only the name', (tester) async {
    await mount(tester);
    await reveal(tester, find.text('Заполнить вручную'));
    await tester.tap(find.text('Заполнить вручную'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('drug-name-input')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('drug-name-input')))
          .controller!
          .text,
      'Лоперамид',
    );
    await reveal(tester, find.byKey(const ValueKey('drug-dosage-input')));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('drug-dosage-input')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  for (final edited in [false, true]) {
    testWidgets(
      'inline selection updates automatic quantity and preserves manual input: $edited',
      (tester) async {
        final container = await mount(tester);
        appRouter.pop();
        await tester.pumpAndSettle();
        appRouter.push('/medicine/new', extra: _entries.first);
        await tester.pumpAndSettle();
        final quantity = find.byKey(const ValueKey('package-quantity-input'));
        await reveal(tester, quantity);
        expect(tester.widget<TextFormField>(quantity).controller!.text, '20');
        if (edited) {
          await tester.enterText(quantity, '7');
          await tester.pumpAndSettle();
        }
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final name = find.byKey(const ValueKey('drug-name-input'));
        await reveal(tester, name);
        await tester.enterText(name, 'Лоперами');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        final choice = find
            .descendant(
              of: find.byType(DrugNameField),
              matching: find.byType(ListTile),
            )
            .last;
        await reveal(tester, choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        await reveal(tester, quantity);
        expect(
          tester.widget<TextFormField>(quantity).controller!.text,
          edited ? '7' : '10',
        );
        await save(tester);
        final added = container
            .read(appControllerProvider)
            .requireValue
            .medicines
            .last;
        expect(added.quantity, edited ? 7 : 10);
        expect(added.unit, 'таблеток');
        expect(added.catalogEntryId, 'c');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'late catalog load keeps quantity explicitly edited before it resolves',
    (tester) async {
      final response = Completer<DrugCatalogEntry?>();
      final container = await mount(
        tester,
        catalog: _Catalog(resolver: (_) => response.future),
      );
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new?scanned=04603988017242');
      await tester.pumpAndSettle();
      final quantity = find.byKey(const ValueKey('package-quantity-input'));
      await reveal(tester, quantity);
      await tester.enterText(quantity, '');
      await tester.enterText(quantity, '1');
      response.complete(_entries[1]);
      await tester.pumpAndSettle();
      await reveal(tester, quantity);
      expect(tester.widget<TextFormField>(quantity).controller!.text, '1');
      await save(tester);
      expect(
        container
            .read(appControllerProvider)
            .requireValue
            .medicines
            .last
            .quantity,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown package count and mismatched units are not filled from dosage or volume',
    (tester) async {
      await mount(tester);
      appRouter.pop();
      await tester.pumpAndSettle();
      for (final entry in [
        const DrugCatalogEntry(
          id: 'unknown',
          name: 'Препарат',
          activeIngredient: '',
          form: 'Таблетки',
          dosage: '500 мг',
          unit: 'таблеток',
          packageDescription: 'ФЛАКОН по 10.000 мл',
        ),
        const DrugCatalogEntry(
          id: 'unit',
          name: 'Препарат',
          activeIngredient: '',
          form: 'Капсулы',
          dosage: '2 мг',
          unit: 'мл',
          packageDescription: '2 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт',
        ),
      ]) {
        appRouter.push('/medicine/new', extra: entry);
        await tester.pumpAndSettle();
        final quantity = find.byKey(const ValueKey('package-quantity-input'));
        await reveal(tester, quantity);
        expect(tester.widget<TextFormField>(quantity).controller!.text, '1');
        appRouter.pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing the name clears automatic package count', (
    tester,
  ) async {
    await mount(tester);
    appRouter.pop();
    await tester.pumpAndSettle();
    appRouter.push('/medicine/new', extra: _entries.first);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('drug-name-input')));
    await tester.enterText(
      find.byKey(const ValueKey('drug-name-input')),
      'Другой препарат',
    );
    await tester.pumpAndSettle();
    final quantity = find.byKey(const ValueKey('package-quantity-input'));
    await reveal(tester, quantity);
    expect(tester.widget<TextFormField>(quantity).controller!.text, '1');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scan action opens scanner and passes returned code as scanned data',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => DrugCatalogVariantsScreen(
              groupKey: group.key,
              initialGroup: group,
            ),
          ),
          GoRoute(
            path: '/scanner',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop('04603988017242'),
                child: const Text('Считать код'),
              ),
            ),
          ),
          GoRoute(
            path: '/medicine/new',
            builder: (_, state) => Scaffold(
              body: Text('Считан: ${state.uri.queryParameters['scanned']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сканировать код упаковки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Считать код'));
      await tester.pumpAndSettle();
      expect(find.text('Считан: 04603988017242'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
