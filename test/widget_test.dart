import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opens pharmacy, groups packages and shows package details', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    appRouter.go('/');

    await tester.pumpWidget(const ProviderScope(child: AptechkaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Мои аптечки'), findsOneWidget);
    await tester.tap(find.text('Дом'));
    await tester.pumpAndSettle();
    expect(find.text('Содержимое аптечки'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ибупрофен');
    await tester.pumpAndSettle();
    expect(find.text('Ибупрофен'), findsWidgets);
    await tester.tap(find.text('Ибупрофен').last);
    await tester.pumpAndSettle();
    expect(find.text('14 таблеток'), findsOneWidget);
    expect(find.text('6 таблеток'), findsOneWidget);

    await tester.tap(find.text('14 таблеток'));
    await tester.pumpAndSettle();
    expect(find.text('ГДЕ ЛЕЖИТ'), findsOneWidget);
    expect(find.text('Верхняя полка'), findsOneWidget);
  });

  testWidgets('shows only packages from the selected pharmacy', (tester) async {
    SharedPreferences.setMockInitialValues({});
    appRouter.go('/');

    await tester.pumpWidget(const ProviderScope(child: AptechkaApp()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Аптечка мамы'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Аптечка мамы'));
    await tester.pumpAndSettle();

    expect(find.text('Лоратадин'), findsOneWidget);
    expect(find.text('Ибупрофен'), findsNothing);
  });
}
