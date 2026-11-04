import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/presentation/widgets/medicine_list_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PackageDetailScreen extends ConsumerStatefulWidget {
  const PackageDetailScreen({required this.packageId, super.key});
  final String packageId;
  @override
  ConsumerState<PackageDetailScreen> createState() =>
      _PackageDetailScreenState();
}

class _PackageDetailScreenState extends ConsumerState<PackageDetailScreen> {
  bool _saving = false;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Medicine package,
  ) async {
    final update = await showDialog<_PackageUpdate>(
      context: context,
      builder: (_) => _EditPackageDialog(package: package),
    );
    if (update == null) return;
    await ref
        .read(appControllerProvider.notifier)
        .updatePackage(
          medicineId: package.id,
          quantity: update.quantity,
          location: update.location,
          expiryDate: update.expiryDate,
          openedAt: update.openedAt,
          afterOpeningDays: update.afterOpeningDays,
        );
  }

  Future<void> _changeQuantity(Medicine package, int delta) async {
    if (_saving || package.quantity + delta < 0) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(appControllerProvider.notifier)
          .updatePackage(
            medicineId: package.id,
            quantity: package.quantity + delta,
            location: package.location,
            expiryDate: package.expiryDate,
            openedAt: package.openedAt,
            afterOpeningDays: package.afterOpeningDays,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить остаток. Повторите попытку.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Medicine package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Убрать из аптечки?'),
        content: Text(
          '«${readableDrugName(package.name)}»: эта упаковка, её расписание и история приёма будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Убрать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(appControllerProvider.notifier).removePackage(package.id);
      if (mounted) context.go('/inventory');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось удалить упаковку. Повторите попытку.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final loadedPackage = appState.asData?.value.medicines
        .where((m) => m.id == widget.packageId)
        .firstOrNull;
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          loadedPackage == null
              ? 'Лекарство'
              : readableDrugName(loadedPackage.name),
          style: theme.textTheme.titleSmall,
        ),
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: IconButton.filledTonal(
            tooltip: 'Назад',
            padding: EdgeInsets.zero,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/inventory'),
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainer,
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppNavigationBar(selectedIndex: 0),
      body: SafeArea(
        top: false,
        child: AsyncValueView(
          value: appState,
          data: (state) {
            final package = state.medicines
                .where((m) => m.id == widget.packageId)
                .firstOrNull;
            if (package == null) {
              return const Center(child: Text('Упаковка не найдена'));
            }
            final pharmacy = state.pharmacies
                .where((p) => p.id == package.pharmacyId)
                .firstOrNull;
            final canEdit = pharmacy?.canEdit == true;
            final status = package.statusAt(
              DateTime.now(),
              warningDays: state.settings.expiryWarningDays,
            );
            final statusIcon = switch (status) {
              MedicineStatus.okay => 'detail-okay',
              MedicineStatus.expired => 'status-expired',
              _ => 'status-warning',
            };
            final expiryText = switch (status) {
              MedicineStatus.expired => 'Срок истёк',
              MedicineStatus.unknown => 'Срок не указан полностью',
              _ => compactDate(package.effectiveExpiryDate!),
            };
            final reminders = state.reminders
                .where((r) => r.medicineId == package.id)
                .toList();
            final specs = <(String, String)>[
              ('Форма выпуска', readableDrugText(package.form)),
              ('Дозировка', package.dosageLabel),
              (
                'Действующее вещество',
                package.activeIngredient == null
                    ? 'Не указано'
                    : readableDrugText(package.activeIngredient!),
              ),
              if (package.manufacturer != null)
                ('Производитель', readableManufacturer(package.manufacturer!)),
              ('Аптечка', pharmacy?.name ?? 'Не указана'),
              (
                'Срок на упаковке',
                package.expiryDate == null
                    ? 'Не указан'
                    : compactDate(package.expiryDate!),
              ),
              (
                'Дата вскрытия',
                package.openedAt == null
                    ? 'Не отмечена'
                    : compactDate(package.openedAt!),
              ),
              if (package.openedAt != null)
                (
                  'После вскрытия',
                  package.afterOpeningExpiry == null
                      ? 'Срок не внесён'
                      : 'До ${compactDate(package.afterOpeningExpiry!)}',
                ),
              if (package.gtin != null) ('Штрихкод', package.gtin!),
              if (package.packageDescription != null)
                (
                  'Упаковка в каталоге',
                  readableDrugText(package.packageDescription!),
                ),
              if (package.registrationId != null)
                ('Регистрационное удостоверение', package.registrationId!),
              if (package.registrationStatus != null)
                ('Статус в источнике', package.registrationStatus!),
              if (package.catalogVersion != null)
                ('Выгрузка МДЛП', package.catalogVersion!),
              if (package.notes != null) ('Заметка', package.notes!),
            ];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MedicineThumbnail(
                                medicine: package,
                                width: 131,
                                height: 192,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    12,
                                    12,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${readableDrugText(package.form)} · ${package.dosageLabel}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                      ),
                                      if (package.activeIngredient != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          readableDrugText(
                                            package.activeIngredient!,
                                          ),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                      const Spacer(),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Годен до',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          DesignIcon(statusIcon, size: 18),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              expiryText,
                                              style: theme.textTheme.titleSmall,
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
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _InfoTile(
                              label: 'Где лежит',
                              value: package.location,
                              icon: 'detail-location',
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: _InfoTile(
                              label: 'Для чего',
                              value: 'Не указано',
                              icon: 'purpose',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _QuantityButton(
                              icon: 'quantity-plus',
                              label: 'Увеличить остаток',
                              onPressed: canEdit && !_saving
                                  ? () => _changeQuantity(package, 1)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Осталось',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  Text(
                                    '${package.quantity} ${package.unit}',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _QuantityButton(
                              icon: 'quantity-minus',
                              label: 'Уменьшить остаток',
                              onPressed:
                                  canEdit && !_saving && package.quantity > 0
                                  ? () => _changeQuantity(package, -1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Как применять',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reminders.isEmpty
                                  ? 'Схема приёма не добавлена. Следуйте инструкции к вашей упаковке и назначению врача.'
                                  : reminders
                                        .map(
                                          (r) => '${r.timeLabel} — ${r.dose}',
                                        )
                                        .join('\n'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Сверяйте дозировку и способ применения с инструкцией к препарату.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Другие характеристики',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          for (final (label, value) in specs) ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label, style: theme.textTheme.bodySmall),
                                  const SizedBox(height: 2),
                                  Text(
                                    value,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (canEdit) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _edit(context, ref, package),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Изменить упаковку'),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _remove(package),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            child: Text(
                              'Убрать из аптечки',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final String icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesignIcon(icon),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    ),
  );
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });
  final String icon;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: IconButton(
      tooltip: label,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Opacity(
        opacity: onPressed == null ? 0.35 : 1,
        child: DesignIcon(icon, size: 44),
      ),
    ),
  );
}

typedef _PackageUpdate = ({
  int quantity,
  String location,
  DateTime? expiryDate,
  DateTime? openedAt,
  int? afterOpeningDays,
});

class _EditPackageDialog extends StatefulWidget {
  const _EditPackageDialog({required this.package});
  final Medicine package;

  @override
  State<_EditPackageDialog> createState() => _EditPackageDialogState();
}

class _EditPackageDialogState extends State<_EditPackageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late final TextEditingController _location;
  late final TextEditingController _afterOpeningDays;
  DateTime? _expiryDate;
  DateTime? _openedAt;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(text: '${widget.package.quantity}');
    _location = TextEditingController(text: widget.package.location);
    _afterOpeningDays = TextEditingController(
      text: widget.package.afterOpeningDays?.toString() ?? '',
    );
    _openedAt = widget.package.openedAt;
    _expiryDate = widget.package.expiryDate;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _location.dispose();
    _afterOpeningDays.dispose();
    super.dispose();
  }

  Future<void> _pickOpenedAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _openedAt ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      helpText: 'Дата вскрытия упаковки',
    );
    if (date != null) setState(() => _openedAt = date);
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime(now.year + 1),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
      helpText: 'Срок на упаковке',
    );
    if (date != null) setState(() => _expiryDate = date);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop<_PackageUpdate>(context, (
      quantity: int.parse(_quantity.text),
      location: _location.text.trim(),
      expiryDate: _expiryDate,
      openedAt: _openedAt,
      afterOpeningDays: _afterOpeningDays.text.trim().isEmpty
          ? null
          : int.parse(_afterOpeningDays.text),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Изменить упаковку'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Количество'),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  return number == null || number < 0
                      ? 'Введите число от 0'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Место хранения'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Укажите место'
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickExpiryDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _expiryDate == null
                      ? 'Указать срок на упаковке'
                      : 'Срок: ${compactDate(_expiryDate!)}',
                ),
              ),
              if (_expiryDate != null)
                TextButton(
                  onPressed: () => setState(() => _expiryDate = null),
                  child: const Text('Убрать срок'),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickOpenedAt,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _openedAt == null
                      ? 'Отметить дату вскрытия'
                      : 'Вскрыта ${compactDate(_openedAt!)}',
                ),
              ),
              if (_openedAt != null)
                TextButton(
                  onPressed: () => setState(() {
                    _openedAt = null;
                    _afterOpeningDays.clear();
                  }),
                  child: const Text('Отменить отметку о вскрытии'),
                ),
              if (_openedAt != null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _afterOpeningDays,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Срок после вскрытия, дней',
                    helperText: 'Внесите срок из инструкции к упаковке',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final number = int.tryParse(value);
                    return number == null || number <= 0
                        ? 'Введите число больше 0'
                        : null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _save, child: const Text('Сохранить')),
    ],
  );
}
