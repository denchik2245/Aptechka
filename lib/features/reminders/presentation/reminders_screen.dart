import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/core/widgets/round_icon_button.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'treatment_widgets.dart';
import 'intake_actions.dart';
import 'course_detail_screen.dart';
import 'treatment_shopping.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool courses = false, allCompleted = false;
  String person = 'Все';
  DateTime date = treatmentDay(DateTime.now());
  @override
  Widget build(BuildContext context) => Scaffold(
    body: DefaultTextStyle.merge(
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      child: SafeArea(
        bottom: false,
        child: AsyncValueView(
          value: ref.watch(appControllerProvider),
          data: (state) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 124),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Лечение',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      RoundIconButton(
                        tooltip: 'Добавить курс',
                        primary: true,
                        icon: const DesignIcon('add'),
                        onPressed: () => context.push('/treatment/new'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.courses.isEmpty && state.reminders.isEmpty) ...[
                    const SizedBox(height: 32),
                    _empty(),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: secondaryFill(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          for (final (value, label) in [
                            (false, 'Сегодня'),
                            (true, 'Курсы'),
                          ])
                            Expanded(
                              child: Material(
                                color: courses == value
                                    ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLowest
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(() => courses = value),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: courses == value
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TreatmentChips(
                      values: {
                        'Все',
                        'Я',
                        ...state.courses.map((c) => c.person),
                      }.toList(),
                      selected: {person},
                      onSelected: (p) => setState(() => person = p),
                      horizontal: true,
                    ),
                    const SizedBox(height: 16),
                    if (courses) ..._courseList(state) else ..._today(state),
                  ],
                  if (state.treatmentShoppingIds.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          showTreatmentShopping(context, ref, const []),
                      child: Text(
                        'Список покупок · ${state.treatmentShoppingIds.length}',
                      ),
                    ),
                  if (!state.settings.expiryAlerts &&
                      !state.settings.stockAlerts)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text('Предупреждения выключены'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _empty() => TreatmentCard(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .08),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .5),
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_outlined, size: 24),
                const SizedBox(height: 12),
                Text(
                  'Иллюстрация',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Маскот с таблетницей и будильником',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Добавьте первый курс',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const Text(
            'Напомним, что, сколько и когда принять, сохраним отметки о приёме и посчитаем, хватит ли лекарства до конца курса',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TreatmentButton(
            'Добавить курс',
            onPressed: () => context.push('/treatment/new'),
          ),
        ],
      ),
    ),
  );

  List<Widget> _courseList(AppState state) {
    final filtered = state.courses
        .where((c) => person == 'Все' || c.person == person)
        .toList();
    final active = filtered
        .where((c) => !c.isCompletedAt(DateTime.now()))
        .toList();
    final completed = filtered
        .where((c) => c.isCompletedAt(DateTime.now()))
        .toList();
    return [
      Text(
        'Активные · ${active.length}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 16),
      ...active.map(
        (c) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CourseCard(course: c, state: state),
        ),
      ),
      if (filtered.isEmpty) _empty(),
      if (completed.isNotEmpty) ...[
        const TreatmentSection('Завершённые'),
        ...(allCompleted ? completed : completed.take(1)).map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CourseCard(course: c, state: state),
          ),
        ),
        if (completed.length > 1)
          TextButton(
            onPressed: () => setState(() => allCompleted = !allCompleted),
            child: Text(
              allCompleted ? 'Скрыть завершённые' : 'Показать все завершённые',
            ),
          ),
      ],
    ];
  }

  List<Widget> _today(AppState state) {
    final slots = TreatmentSchedule.forDay(
      state,
      date,
      person: person == 'Все' ? null : person,
    );
    final now = DateTime.now();
    final marked = slots.where((s) => s.marked).length;
    final current = slots
        .where((s) => !s.marked && !s.dueAt.isAfter(now))
        .lastOrNull;
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final future = treatmentDay(now).isBefore(date);
    return [
      Semantics(
        label: 'Неделя. Смахните влево или вправо для смены недели',
        onIncrease: () => setState(
          () => date = DateTime(date.year, date.month, date.day + 7),
        ),
        onDecrease: () => setState(
          () => date = DateTime(date.year, date.month, date.day - 7),
        ),
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0).abs() > 100) {
              setState(
                () => date = DateTime(
                  date.year,
                  date.month,
                  date.day + ((details.primaryVelocity ?? 0) < 0 ? 7 : -7),
                ),
              );
            }
          },
          child: Row(
            children: List.generate(7, (i) {
              final day = DateTime(monday.year, monday.month, monday.day + i);
              final selected = day == date;
              final ds = TreatmentSchedule.forDay(
                state,
                day,
                person: person == 'Все' ? null : person,
              );
              final done = ds.where((s) => s.marked).length;
              final skipped = ds.any(
                (s) => s.record?.status == IntakeStatus.skipped,
              );
              return Expanded(
                child: Semantics(
                  selected: selected,
                  child: InkWell(
                    onTap: () => setState(() => date = day),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 68),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i],
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? Colors.white
                                  : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (selected || done > 0)
                            DesignIcon(
                              'treatment-day-${selected
                                  ? 'selected'
                                  : skipped || done < ds.length
                                  ? 'partial'
                                  : 'done'}',
                              size: 6,
                            )
                          else
                            const SizedBox(width: 6, height: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (!state.settings.intakeSchedule)
        TreatmentBanner(
          'Расписание на паузе',
          'История приёма сохранена',
          action: 'Настроить расписание',
          onAction: () => context.go('/settings'),
        ),
      if (slots.isNotEmpty && marked == slots.length) ...[
        TreatmentBanner(
          'Все приёмы на ${date == treatmentDay(now) ? 'сегодня' : 'этот день'} отмечены',
          'Отметки сохранены в истории курсов',
          success: true,
        ),
        const SizedBox(height: 16),
      ],
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 4,
        children: [
          InkWell(
            onTap: () async {
              final chosen = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(now.year + 10),
              );
              if (chosen != null && mounted) {
                setState(() => date = chosen);
              }
            },
            child: Text(
              '${date == treatmentDay(now) ? 'Сегодня, ' : ''}${treatmentDate(date)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$marked из ${slots.length} приёмов',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      if (slots.isEmpty && state.settings.intakeSchedule)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: TreatmentCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('На этот день приёмов нет'),
                  const SizedBox(height: 12),
                  TreatmentButton(
                    'Добавить курс',
                    onPressed: () => context.push('/treatment/new'),
                  ),
                ],
              ),
            ),
          ),
        ),
      for (final (label, start, end) in [
        ('Утро', 0, 12),
        ('День', 12, 18),
        ('Вечер', 18, 24),
      ])
        if (slots.any(
          (s) => s.reminder.hour >= start && s.reminder.hour < end,
        )) ...[
          TreatmentSection(label),
          for (final s in slots.where(
            (s) => s.reminder.hour >= start && s.reminder.hour < end,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: s == current && !future
                  ? _nowCard(s)
                  : IntakeRow(
                      intake: s,
                      onTap: future
                          ? null
                          : () => showIntakeAction(context, ref, s),
                    ),
            ),
        ],
    ];
  }

  Widget _nowCard(TreatmentIntake s) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border.all(
        color: Theme.of(context).colorScheme.primary,
        width: 2,
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '${s.record?.status == IntakeStatus.deferred ? 'Отложено до' : 'Сейчас ·'} ${timeText(s.dueAt)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            TreatmentDrugIcon(s.medicine, large: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicineTitle(s.medicine),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${s.reminder.dose}${s.reminder.condition.isEmpty ? '' : ' · ${s.reminder.condition}'}',
                  ),
                  if (s.reminder.hint.isNotEmpty)
                    Text(
                      s.reminder.hint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TreatmentButton(
          'Принял',
          onPressed: () => treatmentAction(
            context,
            () => ref
                .read(appControllerProvider.notifier)
                .recordIntake(
                  s.reminder.id,
                  IntakeStatus.taken,
                  scheduledDate: s.date,
                ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final defer = TreatmentButton(
              'Отложить',
              secondary: true,
              onPressed: () => showIntakeAction(context, ref, s, mode: 'defer'),
            );
            final skip = TreatmentButton(
              'Пропустить',
              secondary: true,
              onPressed: () => showIntakeAction(context, ref, s, mode: 'skip'),
            );
            if (constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(16) > 19) {
              return Column(children: [defer, const SizedBox(height: 8), skip]);
            }
            return Row(
              children: [
                Expanded(child: defer),
                const SizedBox(width: 8),
                Expanded(child: skip),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class IntakeRow extends StatelessWidget {
  const IntakeRow({
    required this.intake,
    this.onTap,
    this.history = false,
    super.key,
  });
  final TreatmentIntake intake;
  final VoidCallback? onTap;
  final bool history;
  @override
  Widget build(BuildContext context) {
    final s = intake;
    final r = s.record;
    final taken = r?.status == IntakeStatus.taken;
    final status = r == null
        ? (!s.plannedAt.isAfter(DateTime.now())
              ? 'Не отмечено · ${s.reminder.timeLabel}'
              : s.reminder.timeLabel)
        : switch (r.status) {
            IntakeStatus.taken => 'Принято в ${timeText(r.occurredAt)}',
            IntakeStatus.skipped =>
              'Пропущено${r.reason.isEmpty ? '' : ': ${r.reason}'}',
            IntakeStatus.deferred =>
              'Отложено до ${timeText(r.deferredUntil!)}',
          };
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              TreatmentDrugIcon(s.medicine),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicineTitle(s.medicine),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${history ? '${s.reminder.timeLabel} · ' : ''}${s.reminder.dose}${s.reminder.condition.isEmpty ? '' : ' · ${s.reminder.condition}'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: taken
                            ? const Color(0xFF00BC00)
                            : r != null
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DesignIcon(
                taken ? 'treatment-okay-18' : 'treatment-check',
                size: taken ? 18 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
