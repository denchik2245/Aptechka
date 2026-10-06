import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:aptechka/features/inventory/domain/drug_name_matching.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DrugCatalogScreen extends ConsumerStatefulWidget {
  const DrugCatalogScreen({super.key});

  @override
  ConsumerState<DrugCatalogScreen> createState() => _DrugCatalogScreenState();
}

class _DrugCatalogScreenState extends ConsumerState<DrugCatalogScreen> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  List<({DrugCatalogGroup group, String name})> _groups = const [];
  List<DrugCatalogGroup> _visible = const [];
  Set<String> _suggestedKeys = const {};
  bool _loading = true;
  bool _failed = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final entries = await ref.read(drugCatalogServiceProvider).listAll();
      if (!mounted) return;
      setState(() {
        _groups = groupDrugCatalogEntries(entries)
            .map(
              (group) => (group: group, name: normalizeDrugQuery(group.name)),
            )
            .toList(growable: false);
        _loading = false;
        _filter();
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
    final prefix = normalizeDrugQuery(_query.text);
    final exact = <DrugCatalogGroup>[];
    final similar = <({DrugCatalogGroup group, int distance})>[];
    for (final item in _groups) {
      if (item.name.startsWith(prefix)) {
        exact.add(item.group);
      } else {
        final distance = drugNameTypoDistance(item.name, prefix);
        if (distance != null) {
          similar.add((group: item.group, distance: distance));
        }
      }
    }
    similar.sort((a, b) {
      final distance = a.distance.compareTo(b.distance);
      return distance != 0
          ? distance
          : drugNameSortKey(a.group.name)
                .compareTo(drugNameSortKey(b.group.name));
    });
    _suggestedKeys = similar.map((item) => item.group.key).toSet();
    _visible = [...exact, ...similar.map((item) => item.group)];
  }

  void _queryChanged(String _) {
    setState(_filter);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _openForm([DrugCatalogEntry? entry]) async {
    if (_opening) return;
    _opening = true;
    FocusScope.of(context).unfocus();
    final uri = Uri(
      path: '/medicine/new',
      queryParameters: entry?.gtin == null ? null : {'catalog': entry!.gtin!},
    );
    try {
      final saved = await context.push<bool>(uri.toString(), extra: entry);
      if (!mounted || saved != true) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/inventory');
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _openGroup(DrugCatalogGroup group) async {
    if (_opening) return;
    _opening = true;
    FocusScope.of(context).unfocus();
    try {
      final saved = await context.push<bool>(
        Uri(
          path: '/medicine/variants',
          queryParameters: {'name': group.key},
        ).toString(),
        extra: group,
      );
      if (!mounted || saved != true) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/inventory');
      }
    } finally {
      _opening = false;
    }
  }

  String _letter(DrugCatalogGroup group) =>
      normalizeDrugQuery(group.name).substring(0, 1).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите препарат')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Начните вводить название — поиск учитывает опечатки.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('catalog-name-input'),
                        controller: _query,
                        onChanged: _queryChanged,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Название препарата',
                          hintText: 'Например, Ибупрофен',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Очистить поиск',
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
                          _loading
                              ? 'Загружаем справочник…'
                              : _failed
                              ? 'Справочник недоступен'
                              : '${_query.text.trim().isEmpty ? 'Все препараты' : 'Найдено препаратов'} · ${NumberFormat.decimalPattern('ru').format(_visible.length)}',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildList(theme)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: TextButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Нет в списке? Заполнить вручную'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Не удалось загрузить список препаратов.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить загрузку'),
              ),
            ],
          ),
        ),
      );
    }
    if (_visible.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Препаратов с таким началом названия нет.\nПроверьте название или заполните поля вручную.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('catalog-list'),
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: _visible.length,
      itemBuilder: (context, index) {
        final group = _visible[index];
        final letter = _letter(group);
        final startsSection =
            index == 0 || _letter(_visible[index - 1]) != letter;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (startsSection)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                child: Text(
                  letter,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('catalog-group-${group.key}'),
                  onTap: () => _openGroup(group),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              if (_suggestedKeys.contains(group.key))
                                Text(
                                  'Похожее название',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              Text(
                                russianCount(
                                  group.entries.length,
                                  'вариант',
                                  'варианта',
                                  'вариантов',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                group.forms.join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
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
            ),
          ],
        );
      },
    );
  }
}
