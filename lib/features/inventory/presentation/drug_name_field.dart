import 'dart:async';

import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inline results remain part of the form scroll, including on narrow screens.
class DrugNameField extends ConsumerStatefulWidget {
  const DrugNameField({
    required this.controller,
    required this.validator,
    required this.onChanged,
    required this.onSelected,
    super.key,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;
  final ValueChanged<DrugCatalogEntry> onSelected;

  @override
  ConsumerState<DrugNameField> createState() => _DrugNameFieldState();
}

class _DrugNameFieldState extends ConsumerState<DrugNameField> {
  Timer? _debounce;
  int _generation = 0;
  String _query = '';
  List<DrugCatalogEntry> _results = const [];
  bool _loading = false;
  bool _showResults = false;
  bool _failed = false;
  int _limit = 6;
  bool _hasMore = false;

  @override
  void didUpdateWidget(covariant DrugNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.text.trim() != _query) {
      // Scanner/programmatic prefills supersede any pending typed search.
      _dismiss();
      _query = widget.controller.text.trim();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    super.dispose();
  }

  void _dismiss() {
    _debounce?.cancel();
    _generation++;
    _showResults = false;
    _loading = false;
    _failed = false;
    _results = const [];
    _hasMore = false;
  }

  void _search(String value, {bool more = false}) {
    _debounce?.cancel();
    final generation = ++_generation;
    _query = value.trim();
    _limit = more ? _limit + 6 : 6;
    setState(() {
      if (!more) _results = const [];
      _hasMore = false;
      _failed = false;
      _showResults = _query.length >= 2;
      _loading = _showResults;
    });
    if (!_showResults) return;
    _debounce = Timer(Duration(milliseconds: more ? 0 : 250), () async {
      try {
        final matches = await ref
            .read(drugCatalogServiceProvider)
            .search(_query, limit: _limit + 1);
        if (!mounted || generation != _generation) return;
        setState(() {
          _hasMore = matches.length > _limit;
          _results = matches.take(_limit).toList();
          _loading = false;
        });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    });
  }

  void _choose(DrugCatalogEntry entry) {
    setState(() {
      _dismiss();
      _query = entry.name;
    });
    widget.onSelected(entry);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final catalog = ref.watch(drugCatalogServiceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('drug-name-input'),
          controller: widget.controller,
          validator: widget.validator,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (value) {
            widget.onChanged(value);
            _search(value);
          },
          decoration: InputDecoration(
            labelText: 'Название *',
            hintText: 'Например, Ибупрофен',
            helperText: '${catalog.sourceLabel} · поиск от 2 символов',
            helperMaxLines: 3,
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
          ),
        ),
        if (_showResults) ...[
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _loading
                          ? 'Ищем в справочнике…'
                          : _failed
                          ? 'Не удалось выполнить поиск'
                          : _results.isEmpty
                          ? 'Совпадений не найдено'
                          : 'Выберите препарат · ${russianCount(_results.length, 'вариант', 'варианта', 'вариантов')}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                if (!_loading && !_failed && _results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Попробуйте другое название или заполните характеристики вручную.',
                    ),
                  ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _search(widget.controller.text),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить поиск'),
                      ),
                    ),
                  ),
                ..._results.map(
                  (entry) => ListTile(
                    title: Text(entry.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry.form} · ${entry.dosageLabel}'),
                        Text(
                          'МНН: ${entry.activeIngredient}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.manufacturer.isNotEmpty)
                          Text(
                            'Производитель: ${entry.manufacturer}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (entry.packageDescription.isNotEmpty)
                          Text(
                            'Упаковка: ${entry.packageDescription}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (entry.isInactive)
                          Text(
                            'В источнике: ${entry.registrationStatus}',
                            style: TextStyle(color: colors.error),
                          ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.add_circle_outline,
                      color: colors.primary,
                    ),
                    onTap: () => _choose(entry),
                  ),
                ),
                if (_hasMore && !_loading)
                  TextButton.icon(
                    onPressed: () =>
                        _search(widget.controller.text, more: true),
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Показать ещё варианты'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: TextButton.icon(
                    onPressed: () => setState(_dismiss),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Заполнить вручную'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
