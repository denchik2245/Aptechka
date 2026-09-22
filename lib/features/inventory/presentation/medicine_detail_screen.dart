import 'package:aptechka/core/theme/app_colors.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MedicineDetailScreen extends ConsumerWidget {
  const MedicineDetailScreen({required this.medicineId, super.key});

  final String medicineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Карточка препарата')),
      body: SafeArea(
        top: false,
        child: AsyncValueView(
          value: appState,
          data: (state) {
            final medicine = state.medicines
                .where((item) => item.id == medicineId)
                .firstOrNull;
            if (medicine == null) {
              return const Center(child: Text('Препарат не найден'));
            }
            final reminder = state.reminders
                .where((item) => item.medicineId == medicineId)
                .firstOrNull;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.medication_outlined,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicine.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 5),
                              Text('${medicine.form} · ${medicine.dosage}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _ExpiryPanel(medicine: medicine),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            _DetailRow(
                              label: 'Действующее вещество',
                              value: medicine.activeIngredient ?? 'Не указано',
                            ),
                            const Divider(height: 28),
                            _DetailRow(
                              label: 'Остаток',
                              value: '${medicine.quantity} ${medicine.unit}',
                            ),
                            const Divider(height: 28),
                            _DetailRow(
                              label: 'Место хранения',
                              value: medicine.location,
                            ),
                            if (medicine.gtin != null) ...[
                              const Divider(height: 28),
                              _DetailRow(label: 'GTIN', value: medicine.gtin!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        minTileHeight: 76,
                        leading: const Icon(Icons.schedule),
                        title: const Text('Расписание приёма'),
                        subtitle: Text(
                          reminder == null
                              ? 'Не настроено'
                              : '${reminder.timeLabel} · ${reminder.dose}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Используйте препарат только по официальной инструкции и назначению специалиста. Приложение не назначает лечение.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExpiryPanel extends StatelessWidget {
  const _ExpiryPanel({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final status = medicine.statusAt(DateTime.now());
    final (label, caption, color, background) = switch (status) {
      MedicineStatus.expired => (
        'Просрочен',
        'Не используйте препарат. Утилизируйте по правилам.',
        AppColors.danger,
        AppColors.dangerSoft,
      ),
      MedicineStatus.expiringSoon => (
        'Срок скоро истечёт',
        'Годен до ${compactDate(medicine.expiryDate)}',
        AppColors.warning,
        AppColors.warningSoft,
      ),
      MedicineStatus.okay => (
        'Срок годности в порядке',
        'Годен до ${compactDate(medicine.expiryDate)}',
        AppColors.success,
        AppColors.successSoft,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status == MedicineStatus.expired
                ? Icons.error_outline
                : Icons.event_available_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(caption, style: TextStyle(color: color, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
