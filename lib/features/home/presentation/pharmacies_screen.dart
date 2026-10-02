import 'package:aptechka/features/accounts/application/account_controller.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/medicine_group.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PharmaciesScreen extends ConsumerWidget {
  const PharmaciesScreen({super.key});

  Future<void> _createPharmacy(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новая аптечка'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Название'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;
    await ref.read(appControllerProvider.notifier).createPharmacy(name);
    if (context.mounted) context.go('/inventory');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: AsyncValueView(
          value: appState,
          data: (state) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                children: [
                  Text(
                    'ВАШЕ ПРОСТРАНСТВО',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Мои аптечки',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/account'),
                        tooltip: 'Аккаунт',
                        icon: const Icon(Icons.account_circle_outlined),
                      ),
                    ],
                  ),
                  Text(
                    ref
                            .watch(localAccountsProvider)
                            .asData
                            ?.value
                            .active
                            ?.name ??
                        'Без аккаунта · гостевые записи',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Выберите аптечку, чтобы увидеть лекарства и конкретные упаковки.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  _PrototypeNotice(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Аптечки',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${state.pharmacies.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...state.pharmacies.map(
                    (pharmacy) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PharmacyCard(
                        pharmacy: pharmacy,
                        state: state,
                        onTap: () async {
                          await ref
                              .read(appControllerProvider.notifier)
                              .selectPharmacy(pharmacy.id);
                          if (context.mounted) context.go('/inventory');
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _createPharmacy(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Создать аптечку'),
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

class _PrototypeNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.science_outlined),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Прототип с примерными данными. Изменения хранятся только на этом устройстве; настоящий вход и семейная синхронизация пока не подключены.',
          ),
        ),
      ],
    ),
  );
}

class _PharmacyCard extends StatelessWidget {
  const _PharmacyCard({
    required this.pharmacy,
    required this.state,
    required this.onTap,
  });

  final Pharmacy pharmacy;
  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final packages = state.medicinesIn(pharmacy.id);
    final groups = groupMedicines(packages);
    final attention = packages
        .where(
          (item) =>
              item.statusAt(
                DateTime.now(),
                warningDays: state.settings.expiryWarningDays,
              ) !=
              MedicineStatus.okay,
        )
        .length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      pharmacy.isShared
                          ? Icons.group_outlined
                          : Icons.home_outlined,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pharmacy.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          pharmacy.isShared
                              ? 'Пример общей · владелец: ${pharmacy.ownerLabel}'
                              : 'Личная аптечка',
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 18),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountChip(
                    icon: Icons.medication_outlined,
                    text: russianCount(
                      groups.length,
                      'препарат',
                      'препарата',
                      'препаратов',
                    ),
                  ),
                  _CountChip(
                    icon: Icons.inventory_2_outlined,
                    text: russianCount(
                      packages.length,
                      'упаковка',
                      'упаковки',
                      'упаковок',
                    ),
                  ),
                  if (attention > 0)
                    _CountChip(
                      icon: Icons.info_outline,
                      text:
                          '${russianCount(attention, 'упаковка', 'упаковки', 'упаковок')} ${attention == 1 ? 'требует' : 'требуют'} проверки',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: Theme.of(context).textTheme.labelMedium),
        ),
      ],
    ),
  );
}
