import 'dart:convert';

import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:aptechka/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'treatment_widgets.dart';
import 'reminders_screen.dart';
import 'intake_actions.dart';
import 'treatment_shopping.dart';

String courseDates(TreatmentCourse c) =>
    '${treatmentDate(c.startsAt)}${c.endsAt == null ? ' · постоянно' : ' — ${treatmentDate(c.endsAt!)}'}';
String coursePerson(TreatmentCourse c) => c.person == 'Я'
    ? 'Для меня'
    : c.person == 'Мама'
    ? 'Для мамы'
    : c.person == 'Миша'
    ? 'Для Миши'
    : 'Для: ${c.person}';
List<IntakeRecord> courseRecords(AppState state, String id) {
  final ids = state.reminders
      .where((r) => r.courseId == id)
      .map((r) => r.id)
      .toSet();
  return state.intakeRecords.where((r) => ids.contains(r.reminderId)).toList();
}

class CourseCard extends StatelessWidget {
  const CourseCard({required this.course, required this.state, super.key});
  final TreatmentCourse course;
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final c = course;
    final done = c.isCompletedAt(DateTime.now());
    final reminders = TreatmentSchedule.courseReminders(state, c.id);
    final records = courseRecords(state, c.id);
    final taken = records.where((r) => r.status == IntakeStatus.taken).length;
    final marked = records
        .where((r) => r.status != IntakeStatus.deferred)
        .length;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/treatment/course/${c.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${coursePerson(c)} · ${courseDates(c)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: c.durationDays == null
                    ? 0
                    : c.dayNumber(DateTime.now()) / c.durationDays!,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
                color: done ? Colors.green : null,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                children: [
                  Text(
                    done
                        ? 'Завершён'
                        : c.status == CourseStatus.paused
                        ? 'На паузе'
                        : c.durationDays == null
                        ? 'С ${treatmentDate(c.startsAt)}'
                        : 'День ${c.dayNumber(DateTime.now())} из ${c.durationDays}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Принято $taken из $marked',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final id in reminders.map((r) => r.medicineId).toSet()) ...[
                Text(
                  '${state.medicines.where((m) => m.id == id).firstOrNull?.name ?? 'Препарат'} · ${reminders.where((r) => r.medicineId == id).length} раз(а) в день',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
              if (!done && stockWarning(state, c) != null) ...[
                const SizedBox(height: 10),
                Text(
                  stockWarning(state, c)!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? stockWarning(AppState state, TreatmentCourse c) {
  final rs = TreatmentSchedule.courseReminders(state, c.id);
  for (final id in rs.map((r) => r.medicineId).toSet()) {
    final m = state.medicines.where((m) => m.id == id).firstOrNull;
    if (m == null) continue;
    final group = rs.where((r) => r.medicineId == id).toList();
    if (!group.first.unit.startsWith(
      m.unit.substring(0, m.unit.length < 3 ? m.unit.length : 3),
    )) {
      continue;
    }
    final from = treatmentDay(DateTime.now()).isBefore(c.startsAt)
        ? c.startsAt
        : treatmentDay(DateTime.now());
    final required = TreatmentSchedule.requiredStock(
      group,
      c.startsAt,
      c.endsAt ?? from.add(const Duration(days: 7)),
      from,
    );
    if (required > m.quantity) {
      return '${m.name}: в аптечке ${m.quantity} ${m.unit}, на оставшийся курс нужно $required';
    }
  }
  return null;
}

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).asData?.value;
    final c = state?.courses.where((c) => c.id == id).firstOrNull;
    if (c == null || state == null) {
      return TreatmentPage(
        title: 'Курс',
        children: const [Text('Курс не найден')],
      );
    }
    final done = c.isCompletedAt(DateTime.now());
    final rs = TreatmentSchedule.courseReminders(state, id);
    final records = courseRecords(state, id);
    final taken = records.where((r) => r.status == IntakeStatus.taken).length;
    final skipped = records
        .where((r) => r.status == IntakeStatus.skipped)
        .length;
    final warning = stockWarning(state, c);
    final now = treatmentDay(DateTime.now());
    var ahead = 0;
    if (!done && c.endsAt != null) {
      for (
        var day = now;
        !day.isAfter(c.endsAt!);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        ahead += TreatmentSchedule.forDay(
          state,
          day,
          courseId: id,
          history: true,
        ).where((s) => !s.marked).length;
      }
    }
    final controller = ref.read(appControllerProvider.notifier);
    return TreatmentPage(
      title: c.name,
      bottomBar: const AppNavigationBar(selectedIndex: 1),
      children: [
        if (done) ...[
          TreatmentBanner(
            'Курс завершён${c.completedAt == null ? '' : ' ${treatmentDate(c.completedAt!)}'}',
            'Принято $taken из ${taken + skipped} приёмов. Если симптомы остались, обратитесь к врачу',
            success: true,
          ),
          const SizedBox(height: 16),
        ],
        TreatmentCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tag(context, coursePerson(c)),
                    _tag(context, courseDates(c)),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: c.durationDays == null
                      ? 0
                      : c.dayNumber(now) / c.durationDays!,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                ),
                const SizedBox(height: 8),
                Text(
                  done
                      ? 'Завершён'
                      : c.status == CourseStatus.paused
                      ? 'На паузе'
                      : c.durationDays == null
                      ? 'Постоянный курс'
                      : 'День ${c.dayNumber(now)} из ${c.durationDays}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  spacing: 8,
                  children: [
                    for (final (n, label, color) in [
                      (taken, 'принято', Colors.green),
                      (skipped, 'пропущено', Colors.red),
                      (
                        ahead,
                        'впереди',
                        Theme.of(context).colorScheme.onSurface,
                      ),
                    ])
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                              Text(
                                label,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!done && warning != null) ...[
          const SizedBox(height: 16),
          TreatmentBanner(
            'Не хватит до конца курса',
            warning,
            action: 'В список покупок',
            onAction: () => showTreatmentShopping(
              context,
              ref,
              rs.map((r) => r.medicineId),
            ),
          ),
        ],
        const TreatmentSection('Препараты'),
        for (final mid in rs.map((r) => r.medicineId).toSet()) ...[
          CourseDrugCard(
            state: state,
            reminders: rs.where((r) => r.medicineId == mid).toList(),
          ),
          const SizedBox(height: 16),
        ],
        const TreatmentSection('Назначение врача'),
        if (c.prescription != null)
          TreatmentCard(
            child: ListTile(
              leading: const DesignIcon('treatment-photo-24', size: 25.2),
              title: const Text('Назначение врача'),
              subtitle: const Text('Фото'),
              trailing: TextButton(
                onPressed: () => showPrescription(context, c.prescription!),
                child: const Text('Открыть'),
              ),
            ),
          )
        else
          const Text('Назначение не прикреплено'),
        TreatmentSection(
          'Последние дни',
          trailing: TextButton(
            onPressed: () => context.push('/treatment/course/$id/history'),
            child: const Text('Вся история'),
          ),
        ),
        TreatmentCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Builder(
                    builder: (context) {
                      final day = DateTime(now.year, now.month, now.day - i);
                      final slots = TreatmentSchedule.forDay(
                        state,
                        day,
                        courseId: id,
                        history: true,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () =>
                              context.push('/treatment/course/$id/history'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${i == 0
                                      ? 'Сегодня, '
                                      : i == 1
                                      ? 'Вчера, '
                                      : ''}${treatmentDate(day)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              ...slots
                                  .take(7)
                                  .map(
                                    (s) => Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              s.record?.status ==
                                                  IntakeStatus.taken
                                              ? Colors.green
                                              : s.record?.status ==
                                                    IntakeStatus.skipped
                                              ? Colors.red
                                              : Theme.of(context)
                                                    .scaffoldBackgroundColor,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              Text(
                                '${slots.where((s) => s.marked).length} из ${slots.length}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        if (!done) ...[
          const TreatmentSection('Напоминания'),
          TextButton(
            onPressed: () => context.push('/treatment/notification/$id'),
            child: const Text('Предпросмотр напоминания'),
          ),
          TreatmentSwitch(
            'Напоминать о приёме',
            c.notifications,
            onChanged: (v) => treatmentAction(
              context,
              () => controller.updateCourse(c.copyWith(notifications: v)),
            ),
          ),
          TreatmentSelect(
            'Повтор',
            'Через ${c.repeatMinutes} минут',
            onTap: () async {
              final v = await treatmentChoice(context, 'Повтор', [
                'Без повтора',
                'Через 5 минут',
                'Через 10 минут',
                'Через 15 минут',
                'Через 30 минут',
              ], 'Через ${c.repeatMinutes} минут');
              if (v != null && context.mounted) {
                await treatmentAction(
                  context,
                  () => controller.updateCourse(
                    c.copyWith(
                      repeatMinutes:
                          int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ??
                          0,
                    ),
                  ),
                );
              }
            },
          ),
          TreatmentSwitch(
            'Сообщать близким о пропуске',
            c.notifyFamily,
            onChanged: (v) => treatmentAction(
              context,
              () => controller.updateCourse(c.copyWith(notifyFamily: v)),
            ),
          ),
          const SizedBox(height: 16),
          TreatmentButton(
            'Изменить курс',
            secondary: true,
            onPressed: () => context.push('/treatment/new?edit=$id'),
          ),
          const SizedBox(height: 8),
          TreatmentButton(
            c.status == CourseStatus.paused ? 'Продолжить' : 'Приостановить',
            secondary: true,
            onPressed: () => treatmentAction(
              context,
              () => controller.updateCourse(
                c.copyWith(
                  status: c.status == CourseStatus.paused
                      ? CourseStatus.active
                      : CourseStatus.paused,
                ),
              ),
            ),
          ),
          TreatmentButton(
            'Завершить курс',
            danger: true,
            onPressed: () async {
              if (await treatmentConfirm(
                    context,
                    'Завершить курс?',
                    'Приёмы и история сохранятся.',
                    'Завершить',
                  ) &&
                  context.mounted) {
                await treatmentAction(
                  context,
                  () => controller.updateCourse(
                    c.copyWith(
                      status: CourseStatus.completed,
                      completedAt: DateTime.now(),
                    ),
                  ),
                );
              }
            },
          ),
        ] else ...[
          const SizedBox(height: 24),
          TreatmentButton(
            'Повторить курс',
            secondary: true,
            onPressed: () => context.push('/treatment/new?repeat=$id'),
          ),
          const SizedBox(height: 8),
          TreatmentButton(
            'Удалить курс',
            danger: true,
            onPressed: () async {
              if (await treatmentConfirm(
                    context,
                    'Удалить курс?',
                    'Курс и его история приёмов будут удалены.',
                    'Удалить',
                  ) &&
                  context.mounted) {
                await treatmentAction(
                  context,
                  () => controller.deleteCourse(id),
                );
                if (context.mounted) context.go('/reminders');
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _tag(BuildContext c, String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(c).scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(t, style: const TextStyle(fontSize: 12)),
  );
}

class CourseDrugCard extends StatelessWidget {
  const CourseDrugCard({
    required this.state,
    required this.reminders,
    this.onEdit,
    super.key,
  });
  final AppState state;
  final List<MedicationReminder> reminders;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final r = reminders.first;
    final m = state.medicines.where((m) => m.id == r.medicineId).firstOrNull;
    if (m == null) return const SizedBox.shrink();
    return TreatmentCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TreatmentDrugIcon(m),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicineTitle(m),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${r.dose} · ${frequencyLabel(r)}${r.condition.isEmpty ? '' : ' · ${r.condition}'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  TextButton(onPressed: onEdit, child: const Text('Изменить')),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: reminders
                  .map(
                    (r) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        r.timeLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Text(
              'В аптечке ${m.quantity} ${m.unit}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String frequencyLabel(MedicationReminder r) => switch (r.frequency) {
  IntakeFrequency.daily => 'каждый день',
  IntakeFrequency.alternate => 'через день',
  IntakeFrequency.weekdays =>
    r.weekdays
        .map((d) => const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][d - 1])
        .join(', '),
  IntakeFrequency.cycles =>
    '${r.cycleDays} дней приём, ${r.breakDays} дней перерыв',
};
Future<void> showPrescription(BuildContext context, String uri) => showDialog(
  context: context,
  builder: (c) => Dialog(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => Navigator.pop(c),
            icon: const Icon(Icons.close),
          ),
        ),
        Flexible(
          child: InteractiveViewer(
            child: Image.memory(
              base64Decode(uri.split(',').last),
              errorBuilder: (_, e, s) => const Text('Не удалось открыть фото'),
            ),
          ),
        ),
      ],
    ),
  ),
);

class CourseHistoryScreen extends ConsumerStatefulWidget {
  const CourseHistoryScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<CourseHistoryScreen> createState() => _CourseHistoryState();
}

class _CourseHistoryState extends ConsumerState<CourseHistoryScreen> {
  String filter = 'Все';
  int days = 30;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).asData?.value;
    final c = state?.courses.where((c) => c.id == widget.id).firstOrNull;
    if (state == null || c == null) {
      return const TreatmentPage(
        title: 'История приёмов',
        children: [Text('Курс не найден')],
      );
    }
    final rs = state.reminders.where((r) => r.courseId == c.id).toList();
    final names = state.medicines
        .where((m) => rs.any((r) => r.medicineId == m.id))
        .map((m) => m.name)
        .toList();
    final end = c.endsAt != null && c.endsAt!.isBefore(DateTime.now())
        ? c.endsAt!
        : treatmentDay(DateTime.now());
    final length = treatmentDaysBetween(c.startsAt, end) + 1;
    return TreatmentPage(
      title: 'История приёмов',
      bottomBar: const AppNavigationBar(selectedIndex: 1),
      children: [
        TreatmentChips(
          values: ['Все', 'Пропущенные', ...names],
          selected: {filter},
          onSelected: (v) => setState(() => filter = v),
          horizontal: true,
        ),
        const SizedBox(height: 16),
        const Text('Нажмите на приём, чтобы изменить отметку'),
        for (var i = 0; i < length && i < days; i++)
          Builder(
            builder: (context) {
              final date = DateTime(end.year, end.month, end.day - i);
              final slots =
                  TreatmentSchedule.forDay(
                        state,
                        date,
                        courseId: c.id,
                        history: true,
                      )
                      .where(
                        (s) =>
                            filter == 'Все' ||
                            filter == 'Пропущенные' &&
                                s.record?.status == IntakeStatus.skipped ||
                            s.medicine.name == filter,
                      )
                      .toList();
              if (slots.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TreatmentSection(treatmentDate(date)),
                  ...slots.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: IntakeRow(
                        intake: s,
                        history: true,
                        onTap: () => showIntakeAction(context, ref, s),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        if (length <= 0)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('Приёмы ещё не начались'),
          ),
        if (length > days)
          TextButton(
            onPressed: () => setState(() => days += 30),
            child: const Text('Показать ещё'),
          ),
      ],
    );
  }
}
