import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_status_badge.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MedicineGroupScreen extends ConsumerWidget {
  const MedicineGroupScreen({required this.packageId, super.key});

  final String packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Упаковки препарата')),
      body: SafeArea(
        top: false,
        child: AsyncValueView(
          value: appState,
          data: (state) {
            final representative = state.medicines
                .where((item) => item.id == packageId)
                .firstOrNull;
            if (representative == null) {
              return const Center(child: Text('Препарат не найден'));
            }
            final packages =
                state.medicines
                    .where(
                      (item) =>
                          item.pharmacyId == representative.pharmacyId &&
                          item.groupKey == representative.groupKey,
                    )
                    .toList()
                  ..sort((a, b) {
                    int priority(Medicine item) {
                      if (item.quantity == 0) return 4;
                      return switch (item.statusAt(
                        DateTime.now(),
                        warningDays: state.settings.expiryWarningDays,
                      )) {
                        MedicineStatus.okay => 0,
                        MedicineStatus.expiringSoon => 1,
                        MedicineStatus.unknown => 2,
                        MedicineStatus.expired => 3,
                      };
                    }

                    final byStatus = priority(a).compareTo(priority(b));
                    if (byStatus != 0) return byStatus;
                    final aDate = a.effectiveExpiryDate;
                    final bDate = b.effectiveExpiryDate;
                    if (aDate == null) return 1;
                    if (bDate == null) return -1;
                    return aDate.compareTo(bDate);
                  });
            final pharmacy = state.pharmacies
                .where((item) => item.id == representative.pharmacyId)
                .firstOrNull;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Text(
                      pharmacy?.name ?? 'Аптечка',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      readableDrugName(representative.name),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${representative.dosageLabel} · ${readableDrugText(representative.form)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      russianCount(
                        packages.length,
                        'упаковка',
                        'упаковки',
                        'упаковок',
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Количество и срок показаны отдельно для каждой упаковки. Срок по датам не подтверждает условия хранения.',
                    ),
                    const SizedBox(height: 16),
                    ...packages.map(
                      (package) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PackageCard(
                          package: package,
                          warningDays: state.settings.expiryWarningDays,
                          onTap: () => context.push('/medicine/${package.id}'),
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

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.onTap,
    required this.warningDays,
  });

  final Medicine package;
  final int warningDays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = package.statusAt(DateTime.now(), warningDays: warningDays);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${package.quantity} ${package.unit}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(package.location)),
                ],
              ),
              const SizedBox(height: 12),
              PackageStatusBadge(status: status, compact: true),
              const SizedBox(height: 10),
              Text(
                package.expiryDate == null
                    ? 'Срок на упаковке не указан'
                    : 'Срок на упаковке: ${compactDate(package.expiryDate!)}',
              ),
              if (package.openedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  package.afterOpeningExpiry == null
                      ? 'Вскрыта ${compactDate(package.openedAt!)} · срок после вскрытия не указан'
                      : 'После вскрытия: до ${compactDate(package.afterOpeningExpiry!)}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
