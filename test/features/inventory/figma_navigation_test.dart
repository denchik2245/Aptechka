import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/presentation/widgets/medicine_list_card.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
import 'package:aptechka/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'three Figma menu items and separate search open real destinations',
    (tester) async {
      appRouter.go('/');
      await tester.pumpWidget(const ProviderScope(child: AptechkaApp()));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppNavigationBar),
          matching: find.text('Аптечка'),
        ),
        findsOneWidget,
      );
      expect(find.text('Лечение'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Содержимое'), findsNothing);
      await tester.tap(find.text('Лечение'));
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/reminders');
      await tester.tap(find.text('Настройки').last);
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/settings');
      await tester.tap(find.byTooltip('Поиск'));
      await tester.pumpAndSettle();
      expect(find.text('Поиск по вашим аптечкам'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Лоратадин');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(MedicineListCard, 'Лоратадин'),
        findsNWidgets(2),
      );
      expect(find.text('Ибупрофен'), findsNothing);
      await tester.tap(
        find.widgetWithText(MedicineListCard, 'Лоратадин').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Где лежит'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Как применять'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Как применять'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppNavigationBar),
          matching: find.text('Аптечка'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('stock controls preserve dates and cannot reduce below zero', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = await container.read(appControllerProvider.future);
    final medicine = before.medicines.first;
    appRouter.go('/medicine/${medicine.id}');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Увеличить остаток'));
    await tester.tap(find.byTooltip('Увеличить остаток'));
    await tester.pumpAndSettle();
    final after = container
        .read(appControllerProvider)
        .requireValue
        .medicines
        .first;
    expect(after.quantity, medicine.quantity + 1);
    expect(after.expiryDate, medicine.expiryDate);
    expect(after.openedAt, medicine.openedAt);
    expect(after.afterOpeningDays, medicine.afterOpeningDays);
    await container
        .read(appControllerProvider.notifier)
        .updatePackage(
          medicineId: medicine.id,
          quantity: 0,
          location: medicine.location,
          expiryDate: medicine.expiryDate,
          openedAt: medicine.openedAt,
          afterOpeningDays: medicine.afterOpeningDays,
        );
    await tester.pumpAndSettle();
    final minus = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Уменьшить остаток',
      ),
    );
    expect(minus.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  test('removing one package removes only its related reminders and keeps a valid backup', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = await container.read(appControllerProvider.future);
    final reminder = state.reminders.first;
    await container
        .read(appControllerProvider.notifier)
        .recordIntake(reminder.id, IntakeStatus.taken);
    await container
        .read(appControllerProvider.notifier)
        .removePackage(reminder.medicineId);
    final after = container.read(appControllerProvider).requireValue;
    expect(after.medicines.any((m) => m.id == reminder.medicineId), isFalse);
    expect(after.medicines.length, state.medicines.length - 1);
    expect(
      after.reminders.any((r) => r.medicineId == reminder.medicineId),
      isFalse,
    );
    expect(
      after.intakeRecords.any((r) => r.reminderId == reminder.id),
      isFalse,
    );
    expect(
      BackupCodec.decode(BackupCodec.encode(after)).medicines.length,
      after.medicines.length,
    );
  });
}
