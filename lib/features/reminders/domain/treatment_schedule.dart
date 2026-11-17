import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';

import 'medication_reminder.dart';
import 'treatment_course.dart';

class TreatmentIntake {
  const TreatmentIntake(
    this.reminder,
    this.medicine,
    this.date,
    this.record,
    this.course,
  );
  final MedicationReminder reminder;
  final Medicine medicine;
  final DateTime date;
  final IntakeRecord? record;
  final TreatmentCourse? course;
  DateTime get plannedAt =>
      DateTime(date.year, date.month, date.day, reminder.hour, reminder.minute);
  DateTime get dueAt => record?.deferredUntil ?? plannedAt;
  bool get marked => record != null && record!.status != IntakeStatus.deferred;
}

abstract final class TreatmentSchedule {
  static List<TreatmentIntake> forDay(
    AppState state,
    DateTime date, {
    String? person,
    String? courseId,
    bool history = false,
  }) {
    final result = <TreatmentIntake>[];
    for (final reminder in state.reminders) {
      if (courseId != null && reminder.courseId != courseId) continue;
      final course = state.courses
          .where((c) => c.id == reminder.courseId)
          .firstOrNull;
      if (person != null && (course?.person ?? 'Я') != person) continue;
      final record = state.intakeRecords
          .where(
            (r) => r.reminderId == reminder.id && r.day == treatmentDay(date),
          )
          .firstOrNull;
      if (!history &&
          (!reminder.enabled ||
              !state.settings.intakeSchedule ||
              course?.status == CourseStatus.paused)) {
        continue;
      }
      if (!reminder.enabled && record == null) continue;
      if (!history &&
          course?.status == CourseStatus.completed &&
          record == null) {
        continue;
      }
      if (course != null &&
          (!course.includes(date) ||
              !reminder.occursOn(date, course.startsAt))) {
        continue;
      }
      if (reminder.courseId != null && course == null) continue;
      final medicine = state.medicines
          .where((m) => m.id == reminder.medicineId)
          .firstOrNull;
      if (medicine == null) continue;
      result.add(
        TreatmentIntake(reminder, medicine, treatmentDay(date), record, course),
      );
    }
    result.sort((a, b) => a.plannedAt.compareTo(b.plannedAt));
    return result;
  }

  static List<MedicationReminder> courseReminders(AppState state, String id) =>
      state.reminders.where((r) => r.courseId == id && r.enabled).toList();
  static int requiredStock(
    List<MedicationReminder> reminders,
    DateTime start,
    DateTime end,
    DateTime from,
  ) {
    var total = 0;
    for (
      var day = treatmentDay(from);
      !day.isAfter(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      for (final r in reminders) {
        if (r.occursOn(day, start)) total += r.amount;
      }
    }
    return total;
  }
}
