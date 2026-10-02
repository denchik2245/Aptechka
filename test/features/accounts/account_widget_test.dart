import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/features/accounts/application/account_controller.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'narrow screen with large text: demo email, import and logout preserve guest data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      appRouter.go('/account');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AptechkaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Демо входа по почте'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Демо входа по почте'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Показать демо-код'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '111111');
      await tester.tap(find.text('Войти в демо'));
      await tester.pumpAndSettle();
      expect(find.text('Введите показанный демо-код 123456'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Войти в демо'));
      await tester.pumpAndSettle();
      expect(
        container.read(localAccountsProvider).requireValue.active,
        isNotNull,
      );
      expect(
        container.read(appControllerProvider).requireValue.medicines,
        isEmpty,
      );
      await tester.scrollUntilVisible(
        find.text('Скопировать гостевые аптечки'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Скопировать гостевые аптечки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Скопировать выбранные'));
      await tester.pumpAndSettle();
      expect(
        container.read(appControllerProvider).requireValue.medicines,
        hasLength(5),
      );
      await tester.scrollUntilVisible(
        find.text('Выйти из демо-профиля'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выйти из демо-профиля'));
      await tester.pumpAndSettle();
      expect(container.read(localAccountsProvider).requireValue.active, isNull);
      expect(
        container.read(appControllerProvider).requireValue.medicines,
        hasLength(6),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
