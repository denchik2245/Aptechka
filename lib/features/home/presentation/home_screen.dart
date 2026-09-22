import 'package:aptechka/core/theme/app_colors.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/presentation/widgets/medicine_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: AsyncValueView(
          value: appState,
          data: (state) => _HomeContent(state: state),
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final expired = state.medicines
        .where((item) => item.statusAt(now) == MedicineStatus.expired)
        .length;
    final expiring = state.medicines
        .where((item) => item.statusAt(now) == MedicineStatus.expiringSoon)
        .length;
    final attention =
        state.medicines
            .where((item) => item.statusAt(now) != MedicineStatus.okay)
            .toList()
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добрый день',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Домашняя аптечка',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Добавить препарат',
                  onPressed: () => context.push('/medicine/new'),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _OverviewCard(
              total: state.medicines.length,
              alerts: expired + expiring,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.warning_amber_rounded,
                    value: '$expiring',
                    label: 'Скоро истекут',
                    color: AppColors.warning,
                    background: AppColors.warningSoft,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.delete_outline,
                    value: '$expired',
                    label: 'Просрочены',
                    color: AppColors.danger,
                    background: AppColors.dangerSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Сегодня принять',
              action: 'Все напоминания',
              onTap: () => context.go('/reminders'),
            ),
            const SizedBox(height: 12),
            if (state.reminders.isEmpty)
              const _EmptyCard(
                icon: Icons.notifications_none,
                title: 'Напоминаний пока нет',
                subtitle: 'Добавьте расписание при создании препарата.',
              )
            else
              ...state.reminders.take(2).map((reminder) {
                final medicine = state.medicines
                    .where((item) => item.id == reminder.medicineId)
                    .firstOrNull;
                if (medicine == null) return const SizedBox.shrink();
                final record = _todayRecord(state.intakeRecords, reminder.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DoseCard(
                    name: medicine.name,
                    dosage: '${reminder.dose} · ${reminder.timeLabel}',
                    status: record?.status,
                    onTaken: () => ref
                        .read(appControllerProvider.notifier)
                        .recordIntake(reminder.id, IntakeStatus.taken),
                  ),
                );
              }),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'Требуют внимания',
              action: 'Открыть аптечку',
              onTap: () => context.go('/inventory'),
            ),
            const SizedBox(height: 12),
            if (attention.isEmpty)
              const _EmptyCard(
                icon: Icons.verified_outlined,
                title: 'Всё в порядке',
                subtitle: 'В ближайшие 30 дней ничего не истекает.',
              )
            else
              ...attention
                  .take(3)
                  .map(
                    (medicine) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MedicineCard(
                        medicine: medicine,
                        onTap: () => context.push('/medicine/${medicine.id}'),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  IntakeRecord? _todayRecord(List<IntakeRecord> records, String reminderId) {
    final now = DateTime.now();
    for (final record in records.reversed) {
      if (record.reminderId == reminderId &&
          record.occurredAt.year == now.year &&
          record.occurredAt.month == now.month &&
          record.occurredAt.day == now.day) {
        return record;
      }
    }
    return null;
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.total, required this.alerts});

  final int total;
  final int alerts;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Всего препаратов: $total. Требуют внимания: $alerts.',
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.sageDark,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Аптечка под контролем',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alerts == 0
                        ? 'Все препараты в порядке'
                        : '$alerts ${_alertWord(alerts)} требуют внимания',
                    style: const TextStyle(
                      color: Color(0xFFD6E7E1),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _alertWord(int value) => value == 1 ? 'препарат' : 'препарата';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.name,
    required this.dosage,
    required this.status,
    required this.onTaken,
  });

  final String name;
  final String dosage;
  final IntakeStatus? status;
  final VoidCallback onTaken;

  @override
  Widget build(BuildContext context) {
    final isTaken = status == IntakeStatus.taken;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isTaken
                    ? AppColors.successSoft
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isTaken ? Icons.check : Icons.schedule,
                color: isTaken ? AppColors.success : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(isTaken ? 'Принято сегодня' : dosage),
                ],
              ),
            ),
            if (!isTaken)
              FilledButton.tonal(
                onPressed: onTaken,
                child: const Text('Принял'),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
