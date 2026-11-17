import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/core/widgets/round_icon_button.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'course_detail_screen.dart';
import 'intake_actions.dart';
import 'treatment_widgets.dart';

/// The Figma lock-screen state, presented explicitly as an in-app preview.
class NotificationPreviewScreen extends ConsumerWidget {
  const NotificationPreviewScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).asData?.value;
    final now = DateTime.now();
    final slots = state == null
        ? <TreatmentIntake>[]
        : TreatmentSchedule.forDay(state, now, courseId: id);
    final intake =
        slots.where((s) => !s.marked).firstOrNull ?? slots.firstOrNull;
    final c = state?.courses.where((c) => c.id == id).firstOrNull;
    final warning = state == null || c == null ? null : stockWarning(state, c);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF799ACA), Color(0xFFB8B9C5)],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        tooltip: 'Назад',
                        icon: const DesignIcon('back'),
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/reminders'),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Предпросмотр напоминания',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1C1A32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${const ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'][now.weekday - 1]}, ${treatmentDate(now)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1C1A32),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      timeText(now),
                      style: const TextStyle(
                        color: Color(0xFF1C1A32),
                        fontSize: 88,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 72),
                  if (intake == null)
                    const TreatmentCard(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'На сегодня нет активных приёмов этого курса',
                        ),
                      ),
                    )
                  else ...[
                    _NotificationCard(
                      title: intake.marked
                          ? 'Приём отмечен'
                          : 'Пора принять ${intake.medicine.name}',
                      message:
                          '${intake.reminder.dose} ${intake.medicine.dosage}${intake.reminder.condition.isEmpty ? '' : ' · ${intake.reminder.condition}'}. ${intake.reminder.hint}',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              intake.marked ? 'Принято' : 'Принял',
                              style: const TextStyle(
                                color: Color(0xFF0075FF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: intake.marked
                                ? null
                                : () => treatmentAction(
                                    context,
                                    () => ref
                                        .read(appControllerProvider.notifier)
                                        .recordIntake(
                                          intake.reminder.id,
                                          IntakeStatus.taken,
                                          scheduledDate: intake.date,
                                        ),
                                  ),
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text(
                              'Отложить на 15 минут',
                              style: TextStyle(
                                color: Color(0xFF1C1A32),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: intake.marked
                                ? null
                                : () => treatmentAction(
                                    context,
                                    () => ref
                                        .read(appControllerProvider.notifier)
                                        .recordIntake(
                                          intake.reminder.id,
                                          IntakeStatus.deferred,
                                          scheduledDate: intake.date,
                                          deferredUntil: DateTime.now().add(
                                            const Duration(minutes: 15),
                                          ),
                                        ),
                                  ),
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text(
                              'Пропустить',
                              style: TextStyle(
                                color: Color(0xFFD62D30),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: intake.marked
                                ? null
                                : () => showIntakeAction(
                                    context,
                                    ref,
                                    intake,
                                    mode: 'skip',
                                  ),
                          ),
                        ],
                      ),
                    ),
                    if (intake.record?.status == IntakeStatus.deferred)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Отложено до ${timeText(intake.record!.deferredUntil!)}',
                          style: const TextStyle(color: Color(0xFF1C1A32)),
                        ),
                      ),
                  ],
                  if (warning != null) ...[
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: .75,
                      child: _NotificationCard(
                        title: 'Проверьте запас лекарства',
                        message: warning,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.title, required this.message});
  final String title, message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x141C1A33),
          blurRadius: 12,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0075FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 18,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              Container(
                width: 6,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Аптечка',
                    style: TextStyle(color: Color(0xFF66647C), fontSize: 12),
                  ),
                  Text(
                    'сейчас',
                    style: TextStyle(color: Color(0xFF66647C), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1C1A32),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: const TextStyle(color: Color(0xFF66647C), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
