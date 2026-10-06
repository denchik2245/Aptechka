import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';

// Match spelling and case, but retain +, hyphens and other meaningful qualifiers.
String drugCatalogNameKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class DrugCatalogGroup {
  DrugCatalogGroup({required this.key, required List<DrugCatalogEntry> entries})
    : entries = List.unmodifiable(entries);

  final String key;
  final List<DrugCatalogEntry> entries;
  String get name => entries.first.displayName;
  List<String> get forms =>
      entries.map((entry) => entry.displayForm).toSet().toList();
}

/// Preserve catalog order and every variant, including inactive records and GTINs.
List<DrugCatalogGroup> groupDrugCatalogEntries(List<DrugCatalogEntry> entries) {
  final groups = <String, List<DrugCatalogEntry>>{};
  for (final entry in entries) {
    (groups[drugCatalogNameKey(entry.name)] ??= []).add(entry);
  }
  return groups.entries
      .map((group) => DrugCatalogGroup(key: group.key, entries: group.value))
      .toList(growable: false);
}
