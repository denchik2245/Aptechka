import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final start = DateTime(2026, 10, 26);
  MedicationReminder reminder({
    IntakeFrequency frequency = IntakeFrequency.daily,
    List<int> weekdays = const [1, 3, 5],
    int? duration,
  }) => MedicationReminder(
    id: 'r',
    medicineId: 'ibuprofen-demo',
    hour: 8,
    minute: 0,
    dose: '2 таблетки',
    enabled: true,
    courseId: 'c',
    amount: 2,
    unit: 'таблетка',
    frequency: frequency,
    weekdays: weekdays,
    cycleDays: 2,
    breakDays: 1,
    durationDays: duration,
  );
  test(
    'schedules respect start, alternate days, weekdays, cycles and duration',
    () {
      expect(reminder().occursOn(DateTime(2026, 10, 25), start), false);
      expect(
        reminder(frequency: IntakeFrequency.alternate)
            .occursOn(DateTime(2026, 10, 27), start),
        false,
      );
      expect(
        reminder(frequency: IntakeFrequency.alternate)
            .occursOn(DateTime(2026, 10, 28), start),
        true,
      );
      expect(
        reminder(frequency: IntakeFrequency.weekdays)
            .occursOn(DateTime(2026, 10, 27), start),
        false,
      );
      expect(
        reminder(frequency: IntakeFrequency.weekdays)
            .occursOn(DateTime(2026, 10, 28), start),
        true,
      );
      expect(
        reminder(frequency: IntakeFrequency.cycles)
            .occursOn(DateTime(2026, 10, 28), start),
        false,
      );
      expect(
        reminder(frequency: IntakeFrequency.cycles)
            .occursOn(DateTime(2026, 10, 29), start),
        true,
      );
      expect(
        reminder(duration: 2).occursOn(DateTime(2026, 10, 28), start),
        false,
      );
      expect(
        TreatmentSchedule.requiredStock(
          [reminder(frequency: IntakeFrequency.weekdays)],
          start,
          DateTime(2026, 11, 1),
          start,
        ),
        6,
      );
    },
  );
  test('legacy JSON remains readable without courses or schedule fields', () {
    final state = AppState.fromJson({
      'medicines': [],
      'reminders': [
        {
          'id': 'r',
          'medicineId': 'm',
          'hour': 9,
          'minute': 0,
          'dose': '1 доза',
          'enabled': true,
        },
      ],
      'intakeRecords': [
        {
          'reminderId': 'r',
          'occurredAt': '2026-10-01T09:00:00',
          'status': 'taken',
        },
      ],
    });
    expect(state.courses, isEmpty);
    expect(state.reminders.single.frequency, IntakeFrequency.daily);
    expect(state.intakeRecords.single.stockDelta, 0);
  });
  test('course, photo and reminders survive backup and restore', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final initial = await container.read(appControllerProvider.future);
    final course = TreatmentCourse(
      id: 'c',
      name: 'Курс',
      person: 'Мама',
      startsAt: start,
      prescription: 'data:image/png;base64,AAAA',
    );
    await container.read(appControllerProvider.notifier).saveCourse(course, [
      reminder(),
    ]);
    final state = container.read(appControllerProvider).requireValue;
    expect(
      BackupCodec.decode(BackupCodec.encode(state)).toJson(),
      state.toJson(),
    );
    final invalid = state.copyWith(courses: []);
    expect(
      () => BackupCodec.decode(BackupCodec.encode(invalid)),
      throwsFormatException,
    );
    expect(initial.courses, isEmpty);
  });
  test(
    'corrections and duplicate taps deduct once; skip restores the exact stock',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      final controller = container.read(appControllerProvider.notifier);
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      await controller.saveCourse(
        TreatmentCourse(
          id: 'c',
          name: 'Курс',
          person: 'Я',
          startsAt: yesterday,
        ),
        [reminder()],
      );
      int quantity() => container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .first
          .quantity;
      await controller.recordIntake(
        'r',
        IntakeStatus.taken,
        scheduledDate: yesterday,
      );
      expect(quantity(), 12);
      await controller.recordIntake(
        'r',
        IntakeStatus.taken,
        scheduledDate: yesterday,
      );
      expect(quantity(), 12);
      await controller.recordIntake(
        'r',
        IntakeStatus.skipped,
        scheduledDate: yesterday,
        reason: 'Нет с собой',
      );
      expect(quantity(), 14);
      await controller.recordIntake(
        'r',
        IntakeStatus.deferred,
        deferredUntil: now.add(const Duration(minutes: 15)),
      );
      expect(quantity(), 14);
      await controller.recordIntake('r', IntakeStatus.taken);
      expect(quantity(), 12);
      expect(
        container.read(appControllerProvider).requireValue.intakeRecords.length,
        2,
      );
      await expectLater(
        controller.recordIntake(
          'r',
          IntakeStatus.taken,
          scheduledDate: now.add(const Duration(days: 1)),
        ),
        throwsStateError,
      );
    },
  );
  test('pause preserves history, completion stops pending intakes, delete clears references', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final controller = container.read(appControllerProvider.notifier);
    final today = treatmentDay(DateTime.now());
    final c = TreatmentCourse(
      id: 'c',
      name: 'Курс',
      person: 'Я',
      startsAt: today,
    );
    await controller.saveCourse(c, [reminder()]);
    await controller.recordIntake('r', IntakeStatus.taken);
    await controller.updateCourse(c.copyWith(status: CourseStatus.paused));
    var state = container.read(appControllerProvider).requireValue;
    expect(TreatmentSchedule.forDay(state, today, courseId: 'c'), isEmpty);
    expect(
      TreatmentSchedule.forDay(
        state,
        today,
        courseId: 'c',
        history: true,
      ).single.marked,
      true,
    );
    await controller.updateCourse(
      c.copyWith(status: CourseStatus.completed, completedAt: today),
    );
    state = container.read(appControllerProvider).requireValue;
    expect(
      TreatmentSchedule.forDay(
        state,
        today.add(const Duration(days: 1)),
        courseId: 'c',
      ),
      isEmpty,
    );
    await controller.deleteCourse('c');
    state = container.read(appControllerProvider).requireValue;
    expect(state.courses, isEmpty);
    expect(state.reminders.where((r) => r.courseId == 'c'), isEmpty);
    expect(state.intakeRecords, isEmpty);
  });
  test(
    'editing preserves old intake history and clearing removes courses',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      final controller = container.read(appControllerProvider.notifier);
      final today = treatmentDay(DateTime.now());
      final c = TreatmentCourse(
        id: 'c',
        name: 'Курс',
        person: 'Я',
        startsAt: today,
      );
      await controller.saveCourse(c, [reminder()]);
      await controller.recordIntake('r', IntakeStatus.taken);
      await controller.saveCourse(c, [reminder().copyWith(id: 'r2', hour: 12)]);
      var state = container.read(appControllerProvider).requireValue;
      expect(state.reminders.where((r) => r.id == 'r').single.enabled, false);
      expect(
        TreatmentSchedule.forDay(
          state,
          today,
          courseId: 'c',
          history: true,
        ).length,
        2,
      );
      await controller.clearInventory();
      state = container.read(appControllerProvider).requireValue;
      expect(state.courses, isEmpty);
    },
  );
}
