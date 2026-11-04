import 'package:aptechka/core/theme/app_colors.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/data/drug_photo_catalog.dart';
import 'package:aptechka/features/inventory/domain/medicine_group.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MedicineThumbnail extends ConsumerWidget {
  const MedicineThumbnail({
    required this.medicine,
    this.width = 90,
    this.height,
    super.key,
  });
  final Medicine medicine;
  final double width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gtin = medicine.catalogEntryId?.startsWith('mdlp:') == true
        ? medicine.catalogEntryId!.substring(5)
        : medicine.gtin;
    final photo = ref.watch(drugPhotoProvider(gtin)).asData?.value;
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: DesignIcon('medicine', color: scheme.onSurfaceVariant),
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: photo == null
            ? placeholder()
            : ColoredBox(
                color: Colors.white,
                child: Image.asset(
                  photo.asset,
                  fit: BoxFit.contain,
                  semanticLabel:
                      'Фото упаковки ${readableDrugName(medicine.name)}',
                  errorBuilder: (_, _, _) => placeholder(),
                ),
              ),
      ),
    );
  }
}

class MedicineListCard extends StatelessWidget {
  const MedicineListCard({
    required this.group,
    required this.warningDays,
    required this.onTap,
    this.pharmacyName,
    super.key,
  });
  final MedicineGroup group;
  final int warningDays;
  final VoidCallback onTap;
  final String? pharmacyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final packages = [...group.packages]
      ..sort((a, b) {
        int priority(Medicine m) =>
            switch (m.statusAt(DateTime.now(), warningDays: warningDays)) {
              MedicineStatus.expired => 3,
              MedicineStatus.unknown => 2,
              MedicineStatus.expiringSoon => 1,
              MedicineStatus.okay => 0,
            };
        final byStatus = priority(b).compareTo(priority(a));
        if (byStatus != 0) return byStatus;
        return (a.effectiveExpiryDate ?? DateTime(9999)).compareTo(
          b.effectiveExpiryDate ?? DateTime(9999),
        );
      });
    final medicine = packages.first;
    final status = medicine.statusAt(DateTime.now(), warningDays: warningDays);
    final expiry = medicine.effectiveExpiryDate;
    final expiryText = switch (status) {
      MedicineStatus.expired =>
        expiry == null
            ? 'Срок истёк'
            : 'Срок истёк ${russianCount(DateUtils.dateOnly(DateTime.now()).difference(DateUtils.dateOnly(expiry)).inDays, 'день', 'дня', 'дней')} назад',
      MedicineStatus.unknown => 'Срок не указан полностью',
      _ =>
        expiry == null ? 'Срок не указан' : 'Годен до: ${compactDate(expiry)}',
    };
    final statusIcon = switch (status) {
      MedicineStatus.expired => 'status-expired',
      MedicineStatus.expiringSoon => 'status-warning',
      _ => null,
    };
    final statusColor = switch (status) {
      MedicineStatus.expired => theme.colorScheme.error,
      MedicineStatus.expiringSoon => AppColors.warning,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 140),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MedicineThumbnail(medicine: medicine),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  readableDrugName(group.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    height: 25 / 18,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              if (medicine.dosage.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 80,
                                  ),
                                  child: Text(
                                    medicine.dosageLabel,
                                    textAlign: TextAlign.end,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          height: 16 / 12,
                                          letterSpacing: 0,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (medicine.openedAt != null) ...[
                            Text(
                              'Вскрыто: ${compactDate(medicine.openedAt!)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 19 / 14,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 3),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (statusIcon != null) ...[
                                DesignIcon(statusIcon, size: 18),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  expiryText,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: statusColor,
                                    height: 19 / 14,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (pharmacyName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              pharmacyName!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          const Spacer(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Flexible(
                                child: _CardChip(
                                  label:
                                      group.packages
                                              .map((m) => m.location)
                                              .toSet()
                                              .length >
                                          1
                                      ? russianCount(
                                          group.packages
                                              .map((m) => m.location)
                                              .toSet()
                                              .length,
                                          'место',
                                          'места',
                                          'мест',
                                        )
                                      : group.locationSummary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: _CardChip(
                                  label: packages.length == 1
                                      ? '${medicine.quantity} ${medicine.unit}'
                                      : russianCount(
                                          packages.length,
                                          'упаковка',
                                          'упаковки',
                                          'упаковок',
                                        ),
                                  icon: 'pills-small',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip({required this.label, this.icon});
  final String label;
  final String? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          DesignIcon(icon!, size: 16),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(height: 16 / 12, letterSpacing: 0),
          ),
        ),
      ],
    ),
  );
}
