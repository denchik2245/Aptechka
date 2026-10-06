import 'dart:convert';

import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:aptechka/features/inventory/domain/drug_name_matching.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final _queryMarks = RegExp(r'[®™+\-–—]+');
final _querySpaces = RegExp(r'\s+');
final _gtinPattern = RegExp(r'^\d{14}$');

String normalizeDrugQuery(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(',', '.')
    .replaceAll(_queryMarks, ' ')
    .replaceAll(_querySpaces, ' ');

// Russian names come first; ё is sorted together with е. Keep all GTIN variants.
String drugNameSortKey(String name) {
  final normalized = normalizeDrugQuery(name);
  final first = normalized.isEmpty ? 0 : normalized.codeUnitAt(0);
  final group = first >= 0x430 && first <= 0x44f
      ? 0
      : first >= 0x61 && first <= 0x7a
      ? 1
      : 2;
  return '$group:$normalized';
}

List<DrugCatalogEntry> alphabetizeDrugEntries(List<DrugCatalogEntry> entries) {
  final keys = {
    for (final entry in entries) entry.id: drugNameSortKey(entry.name),
  };
  return List<DrugCatalogEntry>.unmodifiable(
    [...entries]..sort((a, b) {
      final name = keys[a.id]!.compareTo(keys[b.id]!);
      if (name != 0) return name;
      final status = (a.isInactive ? 1 : 0).compareTo(b.isInactive ? 1 : 0);
      if (status != 0) return status;
      final variant =
          '${a.form} ${a.dosage} ${a.manufacturer} ${a.packageDescription}'
              .compareTo(
                '${b.form} ${b.dosage} ${b.manufacturer} ${b.packageDescription}',
              );
      return variant != 0 ? variant : a.id.compareTo(b.id);
    }),
  );
}

class MdlpDrugCatalogService implements DrugCatalogService {
  MdlpDrugCatalogService({Future<String> Function()? loadAsset})
    : _loadAsset =
          loadAsset ??
          (() =>
              rootBundle.loadString('assets/drug_catalog/mdlp_catalog.json'));

  final Future<String> Function() _loadAsset;
  Future<_CatalogData>? _pending;
  _CatalogData? _loaded;

  @override
  String get sourceLabel {
    final metadata = _loaded?.metadata;
    if (metadata == null) return 'МДЛП · Честный знак · полная выгрузка';
    final date = (metadata['validDate'] as String)
        .split('-')
        .reversed
        .join('.');
    return 'МДЛП · $date · ${metadata['recordCount']} записей';
  }

  Future<_CatalogData> _catalog() async {
    if (_loaded != null) return _loaded!;
    final pending = _pending ??= _loadAsset().then(
      (raw) => compute(_parseCatalog, raw),
    );
    try {
      return _loaded = await pending;
    } catch (_) {
      // A transient asset loading failure must remain retryable.
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }

  @override
  Future<List<DrugCatalogEntry>> listAll() async =>
      (await _catalog()).alphabeticalEntries;

  @override
  Future<List<DrugCatalogEntry>> search(String query, {int limit = 6}) async {
    final normalized = normalizeDrugQuery(query);
    if (normalized.length < 2 || limit <= 0) return const [];
    final catalog = await _catalog();
    final words = normalized.split(' ');
    // Exact matches precede typo suggestions; status breaks equal relevance.
    // Every source row remains addressable by GTIN; search avoids identical cards.
    final buckets = List.generate(12, (_) => <DrugCatalogEntry>[]);
    final typoDistances = <String, int>{};
    final seen = <String>{};
    for (var i = 0; i < catalog.entries.length; i++) {
      final entry = catalog.entries[i];
      final name = catalog.names[i];
      final exact = words.every(catalog.searchText[i].contains);
      final distance = exact
          ? -1
          : typoDistances.putIfAbsent(
              name,
              () => drugNameTypoDistance(name, normalized) ?? -1,
            );
      if (!exact && distance < 0) continue;
      final rank = !exact
          ? 3 + distance
          : name == normalized
          ? 0
          : name.startsWith(normalized)
          ? 1
          : name.contains(normalized)
          ? 2
          : 3;
      final fingerprint = jsonEncode([
        entry.name,
        entry.activeIngredient,
        entry.form,
        entry.dosage,
        entry.manufacturer,
        entry.packageDescription,
        entry.registrationId,
        entry.registrationStatus,
      ]);
      if (!seen.add(fingerprint)) continue;
      final bucket = buckets[rank * 2 + (entry.isInactive ? 1 : 0)];
      if (bucket.length < limit) bucket.add(entry);
    }
    return buckets.expand((items) => items).take(limit).toList(growable: false);
  }

  @override
  Future<DrugCatalogEntry?> findByGtin(String gtin) async =>
      (await _catalog()).byGtin[gtin];
}

class _CatalogData {
  const _CatalogData(
    this.metadata,
    this.entries,
    this.names,
    this.searchText,
    this.byGtin,
    this.alphabeticalEntries,
  );
  final Map<String, dynamic> metadata;
  final List<DrugCatalogEntry> entries;
  final List<String> names;
  final List<String> searchText;
  final Map<String, DrugCatalogEntry> byGtin;
  final List<DrugCatalogEntry> alphabeticalEntries;
}

_CatalogData _parseCatalog(String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  const fields = [
    'gtin',
    'name',
    'activeIngredient',
    'form',
    'dosage',
    'unit',
    'manufacturer',
    'packageDescription',
    'registrationId',
    'registrationStatus',
  ];
  if (data['schemaVersion'] != 1 ||
      !listEquals(data['fields'] as List, fields)) {
    throw const FormatException('Неизвестный формат справочника');
  }
  final strings = (data['strings'] as List).cast<String>();
  final entries = <DrugCatalogEntry>[];
  final names = <String>[];
  final searchText = <String>[];
  final gtins = <String, DrugCatalogEntry>{};
  final metadata = data['metadata'] as Map<String, dynamic>;
  final sourceVersion = metadata['validDate'] as String;
  for (final rawRow in data['entries'] as List) {
    final row = (rawRow as List).cast<int>();
    if (row.length != fields.length) {
      throw const FormatException('Повреждена запись справочника');
    }
    String cell(int column) => strings[row[column]];
    final gtin = cell(0);
    if (!_gtinPattern.hasMatch(gtin) || gtins.containsKey(gtin)) {
      throw const FormatException('Повреждён GTIN справочника');
    }
    final entry = DrugCatalogEntry(
      id: 'mdlp:$gtin',
      gtin: gtin,
      name: cell(1),
      activeIngredient: cell(2),
      form: cell(3),
      dosage: cell(4),
      unit: cell(5),
      manufacturer: cell(6),
      packageDescription: cell(7),
      registrationId: cell(8),
      registrationStatus: cell(9),
      sourceVersion: sourceVersion,
    );
    entries.add(entry);
    gtins[gtin] = entry;
    names.add(normalizeDrugQuery(entry.name));
    searchText.add(
      normalizeDrugQuery(
        '${entry.name} ${entry.activeIngredient} ${entry.form} ${entry.dosage} ${entry.manufacturer} ${entry.packageDescription} ${entry.registrationId}',
      ),
    );
  }
  if (entries.isEmpty ||
      entries.length != metadata['recordCount'] ||
      DateTime.tryParse(metadata['validDate'] as String) == null) {
    throw const FormatException('Неполный справочник');
  }
  return _CatalogData(
    metadata,
    entries,
    names,
    searchText,
    gtins,
    alphabetizeDrugEntries(entries),
  );
}
