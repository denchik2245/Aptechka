import 'package:aptechka/app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the home dashboard with seeded local data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: AptechkaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Домашняя аптечка'), findsOneWidget);
    expect(find.text('Аптечка под контролем'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ибупрофен'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ибупрофен'), findsOneWidget);
  });
}
