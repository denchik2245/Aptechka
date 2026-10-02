import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dark filters wrap, remain legible and location reset works', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .updateSettings(const AppSettings(appearance: AppAppearance.dark));
    appRouter.go('/inventory');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.labelStyle!.color, isNot(Colors.black));
    }
    final emptyChip = find.widgetWithText(FilterChip, 'Нет в наличии');
    await tester.ensureVisible(emptyChip);
    await tester.pumpAndSettle();
    await tester.tap(emptyChip);
    await tester.pumpAndSettle();
    expect(find.text('В этой аптечке ничего не найдено'), findsOneWidget);
    await tester.ensureVisible(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Все места'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все места'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Верхняя полка').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Нет в наличии'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('Все места'), findsOneWidget);
  });

  testWidgets('settings change theme, type size and warning window', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    appRouter.go('/settings');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тема'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.tap(find.text('Размер текста'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Очень крупный'));
    await tester.pumpAndSettle();
    expect(
      container.read(appControllerProvider).requireValue.settings.textScale,
      1.3,
    );
    await tester.scrollUntilVisible(
      find.text('Срок скоро истечёт'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Срок скоро истечёт'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('За 7 дней'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(appControllerProvider)
          .requireValue
          .settings
          .expiryWarningDays,
      7,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('alerts and paused schedule respond to settings', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .updateSettings(
          const AppSettings(
            expiryAlerts: false,
            stockAlerts: false,
            intakeSchedule: false,
          ),
        );
    appRouter.go('/reminders');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Предупреждения выключены'), findsOneWidget);
    expect(find.text('Расписание на паузе'), findsOneWidget);
    expect(find.text('Принял'), findsNothing);
  });

  testWidgets('large type stays usable on a short phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .updateSettings(
          const AppSettings(appearance: AppAppearance.dark, textScale: 1.3),
        );
    appRouter.go('/inventory');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    final empty = find.widgetWithText(FilterChip, 'Нет в наличии');
    await tester.ensureVisible(empty);
    await tester.pumpAndSettle();
    await tester.tap(empty);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    appRouter.go('/');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    appRouter.go('/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Удалить все записи'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('import validates before replacement and requires confirmation', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final original = await container.read(appControllerProvider.future);
    final backup = original.copyWith(
      medicines: [],
      reminders: [],
      intakeRecords: [],
    );
    appRouter.go('/settings');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Восстановить из копии'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Восстановить из копии'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{broken');
    await tester.tap(find.text('Проверить копию'));
    await tester.pumpAndSettle();
    expect(
      find.text('Копия повреждена или содержит некорректные записи.'),
      findsOneWidget,
    );
    expect(
      container.read(appControllerProvider).requireValue.medicines,
      hasLength(original.medicines.length),
    );
    await tester.enterText(find.byType(TextField), BackupCodec.encode(backup));
    await tester.tap(find.text('Проверить копию'));
    await tester.pumpAndSettle();
    expect(find.text('Восстановить данные?'), findsOneWidget);
    expect(
      container.read(appControllerProvider).requireValue.medicines,
      hasLength(original.medicines.length),
    );
    await tester.tap(find.text('Восстановить'));
    await tester.pumpAndSettle();
    expect(
      container.read(appControllerProvider).requireValue.medicines,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
