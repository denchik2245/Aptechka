import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
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
    appRouter.push('/medicine/new');
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> reveal(
    WidgetTester tester,
    String key, {
    double delta = 200,
  }) async {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(key)),
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await reveal(tester, 'drug-name-input', delta: -200);
    await tester.enterText(
      find.byKey(const ValueKey('drug-name-input')),
      query,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'readable prefill saves original catalog identity and displays saved text normally',
    (tester) async {
      final container = await mount(tester);
      const entry = DrugCatalogEntry(
        id: 'uppercase',
        name: 'ПРЕПАРАТ',
        activeIngredient: 'ФЛУОЦИНОЛОНА АЦЕТОНИД',
        form: 'ТАБЛЕТКИ, ПОКРЫТЫЕ ОБОЛОЧКОЙ',
        dosage: '500 МЕ',
        unit: 'таблеток',
        manufacturer: 'АО ВЕРТЕКС',
        packageDescription: 'УПАКОВКА по 10 шт',
        registrationId: 'ЛП-002969',
      );
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new', extra: entry);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-name-input')),
            )
            .controller!
            .text,
        'Препарат',
      );
      await reveal(tester, 'drug-ingredient-input');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-ingredient-input')),
            )
            .controller!
            .text,
        'Флуоцинолона ацетонид',
      );
      await reveal(tester, 'drug-form-input');
      expect(find.text('Таблетки, покрытые оболочкой'), findsWidgets);
      await reveal(tester, 'package-location-input');
      await tester.enterText(
        find.byKey(const ValueKey('package-location-input')),
        'Шкаф',
      );
      await tester.scrollUntilVisible(
        find.text('Добавить упаковку'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Добавить упаковку'));
      await tester.pumpAndSettle();
      final medicine = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(medicine.catalogEntryId, entry.id);
      expect(medicine.name, entry.name);
      expect(medicine.activeIngredient, entry.activeIngredient);
      expect(medicine.form, entry.form);
      expect(medicine.manufacturer, entry.manufacturer);
      expect(medicine.packageDescription, entry.packageDescription);
      expect(medicine.registrationId, entry.registrationId);
      expect(medicine.dosage, '500 МЕ');
      await tester.scrollUntilVisible(
        find.text('Препарат'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Препарат'), findsOneWidget);
      expect(
        find.text('500 МЕ · Таблетки, покрытые оболочкой'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected capsule variant fills fields and saves without guessing package data',
    (tester) async {
      final container = await mount(tester);
      await reveal(tester, 'package-quantity-input');
      await tester.enterText(
        find.byKey(const ValueKey('package-quantity-input')),
        '7',
      );
      await reveal(tester, 'package-location-input');
      await tester.enterText(
        find.byKey(const ValueKey('package-location-input')),
        'Дорожная аптечка',
      );
      await search(tester, 'нурофен капсулы 400');
      await tester.scrollUntilVisible(
        find.text('Нурофен Экспресс Форте'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Нурофен Экспресс Форте'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      await reveal(tester, 'drug-ingredient-input');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-ingredient-input')),
            )
            .controller!
            .text,
        'Ибупрофен',
      );
      await reveal(tester, 'drug-form-input');
      expect(find.text('Капсулы'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-dosage-input')),
            )
            .controller!
            .text,
        '400 мг',
      );
      await tester.tap(find.text('Добавить упаковку'));
      await tester.pumpAndSettle();
      final medicine = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(medicine.name, 'Нурофен Экспресс Форте');
      expect(medicine.activeIngredient, 'Ибупрофен');
      expect(medicine.form, 'Капсулы');
      expect(medicine.dosage, '400 мг');
      expect(medicine.unit, 'капсул');
      expect(medicine.quantity, 7);
      expect(medicine.location, 'Дорожная аптечка');
      expect(medicine.expiryDate, isNull);
      expect(medicine.gtin, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real catalog retains source details and an unknown dose through save and backup',
    (tester) async {
      final catalog = MdlpDrugCatalogService();
      // Asset IO/isolate parsing run outside the fake widget-test clock.
      await tester.runAsync(() => catalog.search('гомеовокс'));
      final container = await mount(tester, catalog: catalog);
      await search(tester, 'гомеовокс');
      await tester.scrollUntilVisible(
        find.text('Гомеовокс').first,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Гомеовокс').first);
      await tester.pumpAndSettle();
      // Collapsing the results can leave the list below the package fields.
      await reveal(tester, 'drug-name-input', delta: -200);
      await reveal(tester, 'package-location-input');
      await tester.enterText(
        find.byKey(const ValueKey('package-location-input')),
        'Шкаф',
      );
      await tester.tap(find.text('Добавить упаковку'));
      await tester.pumpAndSettle();
      final state = container.read(appControllerProvider).requireValue;
      final medicine = state.medicines.last;
      expect(medicine.name, 'Гомеовокс');
      expect(medicine.dosage, isEmpty);
      expect(medicine.dosageLabel, 'Дозировка не указана');
      expect(medicine.catalogEntryId, startsWith('mdlp:'));
      expect(medicine.manufacturer, isNotEmpty);
      expect(medicine.packageDescription, isNotEmpty);
      expect(medicine.catalogVersion, '2026-10-01');
      expect(medicine.gtin, isNull);
      final restored = BackupCodec.decode(BackupCodec.encode(state))
          .medicines
          .last;
      expect(restored.toJson(), medicine.toJson());
      expect(
        restored.copyWith(quantity: 2).manufacturer,
        medicine.manufacturer,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing a chosen name removes stale autofill and allows manual save',
    (tester) async {
      final container = await mount(tester);
      await search(tester, 'лора');
      await tester.scrollUntilVisible(
        find.text('Лоратадин'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Лоратадин'));
      await tester.pumpAndSettle();
      await search(tester, 'Свой препарат');
      expect(find.text('Совпадений не найдено'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Заполнить вручную'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Заполнить вручную'));
      await tester.pumpAndSettle();
      await reveal(tester, 'drug-ingredient-input', delta: -200);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-ingredient-input')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await reveal(tester, 'drug-dosage-input');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-dosage-input')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('drug-dosage-input')),
        'по упаковке',
      );
      await reveal(tester, 'package-location-input');
      await tester.enterText(
        find.byKey(const ValueKey('package-location-input')),
        'Шкаф',
      );
      await tester.tap(find.text('Добавить упаковку'));
      await tester.pumpAndSettle();
      final medicine = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(medicine.name, 'Свой препарат');
      expect(medicine.activeIngredient, isNull);
      expect(medicine.dosage, 'по упаковке');
      expect(medicine.gtin, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
