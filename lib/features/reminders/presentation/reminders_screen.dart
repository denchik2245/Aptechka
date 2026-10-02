import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_status_badge.dart';
import 'package:go_router/go_router.dart';
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
    final reminders = state.settings.intakeSchedule
        ? state.reminders.where((item) => item.enabled).toList()
        : <MedicationReminder>[];
    reminders.sort(
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
            _AttentionSummary(state: state),
            const SizedBox(height: 24),
            Text('Сегодня', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (reminders.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.settings.intakeSchedule
                            ? 'Нет активных расписаний'
                            : 'Расписание на паузе',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.reminders.isEmpty
                            ? 'Расписание можно добавить при создании упаковки.'
                            : 'Включите расписание в настройках. История приёма сохранена.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.go('/settings'),
                        child: const Text('Настроить расписание'),
                      ),
                    ],
                  ),
                ),
              ),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                reminder.timeLabel,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
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
                                  Text(
                                    '${reminder.dose} · ${medicine.dosageLabel}',
                                  ),
                                  if (status != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      status == IntakeStatus.taken
                                          ? 'Принято'
                                          : 'Пропущено',
                                      style: TextStyle(
                                        color: status == IntakeStatus.taken
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .tertiary,
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

class _AttentionSummary extends StatelessWidget {
  const _AttentionSummary({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.settings;
    final entries = state.medicines.where((item) {
      final status = item.statusAt(
        DateTime.now(),
        warningDays: settings.expiryWarningDays,
      );
      return (settings.expiryAlerts &&
              item.quantity > 0 &&
              status != MedicineStatus.okay) ||
          (settings.stockAlerts && item.quantity <= settings.lowStockThreshold);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Проверить аптечки',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Предупреждения по всем аптечкам на этом устройстве'),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(
                !settings.expiryAlerts && !settings.stockAlerts
                    ? 'Предупреждения выключены'
                    : 'По включённым проверкам всё спокойно',
              ),
              subtitle: Text(
                !settings.expiryAlerts && !settings.stockAlerts
                    ? 'Включите нужные проверки в настройках.'
                    : 'Нет упаковок, требующих внимания.',
              ),
            ),
          ),
        ...entries.map((item) {
          final pharmacy = state.pharmacies
              .where((p) => p.id == item.pharmacyId)
              .firstOrNull;
          final status = item.statusAt(
            DateTime.now(),
            warningDays: settings.expiryWarningDays,
          );
          final reasons = <String>[
            if (settings.expiryAlerts &&
                item.quantity > 0 &&
                status != MedicineStatus.okay)
              PackageStatusBadge.labelFor(status),
            if (settings.stockAlerts &&
                item.quantity <= settings.lowStockThreshold)
              item.quantity == 0
                  ? 'Нет в наличии'
                  : 'Малый остаток: ${item.quantity} ${item.unit}',
          ];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  '${pharmacy?.name ?? ''} · ${item.location}\n${reasons.join(' · ')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/medicine/${item.id}'),
              ),
            ),
          );
        }),
      ],
    );
  }
}
