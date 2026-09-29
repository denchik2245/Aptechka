import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

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
  final DrugCatalogService _catalog = const DemoDrugCatalogService();

  String _form = 'Таблетки';
  String _unit = 'таблеток';
  DateTime? _expiryDate;
  DateTime? _openedAt;
  String? _gtin;
  bool _createReminder = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _saving = false;

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
    final gtin = await context.push<String>('/scanner');
    if (gtin == null || !mounted) return;
    final entry = await _catalog.findByGtin(gtin);
    if (!mounted) return;
    setState(() {
      _gtin = gtin;
      if (entry != null) {
        _name.text = entry.name;
        _activeIngredient.text = entry.activeIngredient;
        _form = entry.form;
        _dosage.text = entry.dosage;
        _unit = entry.unit;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entry == null
              ? 'Код считан. Заполните характеристики препарата.'
              : 'Препарат найден в демонстрационном справочнике.',
        ),
      ),
    );
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
    setState(() => _saving = true);
    try {
      await ref
          .read(appControllerProvider.notifier)
          .addMedicine(
            name: _name.text,
            activeIngredient: _activeIngredient.text,
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
            createReminder: _createReminder,
            reminderHour: _reminderTime.hour,
            reminderMinute: _reminderTime.minute,
            reminderDose: _reminderDose.text,
          );
      if (mounted) context.pop();
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
                            onPressed: _scan,
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
                      'Считан GTIN: $_gtin',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Препарат',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    validator: _required,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Название *',
                      hintText: 'Например, Ибупрофен',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _activeIngredient,
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
                          initialValue: _form,
                          decoration: const InputDecoration(labelText: 'Форма'),
                          items:
                              const [
                                    'Таблетки',
                                    'Капсулы',
                                    'Раствор',
                                    'Спрей',
                                    'Мазь',
                                    'Другое',
                                  ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => setState(() => _form = value!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _dosage,
                          validator: _required,
                          decoration: const InputDecoration(
                            labelText: 'Дозировка *',
                            hintText: '200 мг',
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
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => setState(() => _unit = value!),
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
