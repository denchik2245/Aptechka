import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:aptechka/features/inventory/presentation/drug_catalog_variants_screen.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    DrugCatalogService catalog = const DemoDrugCatalogService(),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [drugCatalogServiceProvider.overrideWithValue(catalog)],
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
    await tester.tap(find.text('Добавить упаковку'));
    await tester.pumpAndSettle();
    return container;
  }

  final input = find.byKey(const ValueKey('catalog-name-input'));

  testWidgets('typos suggest source name without automatic selection', (
    tester,
  ) async {
    await mount(tester);
    for (final query in [
      'ибупрафен',
      'ибупрофн',
      'ибуппрофен',
      'ибупорфен',
      'ибупрафн',
    ]) {
      await tester.enterText(input, query);
      await tester.pumpAndSettle();
      expect(find.text('Ибупрофен'), findsOneWidget, reason: query);
      expect(find.text('Похожее название'), findsWidgets);
      expect(find.text('Новая упаковка'), findsNothing);
      expect(tester.widget<TextField>(input).controller!.text, query);
    }
    await tester.tap(find.text('Ибупрофен'));
    await tester.pumpAndSettle();
    expect(find.text('Варианты препарата'), findsOneWidget);
    expect(find.text('200 мг'), findsOneWidget);
    expect(find.text('400 мг'), findsOneWidget);
    appRouter.pop();
    await tester.pumpAndSettle();
    await tester.enterText(input, 'ибупрофен');
    await tester.pumpAndSettle();
    expect(find.text('Похожее название'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dose search ignores partial GTIN; full barcode finds its variant',
    (tester) async {
      final group = DrugCatalogGroup(
        key: 'ибупрофен',
        entries: const [
          DrugCatalogEntry(
            id: '200',
            gtin: '04602884006732',
            name: 'Ибупрофен',
            activeIngredient: 'Ибупрофен',
            form: 'Таблетки',
            dosage: '200 мг',
            unit: 'таблеток',
          ),
          DrugCatalogEntry(
            id: '400',
            gtin: '04660153652998',
            name: 'Ибупрофен',
            activeIngredient: 'Ибупрофен',
            form: 'Таблетки',
            dosage: '400 мг',
            unit: 'таблеток',
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DrugCatalogVariantsScreen(
              groupKey: group.key,
              initialGroup: group,
            ),
          ),
        ),
      );
      final variantInput = find.byKey(const ValueKey('catalog-variant-input'));
      await tester.enterText(variantInput, '400 таблетки');
      await tester.pumpAndSettle();
      expect(find.text('200 мг'), findsNothing);
      expect(find.text('400 мг'), findsOneWidget);
      await tester.enterText(variantInput, '4602884006732');
      await tester.pumpAndSettle();
      expect(find.text('200 мг'), findsOneWidget);
      expect(find.text('400 мг'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows alphabetic catalog, filters from one letter, clears and keeps filter after back',
    (tester) async {
      await mount(tester);
      expect(find.text('Выберите препарат'), findsOneWidget);
      expect(find.text('Все препараты · 7'), findsOneWidget);
      expect(find.text('Ибупрофен'), findsOneWidget);
      await tester.enterText(input, 'н');
      await tester.pumpAndSettle();
      expect(find.text('Найдено препаратов · 5'), findsOneWidget);
      expect(find.text('Ибупрофен'), findsNothing);
      expect(find.text('Натрия хлорид'), findsOneWidget);
      // A match within a name is excluded: filtering is by the beginning.
      await tester.enterText(input, 'рофен');
      await tester.pumpAndSettle();
      expect(find.text('Найдено препаратов · 0'), findsOneWidget);
      await tester.enterText(input, 'НУРОФЕН ЭКСПРЕСС Ф');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Нурофен Экспресс Форте'));
      await tester.pumpAndSettle();
      expect(find.text('Варианты препарата'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey(
            'catalog-entry-demo-nurofen-express-forte-400-capsules',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Новая упаковка'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-name-input')),
            )
            .controller!
            .text,
        'Нурофен Экспресс Форте',
      );
      appRouter.pop();
      await tester.pumpAndSettle();
      expect(find.text('Варианты препарата'), findsOneWidget);
      appRouter.pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(input).controller!.text,
        'НУРОФЕН ЭКСПРЕСС Ф',
      );
      await tester.tap(find.byTooltip('Очистить поиск'));
      await tester.pumpAndSettle();
      expect(find.text('Все препараты · 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected variant fills form and saving returns to inventory without assigning a scanned GTIN',
    (tester) async {
      final container = await mount(tester);
      final before = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .length;
      await tester.enterText(input, 'Л');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Лоратадин'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('catalog-entry-demo-loratadine-10-tablets')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-name-input')),
            )
            .controller!
            .text,
        'Лоратадин',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('drug-ingredient-input')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-ingredient-input')),
            )
            .controller!
            .text,
        'Лоратадин',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('drug-dosage-input')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-dosage-input')),
            )
            .controller!
            .text,
        '10 мг',
      );
      await tester.scrollUntilVisible(
        find.text('Добавить упаковку'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Добавить упаковку').last);
      await tester.pumpAndSettle();
      expect(find.text('Содержимое аптечки'), findsOneWidget);
      final medicines = container
          .read(appControllerProvider)
          .requireValue
          .medicines;
      expect(medicines, hasLength(before + 1));
      final added = medicines.last;
      expect(added.catalogEntryId, 'demo-loratadine-10-tablets');
      expect(added.gtin, isNull);
      expect(added.expiryDate, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one name card contains all doses; variant filter and selected dose survive back',
    (tester) async {
      await mount(tester);
      await tester.enterText(input, 'ибупрофен');
      await tester.pumpAndSettle();
      expect(find.text('Найдено препаратов · 1'), findsOneWidget);
      expect(find.text('Ибупрофен'), findsOneWidget);
      expect(find.text('2 варианта'), findsOneWidget);
      await tester.tap(find.text('Ибупрофен'));
      await tester.pumpAndSettle();
      expect(find.text('2 варианта из 2'), findsOneWidget);
      expect(find.text('200 мг'), findsOneWidget);
      expect(find.text('400 мг'), findsOneWidget);
      final variantInput = find.byKey(const ValueKey('catalog-variant-input'));
      await tester.enterText(variantInput, '400');
      await tester.pumpAndSettle();
      expect(find.text('1 вариант из 2'), findsOneWidget);
      expect(find.text('200 мг'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('catalog-entry-demo-ibuprofen-400-tablets')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('drug-dosage-input')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-dosage-input')),
            )
            .controller!
            .text,
        '400 мг',
      );
      appRouter.pop();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(variantInput).controller!.text, '400');
      await tester.tap(find.byTooltip('Очистить поиск вариантов'));
      await tester.pumpAndSettle();
      expect(find.text('2 варианта из 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed catalog can retry and manual form remains available', (
    tester,
  ) async {
    var calls = 0;
    final catalog = MdlpDrugCatalogService(
      loadAsset: () async {
        calls++;
        throw StateError('offline');
      },
    );
    await mount(tester, catalog: catalog);
    expect(find.text('Справочник недоступен'), findsOneWidget);
    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.tap(find.text('Нет в списке? Заполнить вручную'));
    await tester.pumpAndSettle();
    expect(find.text('Новая упаковка'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('drug-name-input')))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
