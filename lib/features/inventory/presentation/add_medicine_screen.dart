import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/presentation/drug_name_field.dart';
import 'package:aptechka/features/inventory/presentation/widgets/drug_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({this.initialEntry, this.catalogGtin, super.key});

  final DrugCatalogEntry? initialEntry;
  final String? catalogGtin;

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _activeIngredient = TextEditingController();
  final _dosage = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _location = TextEditingController();
  final _afterOpeningDays = TextEditingController();
  final _reminderDose = TextEditingController(text: '1 таблетка');
  DrugCatalogEntry? _selectedEntry;

  String _form = 'Таблетки';
  String _unit = 'таблеток';
  DateTime? _expiryDate;
  DateTime? _openedAt;
  String? _gtin;
  bool _createReminder = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _saving = false;
  bool _scanning = false;
  int _catalogRevision = 0;

  bool get _selectedVariantMatches {
    final entry = _selectedEntry;
    return entry != null &&
        entry.displayName == _name.text &&
        entry.displayIngredient == _activeIngredient.text &&
        entry.form == _form &&
        entry.dosage == _dosage.text &&
        entry.unit == _unit;
  }

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    if (entry != null) {
      _fillEntry(entry);
    } else if (widget.catalogGtin != null) {
      _restoreCatalogSelection();
    }
  }

  void _fillEntry(DrugCatalogEntry entry) {
    _selectedEntry = entry;
    _gtin = null;
    _name.text = entry.displayName;
    _activeIngredient.text = entry.displayIngredient;
    _form = entry.form;
    _dosage.text = entry.dosage;
    _unit = entry.unit;
  }

  Future<void> _restoreCatalogSelection() async {
    final revision = _catalogRevision;
    try {
      final entry = await ref
          .read(drugCatalogServiceProvider)
          .findByGtin(widget.catalogGtin!);
      if (!mounted || revision != _catalogRevision) return;
      if (entry != null) {
        setState(() => _fillEntry(entry));
        return;
      }
    } catch (_) {
      if (!mounted || revision != _catalogRevision) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Не удалось загрузить выбранный препарат. Выберите его снова или заполните поля вручную.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _activeIngredient.dispose();
    _dosage.dispose();
    _quantity.dispose();
    _location.dispose();
    _afterOpeningDays.dispose();
    _reminderDose.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_scanning) return;
    final revision = ++_catalogRevision;
    setState(() => _scanning = true);
    try {
      final gtin = await context.push<String>('/scanner');
      if (gtin == null || !mounted) return;
      DrugCatalogEntry? entry;
      var unavailable = false;
      try {
        entry = await ref.read(drugCatalogServiceProvider).findByGtin(gtin);
      } catch (_) {
        unavailable = true;
      }
      if (!mounted || revision != _catalogRevision) return;
      setState(() {
        _gtin = gtin;
        _selectedEntry = entry;
        _name.text = entry?.displayName ?? '';
        _activeIngredient.text = entry?.displayIngredient ?? '';
        _form = entry?.form ?? 'Таблетки';
        _dosage.text = entry?.dosage ?? '';
        _unit = entry?.unit ?? 'таблеток';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unavailable
                ? 'Код считан, справочник не загрузился. Заполните характеристики вручную.'
                : entry == null
                ? 'Код считан, совпадение не найдено. Заполните характеристики вручную.'
                : 'Препарат найден: ${ref.read(drugCatalogServiceProvider).sourceLabel}.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _selectEntry(DrugCatalogEntry entry) {
    _catalogRevision++;
    setState(() {
      // A name match does not identify the physical package's barcode.
      _fillEntry(entry);
    });
  }

  void _nameChanged(String _) {
    _catalogRevision++;
    final previous = _selectedEntry;
    setState(() {
      _gtin = null;
      _selectedEntry = null;
      // Do not carry automatically filled characteristics to a different name.
      // Preserve fields the user has already corrected manually.
      if (previous != null) {
        if (_activeIngredient.text == previous.displayIngredient) {
          _activeIngredient.clear();
        }
        if (_dosage.text == previous.dosage) _dosage.clear();
        if (_form == previous.form) _form = 'Таблетки';
        if (_unit == previous.unit) _unit = 'таблеток';
      }
    });
  }

  void _characteristicChanged(String _) {
    _catalogRevision++;
    setState(() => _gtin = null);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
      helpText: 'Срок годности',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (date != null) setState(() => _expiryDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Время приёма',
    );
    if (time != null) setState(() => _reminderTime = time);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final selected = _selectedEntry;
    final matched =
        selected != null &&
        selected.displayName == _name.text &&
        selected.displayIngredient == _activeIngredient.text &&
        selected.form == _form &&
        selected.dosage == _dosage.text &&
        selected.unit == _unit;
    String? catalogValue(String? value) =>
        value == null || value.isEmpty ? null : value;
    setState(() => _saving = true);
    try {
      await ref
          .read(appControllerProvider.notifier)
          .addMedicine(
            name: matched ? selected.name : _name.text,
            activeIngredient: matched
                ? selected.activeIngredient
                : _activeIngredient.text,
            form: _form,
            dosage: _dosage.text,
            quantity: int.parse(_quantity.text),
            unit: _unit,
            expiryDate: _expiryDate,
            location: _location.text,
            openedAt: _openedAt,
            afterOpeningDays:
                _openedAt == null || _afterOpeningDays.text.trim().isEmpty
                ? null
                : int.parse(_afterOpeningDays.text),
            gtin: _gtin,
            catalogEntryId: matched ? selected.id : null,
            manufacturer: matched ? catalogValue(selected.manufacturer) : null,
            packageDescription: matched
                ? catalogValue(selected.packageDescription)
                : null,
            registrationId: matched
                ? catalogValue(selected.registrationId)
                : null,
            registrationStatus: matched
                ? catalogValue(selected.registrationStatus)
                : null,
            catalogVersion: matched
                ? catalogValue(selected.sourceVersion)
                : null,
            createReminder: _createReminder,
            reminderHour: _reminderTime.hour,
            reminderMinute: _reminderTime.minute,
            reminderDose: _reminderDose.text,
          );
      if (mounted) context.pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Заполните поле' : null;

  @override
  Widget build(BuildContext context) {
    final pharmacyName = ref
        .watch(appControllerProvider)
        .asData
        ?.value
        .selectedPharmacy
        .name;
    return Scaffold(
      appBar: AppBar(title: const Text('Новая упаковка')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  if (pharmacyName != null) ...[
                    Text(
                      'В аптечку «$pharmacyName»',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code_scanner, size: 30),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Добавить по коду',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Сканируйте Data Matrix или EAN на упаковке.',
                                ),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            onPressed: _scanning ? null : _scan,
                            tooltip: 'Открыть сканер',
                            icon: const Icon(Icons.camera_alt_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_gtin != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'GTIN с упаковки: $_gtin',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Препарат',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  DrugNameField(
                    controller: _name,
                    validator: _required,
                    onChanged: _nameChanged,
                    onSelected: _selectEntry,
                  ),
                  if (_selectedEntry != null) ...[
                    if (_selectedVariantMatches)
                      DrugPhotoPanel(gtin: _selectedEntry!.gtin),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Из справочника: ${_selectedEntry!.displayName} · ${_selectedEntry!.displayForm} · ${_selectedEntry!.dosageLabel}.${_selectedEntry!.manufacturer.isNotEmpty ? '\nПроизводитель: ${_selectedEntry!.displayManufacturer}.' : ''}${_selectedEntry!.packageDescription.isNotEmpty ? '\nУпаковка: ${_selectedEntry!.displayPackage}.' : ''}\nХарактеристики можно изменить. Сверьте их с упаковкой; количество и даты укажите отдельно.${_selectedEntry!.isInactive ? '\nВ источнике: ${_selectedEntry!.registrationStatus}.' : ''}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('drug-ingredient-input'),
                    controller: _activeIngredient,
                    maxLines: 2,
                    onChanged: _characteristicChanged,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Действующее вещество',
                      hintText: 'МНН',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const ValueKey('drug-form-input'),
                          isExpanded: true,
                          initialValue: _form,
                          decoration: const InputDecoration(labelText: 'Форма'),
                          items:
                              {
                                    'Таблетки',
                                    'Капсулы',
                                    'Раствор',
                                    'Спрей',
                                    'Мазь',
                                    'Другое',
                                    _form,
                                  }
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        readableDrugText(value),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => setState(() {
                            _form = value!;
                            _catalogRevision++;
                            _gtin = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('drug-dosage-input'),
                          controller: _dosage,
                          onChanged: _characteristicChanged,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Дозировка',
                            hintText: '200 мг',
                            helperText:
                                'Если не указана на упаковке, оставьте пустой',
                            helperMaxLines: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Упаковка',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('package-quantity-input'),
                          controller: _quantity,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final number = int.tryParse(value ?? '');
                            return number == null || number < 0
                                ? 'Введите число'
                                : null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Количество *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const ValueKey('package-unit-input'),
                          isExpanded: true,
                          initialValue: _unit,
                          decoration: const InputDecoration(
                            labelText: 'Единица',
                          ),
                          items:
                              const [
                                    'таблеток',
                                    'капсул',
                                    'ампул',
                                    'флаконов',
                                    'мл',
                                    'шт.',
                                  ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        readableDrugText(value),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => setState(() {
                            _unit = value!;
                            _catalogRevision++;
                            _gtin = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    readOnly: true,
                    onTap: _pickExpiry,
                    decoration: InputDecoration(
                      labelText: 'Срок на упаковке',
                      hintText: 'Выберите дату',
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                      helperText: _expiryDate == null
                          ? 'Если не знаете дату, оставьте поле пустым. Статус будет «неизвестен».'
                          : compactDate(_expiryDate!),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('package-location-input'),
                    controller: _location,
                    validator: _required,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Место хранения *',
                      hintText: 'Например, верхняя полка',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickOpenedAt,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _openedAt == null
                          ? 'Отметить дату вскрытия'
                          : 'Вскрыта ${compactDate(_openedAt!)}',
                    ),
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
                  const SizedBox(height: 28),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _createReminder,
                          onChanged: (value) =>
                              setState(() => _createReminder = value),
                          title: const Text(
                            'Добавить в расписание',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'В прототипе системные уведомления ещё не работают',
                          ),
                        ),
                        if (_createReminder) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _reminderDose,
                                    validator: _required,
                                    decoration: const InputDecoration(
                                      labelText: 'Доза',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: _pickTime,
                                  icon: const Icon(Icons.schedule),
                                  label: Text(_reminderTime.format(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Сохраняем…' : 'Добавить упаковку'),
          ),
        ),
      ),
    );
  }
}
