import 'package:aptechka/core/theme/app_colors.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Приём лекарств')),
      body: SafeArea(
        top: false,
        child: AsyncValueView(
          value: appState,
          data: (state) => _ReminderContent(state: state),
        ),
      ),
    );
  }
}

class _ReminderContent extends ConsumerWidget {
  const _ReminderContent({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.reminders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Нет напоминаний',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Расписание можно добавить при создании препарата.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final reminders = [...state.reminders]
      ..sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Отмечайте факт приёма. На этом этапе расписание сохраняется локально; системные уведомления будут подключены следующими.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Сегодня', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...reminders.map((reminder) {
              final medicine = state.medicines
                  .where((item) => item.id == reminder.medicineId)
                  .firstOrNull;
              if (medicine == null) return const SizedBox.shrink();
              final status = _todayStatus(state, reminder.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: status == IntakeStatus.taken
                                    ? AppColors.successSoft
                                    : Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                reminder.timeLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    medicine.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${reminder.dose} · ${medicine.dosage}'),
                                  if (status != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      status == IntakeStatus.taken
                                          ? 'Принято'
                                          : 'Пропущено',
                                      style: TextStyle(
                                        color: status == IntakeStatus.taken
                                            ? AppColors.success
                                            : AppColors.warning,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (status == null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => ref
                                      .read(appControllerProvider.notifier)
                                      .recordIntake(
                                        reminder.id,
                                        IntakeStatus.skipped,
                                      ),
                                  child: const Text('Пропустить'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => ref
                                      .read(appControllerProvider.notifier)
                                      .recordIntake(
                                        reminder.id,
                                        IntakeStatus.taken,
                                      ),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Принял'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IntakeStatus? _todayStatus(AppState state, String reminderId) {
    final now = DateTime.now();
    for (final record in state.intakeRecords.reversed) {
      if (record.reminderId == reminderId &&
          record.occurredAt.year == now.year &&
          record.occurredAt.month == now.month &&
          record.occurredAt.day == now.day) {
        return record.status;
      }
    }
    return null;
  }
}
