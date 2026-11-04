import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/core/theme/app_colors.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
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
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Мои аптечки',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: 32,
                                height: 44 / 32,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w800,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.light
                                    ? const Color(0xFF1A1A1A)
                                    : AppColors.darkInk,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: () => _createPharmacy(context, ref),
                        tooltip: 'Создать аптечку',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          fixedSize: const Size(44, 44),
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.all(10),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        icon: const DesignIcon('add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  ...state.pharmacies.map(
                    (pharmacy) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    final theme = Theme.of(context);
    int count(MedicineStatus status) => packages
        .where(
          (item) =>
              item.statusAt(
                DateTime.now(),
                warningDays: state.settings.expiryWarningDays,
              ) ==
              status,
        )
        .length;
    final expired = count(MedicineStatus.expired);
    final expiring = count(MedicineStatus.expiringSoon);
    final unknown = count(MedicineStatus.unknown);
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );
    final valueStyle = theme.textTheme.titleSmall?.copyWith(
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
    final statuses = <(String, String)>[
      if (expired > 0)
        (
          'status-expired',
          '$expired ${expired == 1 ? 'просрочена' : 'просрочены'}',
        ),
      if (expiring > 0)
        (
          'status-warning',
          expired > 0
              ? '+$expiring'
              : '$expiring скоро ${expiring == 1 ? 'истечёт' : 'истекут'}',
        ),
      if (expired == 0 && expiring == 0)
        unknown > 0
            ? ('status-warning', 'Проверьте сроки')
            : (
                'status-okay',
                packages.isEmpty ? 'Нет препаратов' : 'Все в норме',
              ),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 132),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DesignIcon(
                      pharmacy.isShared ? 'forest' : 'home',
                      size: 28,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pharmacy.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 24,
                          height: 1.2,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: DesignIcon(
                          'chevron',
                          width: 7,
                          height: 12,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Сроки годности', style: captionStyle),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              for (final (icon, text) in statuses)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    DesignIcon(icon, size: 18),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(text, style: valueStyle),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Элементов', style: captionStyle),
                        const SizedBox(height: 3),
                        Text('${packages.length}', style: valueStyle),
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
