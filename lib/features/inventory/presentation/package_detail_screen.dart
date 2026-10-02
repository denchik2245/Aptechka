import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_status_badge.dart';
import 'package:aptechka/features/inventory/presentation/widgets/drug_photo.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PackageDetailScreen extends ConsumerWidget {
  const PackageDetailScreen({required this.packageId, super.key});

  final String packageId;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Medicine package,
  ) async {
    final update = await showDialog<_PackageUpdate>(
      context: context,
      builder: (context) => _EditPackageDialog(package: package),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Упаковка')),
      body: SafeArea(
        top: false,
        child: AsyncValueView(
          value: appState,
          data: (state) {
            final package = state.medicines
                .where((item) => item.id == packageId)
                .firstOrNull;
            if (package == null) {
              return const Center(child: Text('Упаковка не найдена'));
            }
            final pharmacy = state.pharmacies
                .where((item) => item.id == package.pharmacyId)
                .firstOrNull;
            final status = package.statusAt(
              DateTime.now(),
              warningDays: state.settings.expiryWarningDays,
            );
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Text(
                      pharmacy?.name ?? 'Аптечка',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      package.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${package.dosageLabel} · ${package.form}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    DrugPhotoPanel(
                      gtin: package.catalogEntryId?.startsWith('mdlp:') == true
                          ? package.catalogEntryId!.substring(5)
                          : package.gtin,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PackageStatusBadge(status: status),
                            const SizedBox(height: 14),
                            Text(
                              _statusExplanation(
                                package,
                                status,
                                state.settings.expiryWarningDays,
                              ),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FactCard(
                            label: 'ОСТАЛОСЬ',
                            value: '${package.quantity} ${package.unit}',
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FactCard(
                            label: 'ГДЕ ЛЕЖИТ',
                            value: package.location,
                            icon: Icons.place_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (package.catalogEntryId != null) ...[
                      Text(
                        'Данные справочника',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              if (package.manufacturer != null)
                                _DetailRow(
                                  label: 'Производитель',
                                  value: package.manufacturer!,
                                ),
                              if (package.packageDescription != null) ...[
                                const SizedBox(height: 16),
                                _DetailRow(
                                  label: 'Упаковка в каталоге',
                                  value: package.packageDescription!,
                                ),
                              ],
                              if (package.registrationId != null) ...[
                                const SizedBox(height: 16),
                                _DetailRow(
                                  label: 'Регистрационное удостоверение',
                                  value: package.registrationId!,
                                ),
                              ],
                              if (package.registrationStatus != null) ...[
                                const SizedBox(height: 16),
                                _DetailRow(
                                  label: 'Статус в источнике',
                                  value: package.registrationStatus!,
                                ),
                              ],
                              if (package.catalogVersion != null) ...[
                                const SizedBox(height: 16),
                                _DetailRow(
                                  label: 'Выгрузка МДЛП',
                                  value: package.catalogVersion!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Сроки этой упаковки',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            _DetailRow(
                              label: 'Срок на упаковке',
                              value: package.expiryDate == null
                                  ? 'Не указан'
                                  : compactDate(package.expiryDate!),
                            ),
                            const Divider(height: 28),
                            _DetailRow(
                              label: 'Дата вскрытия',
                              value: package.openedAt == null
                                  ? 'Не отмечена'
                                  : compactDate(package.openedAt!),
                            ),
                            const Divider(height: 28),
                            _DetailRow(
                              label: 'После вскрытия',
                              value: package.openedAt == null
                                  ? 'Не применяется'
                                  : package.afterOpeningExpiry == null
                                  ? 'Срок не внесён'
                                  : 'До ${compactDate(package.afterOpeningExpiry!)}',
                            ),
                            if (package.effectiveExpiryDate != null &&
                                !package.hasIncompleteExpiryData) ...[
                              const Divider(height: 28),
                              _DetailRow(
                                label: 'Более ранний срок',
                                value: compactDate(
                                  package.effectiveExpiryDate!,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Статус рассчитан только по внесённым датам. Он не подтверждает условия хранения или назначение препарата.',
                    ),
                    if (package.gtin != null || package.notes != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Дополнительно',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              if (package.gtin != null)
                                _DetailRow(label: 'GTIN', value: package.gtin!),
                              if (package.gtin != null && package.notes != null)
                                const Divider(height: 28),
                              if (package.notes != null)
                                _DetailRow(
                                  label: 'Заметка',
                                  value: package.notes!,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (pharmacy?.canEdit == true) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _edit(context, ref, package),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Изменить упаковку'),
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

  String _statusExplanation(
    Medicine package,
    MedicineStatus status,
    int warningDays,
  ) => switch (status) {
    MedicineStatus.expired =>
      'По одной из внесённых дат срок уже истёк. Проверьте эту упаковку.',
    MedicineStatus.expiringSoon =>
      'По внесённым датам до ближайшего срока осталось не более $warningDays дней.',
    MedicineStatus.okay => 'По внесённым датам срок не истёк.',
    MedicineStatus.unknown =>
      package.openedAt != null && package.afterOpeningDays == null
          ? 'Упаковка вскрыта, но срок после вскрытия не указан.'
          : 'Для оценки срока недостаточно внесённых данных.',
  };
}

class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          const SizedBox(height: 5),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
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
