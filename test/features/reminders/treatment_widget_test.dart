import 'dart:io';
import 'dart:ui' as ui;

import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts = FontLoader('Manrope');
    for (final weight in [
      'regular',
      'medium',
      'semibold',
      'bold',
      'extrabold',
    ]) {
      fonts.addFont(rootBundle.load('assets/fonts/manrope-$weight.ttf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
    } else {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('TREATMENT_SCREENSHOTS')) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('tmp/treatment-$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> open(
    WidgetTester tester,
    ProviderContainer container, {
    String path = '/reminders',
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go(path);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RepaintBoundary(
          key: ValueKey('capture'),
          child: AptechkaApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'wizard creates a course from stock, retains settings and opens history',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      await open(tester, container);
      await tester.tap(find.byTooltip('Добавить курс'));
      await tester.pumpAndSettle();
      await capture(tester, 'new');
      await tester.enterText(find.byType(TextFormField), 'Мой курс');
      await reveal(tester, find.text('Далее'));
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ Добавить препарат'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Лоратадин');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Лоратадин, 10 мг').first);
      await tester.pumpAndSettle();
      await capture(tester, 'regimen');
      await reveal(tester, find.text('Сохранить препарат'));
      await tester.tap(find.text('Сохранить препарат'));
      await tester.pumpAndSettle();
      expect(find.text('Лоратадин, 10 мг'), findsOneWidget);
      await reveal(tester, find.text('Далее'));
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      await capture(tester, 'settings');
      await reveal(tester, find.text('Создать курс'));
      await tester.tap(find.text('Создать курс'));
      await tester.pumpAndSettle();
      expect(
        container.read(appControllerProvider).requireValue.courses.single.name,
        'Мой курс',
      );
      expect(find.text('Мой курс'), findsOneWidget);
      await capture(tester, 'detail');
      await reveal(tester, find.text('Вся история'));
      await tester.tap(find.text('Вся история'));
      await tester.pumpAndSettle();
      expect(find.text('История приёмов'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'today actions, courses and history work at narrow width with large type',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      final controller = container.read(appControllerProvider.notifier);
      await controller.setReminderEnabled('reminder-loratadine', false);
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day - 2);
      await controller.saveCourse(
        TreatmentCourse(
          id: 'test',
          name: 'Простуда',
          person: 'Я',
          startsAt: start,
        ),
        [
          const MedicationReminder(
            id: 'r',
            medicineId: 'ibuprofen-demo',
            courseId: 'test',
            hour: 0,
            minute: 0,
            dose: '1 таблетка',
            enabled: true,
            unit: 'таблетка',
          ),
        ],
      );
      await controller.updateSettings(
        const AppSettings(appearance: AppAppearance.dark, textScale: 1.3),
      );
      await open(tester, container, size: const Size(320, 700));
      await reveal(tester, find.text('Принял'));
      await tester.tap(find.text('Принял'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appControllerProvider)
            .requireValue
            .intakeRecords
            .single
            .status,
        IntakeStatus.taken,
      );
      await capture(tester, 'dark');
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Курсы'));
      await tester.tap(find.text('Курсы'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Простуда'));
      await tester.tap(find.text('Простуда'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Вся история'));
      await tester.tap(find.text('Вся история'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ибупрофен, 200 мг').first);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Не принимал'));
      await tester.tap(find.text('Не принимал'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appControllerProvider)
            .requireValue
            .intakeRecords
            .single
            .status,
        IntakeStatus.skipped,
      );
      expect(
        container
            .read(appControllerProvider)
            .requireValue
            .medicines
            .first
            .quantity,
        14,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty state and completed course retain their Figma actions', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final controller = container.read(appControllerProvider.notifier);
    await controller.setReminderEnabled('reminder-loratadine', false);
    final today = treatmentDay(DateTime.now());
    await controller.saveCourse(
      TreatmentCourse(
        id: 'done',
        name: 'Завершённый курс',
        person: 'Мама',
        startsAt: today,
        status: CourseStatus.completed,
        completedAt: today,
      ),
      [
        const MedicationReminder(
          id: 'done-r',
          medicineId: 'ibuprofen-demo',
          courseId: 'done',
          hour: 8,
          minute: 0,
          dose: '1 таблетка',
          unit: 'таблетка',
          enabled: true,
        ),
      ],
    );
    await open(tester, container, path: '/treatment/course/done');
    await reveal(tester, find.text('Повторить курс'));
    await tester.tap(find.text('Повторить курс'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'Завершённый курс'),
      findsOneWidget,
    );
    await controller.clearInventory();
    appRouter.go('/reminders');
    await tester.pumpAndSettle();
    expect(find.text('Добавьте первый курс'), findsOneWidget);
    await capture(tester, 'empty');
    expect(tester.takeException(), isNull);
  });
}
