import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';

class PackageStatusBadge extends StatelessWidget {
  const PackageStatusBadge({
    required this.status,
    this.compact = false,
    super.key,
  });

  final MedicineStatus status;
  final bool compact;

  static String labelFor(MedicineStatus status) => switch (status) {
    MedicineStatus.okay => 'Срок не истёк',
    MedicineStatus.expiringSoon => 'Срок скоро истечёт',
    MedicineStatus.expired => 'Срок истёк',
    MedicineStatus.unknown => 'Данных о сроке недостаточно',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, foreground, background) = switch (status) {
      MedicineStatus.okay => (
        Icons.check_circle_outline,
        scheme.primary,
        scheme.primaryContainer,
      ),
      MedicineStatus.expiringSoon => (
        Icons.schedule,
        scheme.onTertiaryContainer,
        scheme.tertiaryContainer,
      ),
      MedicineStatus.expired => (
        Icons.error_outline,
        scheme.onErrorContainer,
        scheme.errorContainer,
      ),
      MedicineStatus.unknown => (
        Icons.help_outline,
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              labelFor(status),
              style: TextStyle(
                color: foreground,
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
