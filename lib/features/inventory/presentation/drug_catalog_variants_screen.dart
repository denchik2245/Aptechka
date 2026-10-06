import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
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
  List<({DrugCatalogEntry entry, String text})> _entries = const [];
  List<DrugCatalogEntry> _visible = const [];
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
    _entries = group.entries
        .map(
          (entry) => (
            entry: entry,
            text: normalizeDrugQuery(
              '${entry.form} ${entry.dosage} ${entry.manufacturer} ${entry.packageDescription} ${entry.activeIngredient} ${entry.registrationId}',
            ),
          ),
        )
        .toList(growable: false);
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

  void _filter() {
    final query = normalizeDrugQuery(_query.text);
    final words = query.isEmpty ? const <String>[] : query.split(' ');
    final barcode = RegExp(r'^(\d{8}|\d{12,14})$').hasMatch(query)
        ? query.padLeft(14, '0')
        : null;
    _visible = _entries
        .where(
          (item) => barcode == null
              ? words.every(item.text.contains)
              : item.entry.gtin?.padLeft(14, '0') == barcode,
        )
        .map((item) => item.entry)
        .toList(growable: false);
  }

  void _queryChanged(String _) {
    setState(_filter);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _choose(DrugCatalogEntry entry) async {
    if (_opening) return;
    _opening = true;
    FocusScope.of(context).unfocus();
    try {
      final saved = await context.push<bool>(
        Uri(
          path: '/medicine/new',
          queryParameters: entry.gtin == null ? null : {'catalog': entry.gtin!},
        ).toString(),
        extra: entry,
      );
      if (!mounted || saved != true) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/inventory');
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Варианты препарата')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Не удалось загрузить варианты препарата.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Повторить загрузку'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _group == null
                ? const Center(child: Text('Препарат не найден в справочнике.'))
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
                                _group!.name,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Выберите форму, дозировку, производителя и упаковку.',
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                key: const ValueKey('catalog-variant-input'),
                                controller: _query,
                                onChanged: _queryChanged,
                                decoration: InputDecoration(
                                  labelText: 'Поиск среди вариантов',
                                  hintText:
                                      'Дозировка, форма или производитель',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _query.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Очистить поиск вариантов',
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            _query.clear();
                                            _queryChanged('');
                                          },
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  '${russianCount(_visible.length, 'вариант', 'варианта', 'вариантов')} из ${_group!.entries.length}',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_visible.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Подходящих вариантов нет. Попробуйте изменить поиск.',
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        sliver: SliverList.builder(
                          itemCount: _visible.length,
                          itemBuilder: (context, index) {
                            final entry = _visible[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  key: ValueKey('catalog-entry-${entry.id}'),
                                  onTap: () => _choose(entry),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                entry.dosageLabel,
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(entry.displayForm),
                                              if (entry
                                                  .packageDescription
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Text(entry.displayPackage),
                                              ],
                                              if (entry.manufacturer.isNotEmpty)
                                                Text(entry.displayManufacturer),
                                              if (entry
                                                  .registrationId
                                                  .isNotEmpty)
                                                Text(
                                                  'РУ: ${entry.registrationId}',
                                                ),
                                              if (entry.gtin != null)
                                                Text('GTIN: ${entry.gtin}'),
                                              if (entry.isInactive) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Запись в справочнике недействующая',
                                                  style: TextStyle(
                                                    color:
                                                        theme.colorScheme.error,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.chevron_right,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
