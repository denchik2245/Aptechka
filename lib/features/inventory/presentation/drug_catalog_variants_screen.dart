import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:aptechka/features/inventory/presentation/widgets/drug_catalog_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DrugCatalogVariantsScreen extends ConsumerStatefulWidget {
  const DrugCatalogVariantsScreen({
    required this.groupKey,
    this.initialGroup,
    super.key,
  });
  final String groupKey;
  final DrugCatalogGroup? initialGroup;

  @override
  ConsumerState<DrugCatalogVariantsScreen> createState() =>
      _DrugCatalogVariantsScreenState();
}

class _DrugCatalogVariantsScreenState
    extends ConsumerState<DrugCatalogVariantsScreen> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  DrugCatalogGroup? _group;
  List<DrugCatalogVariant> _variants = const [];
  List<DrugCatalogVariant> _visible = const [];
  String? _form;
  String? _dosage;
  String? _manufacturer;
  bool _loading = false;
  bool _failed = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialGroup;
    if (initial != null) {
      _setGroup(initial);
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setGroup(DrugCatalogGroup group) {
    _group = group;
    _variants = group.variants;
    _filter();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final entries = await ref.read(drugCatalogServiceProvider).listAll();
      if (!mounted) return;
      final matches = entries
          .where((entry) => drugCatalogNameKey(entry.name) == widget.groupKey)
          .toList(growable: false);
      setState(() {
        if (matches.isNotEmpty) {
          _setGroup(DrugCatalogGroup(key: widget.groupKey, entries: matches));
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  List<String> get _forms =>
      _variants.map((v) => v.entry.displayForm).toSet().toList();
  List<String> get _dosages => _variants
      .where((v) => _form == null || v.entry.displayForm == _form)
      .map((v) => v.entry.dosageLabel)
      .toSet()
      .toList();
  List<String> get _manufacturers => _variants
      .where(
        (v) =>
            (_form == null || v.entry.displayForm == _form) &&
            (_dosage == null || v.entry.dosageLabel == _dosage),
      )
      .map((v) => _manufacturerLabel(v.entry))
      .toSet()
      .toList();
  String _manufacturerLabel(DrugCatalogEntry entry) =>
      entry.manufacturer.isEmpty
      ? 'Производитель не указан'
      : entry.displayManufacturer;
  bool get _hasFilters =>
      _form != null ||
      _dosage != null ||
      _manufacturer != null ||
      _query.text.isNotEmpty;

  void _filter() {
    final query = normalizeDrugQuery(_query.text);
    final words = query.isEmpty ? const <String>[] : query.split(' ');
    final barcode = RegExp(r'^(\d{8}|\d{12,14})$').hasMatch(query)
        ? query.padLeft(14, '0')
        : null;
    _visible = _variants
        .where((variant) {
          final entry = variant.entry;
          if ((_form != null && entry.displayForm != _form) ||
              (_dosage != null && entry.dosageLabel != _dosage) ||
              (_manufacturer != null &&
                  _manufacturerLabel(entry) != _manufacturer)) {
            return false;
          }
          if (barcode != null) {
            return variant.entries.any(
              (e) => e.gtin?.padLeft(14, '0') == barcode,
            );
          }
          final text = normalizeDrugQuery(
            '${entry.form} ${entry.dosage} ${entry.manufacturer} '
            '${entry.packageDescription} ${variant.package.title} ${variant.package.detail ?? ''} '
            '${entry.activeIngredient} ${entry.registrationId}',
          );
          return words.every(text.contains);
        })
        .toList(growable: false);
  }

  void _updateFilters(VoidCallback change) {
    setState(() {
      change();
      if (!_dosages.contains(_dosage)) _dosage = null;
      if (!_manufacturers.contains(_manufacturer)) _manufacturer = null;
      _filter();
    });
  }

  void _resetFilters() => _updateFilters(() {
    _form = null;
    _dosage = null;
    _manufacturer = null;
    _query.clear();
  });

  Future<void> _choose(DrugCatalogVariant variant) async {
    final entry = variant.entry;
    await _openForm(
      extra: variant.isAmbiguous ? variant : entry,
      parameters: variant.isAmbiguous
          ? {
              'candidates': variant.entries
                  .map((e) => e.gtin)
                  .whereType<String>()
                  .join(','),
            }
          : entry.gtin == null
          ? null
          : {'catalog': entry.gtin!},
    );
  }

  Future<void> _openForm({
    Object? extra,
    Map<String, String>? parameters,
  }) async {
    if (_opening) return;
    setState(() => _opening = true);
    FocusScope.of(context).unfocus();
    try {
      final saved = await context.push<bool>(
        Uri(path: '/medicine/new', queryParameters: parameters).toString(),
        extra: extra,
      );
      if (!mounted || saved != true) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/inventory');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _scan() async {
    if (_opening) return;
    setState(() => _opening = true);
    FocusScope.of(context).unfocus();
    String? gtin;
    try {
      gtin = await context.push<String>('/scanner');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    if (!mounted || gtin == null) return;
    await _openForm(parameters: {'scanned': gtin});
  }

  Future<void> _pickManufacturer() async {
    final values = _manufacturers;
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Производитель',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('Все производители'),
                    selected: _manufacturer == null,
                    trailing: _manufacturer == null
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, ''),
                  ),
                  for (final value in values)
                    ListTile(
                      title: Text(value),
                      selected: _manufacturer == value,
                      trailing: _manufacturer == value
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, value),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    _updateFilters(() => _manufacturer = selection.isEmpty ? null : selection);
  }

  void _showDetails(DrugCatalogVariant variant) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .85,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: DrugCatalogDetails(
                    variant: variant,
                    initiallyExpanded: true,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChips({
    required String label,
    required List<String> values,
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Все'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final value in values)
            ChoiceChip(
              key: ValueKey('variant-filter-$label-$value'),
              label: Text(value),
              selected: value == selected,
              onSelected: (enabled) => onChanged(enabled ? value : null),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _variantCard(DrugCatalogVariant variant) {
    final entry = variant.entry;
    final package = variant.package;
    final title = package.quantity == null
        ? _manufacturerLabel(entry)
        : '${_manufacturerLabel(entry)} · ${package.title}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey('catalog-entry-${entry.id}'),
              onTap: _opening ? null : () => _choose(variant),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(package.detail ?? package.title),
                          if (entry.isInactive) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Запись в справочнике недействующая',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('catalog-details-${entry.id}'),
            tooltip: 'Данные из справочника',
            onPressed: () => _showDetails(variant),
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDosages = _variants.map((v) => v.entry.dosageLabel).toSet();
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите упаковку')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed || _group == null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        _failed
                            ? 'Не удалось загрузить варианты препарата.'
                            : 'Препарат не найден в справочнике.',
                      ),
                      if (_failed)
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить загрузку'),
                        ),
                      OutlinedButton.icon(
                        onPressed: _opening ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Сканировать код упаковки'),
                      ),
                      TextButton(
                        onPressed: _opening
                            ? null
                            : () => _openForm(
                                parameters: {'name': widget.groupKey},
                              ),
                        child: const Text('Заполнить вручную'),
                      ),
                    ],
                  )
                : CustomScrollView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${_group!.name}${allDosages.length == 1 ? ' · ${allDosages.single}' : ''}',
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text('Сверьте данные с вашей упаковкой.'),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _opening ? null : _scan,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Сканировать код упаковки'),
                              ),
                              const SizedBox(height: 20),
                              if (_forms.length > 1)
                                _filterChips(
                                  label: 'Форма',
                                  values: _forms,
                                  selected: _form,
                                  onChanged: (value) =>
                                      _updateFilters(() => _form = value),
                                ),
                              if (_dosages.length > 1)
                                _filterChips(
                                  label: 'Дозировка',
                                  values: _dosages,
                                  selected: _dosage,
                                  onChanged: (value) =>
                                      _updateFilters(() => _dosage = value),
                                ),
                              if (_manufacturers.length > 1) ...[
                                OutlinedButton(
                                  key: const ValueKey(
                                    'variant-manufacturer-filter',
                                  ),
                                  onPressed: _pickManufacturer,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Производитель: ${_manufacturer ?? 'Все'}',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.expand_more),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                key: const ValueKey('catalog-variant-input'),
                                controller: _query,
                                onChanged: (_) => _updateFilters(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Поиск среди упаковок',
                                  hintText:
                                      'Например, 20 капсул или производитель',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _query.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Очистить поиск вариантов',
                                          icon: const Icon(Icons.close),
                                          onPressed: () =>
                                              _updateFilters(_query.clear),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _hasFilters
                                      ? '${russianCount(_visible.length, 'вариант', 'варианта', 'вариантов')} из ${_variants.length}'
                                      : russianCount(
                                          _variants.length,
                                          'вариант упаковки',
                                          'варианта упаковки',
                                          'вариантов упаковки',
                                        ),
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              if (_hasFilters)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: _resetFilters,
                                    child: const Text('Сбросить фильтры'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_visible.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Text(
                              'Подходящих упаковок нет. Измените поиск или сбросьте фильтры.',
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList.builder(
                          itemCount: _visible.length,
                          itemBuilder: (context, index) {
                            final variant = _visible[index];
                            final entry = variant.entry;
                            final previous = index == 0
                                ? null
                                : _visible[index - 1].entry;
                            final sectionStart =
                                previous == null ||
                                previous.displayForm != entry.displayForm ||
                                previous.dosageLabel != entry.dosageLabel;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (sectionStart)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        8,
                                        4,
                                        12,
                                      ),
                                      child: Text(
                                        '${entry.displayForm}${allDosages.length > 1 ? ' · ${entry.dosageLabel}' : ''}',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                  _variantCard(variant),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Не нашли свою упаковку?'),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _opening
                                      ? null
                                      : () => _openForm(
                                          parameters: {'name': _group!.name},
                                        ),
                                  child: const Text('Заполнить вручную'),
                                ),
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
    );
  }
}
