import 'package:aptechka/core/theme/app_colors.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';

class MedicineCard extends StatelessWidget {
  const MedicineCard({required this.medicine, required this.onTap, super.key});

  final Medicine medicine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = medicine.statusAt(DateTime.now());
    final style = _StatusStyle.from(status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  medicine.form.toLowerCase().contains('раствор')
                      ? Icons.water_drop_outlined
                      : Icons.medication_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            medicine.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${medicine.form} · ${medicine.dosage}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusPill(
                          label: style.label,
                          color: style.color,
                          background: style.background,
                        ),
                        Text(
                          '${medicine.quantity} ${medicine.unit}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.color, this.background);

  final String label;
  final Color color;
  final Color background;

  factory _StatusStyle.from(MedicineStatus status) {
    return switch (status) {
      MedicineStatus.expired => const _StatusStyle(
        'Просрочен',
        AppColors.danger,
        AppColors.dangerSoft,
      ),
      MedicineStatus.expiringSoon => const _StatusStyle(
        'Скоро истечёт',
        AppColors.warning,
        AppColors.warningSoft,
      ),
      MedicineStatus.okay => const _StatusStyle(
        'Годен',
        AppColors.success,
        AppColors.successSoft,
      ),
    };
  }
}

class ExpiryCaption extends StatelessWidget {
  const ExpiryCaption({required this.medicine, super.key});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    return Text('Годен до ${compactDate(medicine.expiryDate)}');
  }
}
