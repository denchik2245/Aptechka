import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:aptechka/features/inventory/domain/drug_name_matching.dart';

export 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';

final drugCatalogServiceProvider = Provider<DrugCatalogService>(
  (ref) => MdlpDrugCatalogService(),
);

class DemoDrugCatalogService implements DrugCatalogService {
  const DemoDrugCatalogService();

  @override
  String get sourceLabel => 'Демонстрационный справочник';

  // Prototype fixtures, not a full registry. Demo GTINs are for scanner testing only.
  // New trade-name variants are documented with source links in docs/drug-catalog.md.
  static const _entries = <DrugCatalogEntry>[
    DrugCatalogEntry(
      id: 'demo-ibuprofen-200-tablets',
      gtin: '04600000000001',
      name: 'Ибупрофен',
      activeIngredient: 'Ибупрофен',
      form: 'Таблетки',
      dosage: '200 мг',
      unit: 'таблеток',
    ),
    DrugCatalogEntry(
      id: 'demo-ibuprofen-400-tablets',
      name: 'Ибупрофен',
      activeIngredient: 'Ибупрофен',
      form: 'Таблетки',
      dosage: '400 мг',
      unit: 'таблеток',
    ),
    DrugCatalogEntry(
      id: 'demo-loratadine-10-tablets',
      gtin: '04600000000002',
      name: 'Лоратадин',
      activeIngredient: 'Лоратадин',
      form: 'Таблетки',
      dosage: '10 мг',
      unit: 'таблеток',
    ),
    DrugCatalogEntry(
      id: 'demo-saline-09-solution',
      name: 'Натрия хлорид',
      activeIngredient: 'Натрия хлорид',
      form: 'Раствор',
      dosage: '0,9%',
      unit: 'флаконов',
    ),
    DrugCatalogEntry(
      id: 'demo-nurofen-200-tablets',
      name: 'Нурофен',
      activeIngredient: 'Ибупрофен',
      form: 'Таблетки',
      dosage: '200 мг',
      unit: 'таблеток',
    ),
    DrugCatalogEntry(
      id: 'demo-nurofen-forte-400-tablets',
      name: 'Нурофен Форте',
      activeIngredient: 'Ибупрофен',
      form: 'Таблетки',
      dosage: '400 мг',
      unit: 'таблеток',
    ),
    DrugCatalogEntry(
      id: 'demo-nurofen-express-200-capsules',
      name: 'Нурофен Экспресс',
      activeIngredient: 'Ибупрофен',
      form: 'Капсулы',
      dosage: '200 мг',
      unit: 'капсул',
    ),
    DrugCatalogEntry(
      id: 'demo-nurofen-express-forte-400-capsules',
      name: 'Нурофен Экспресс Форте',
      activeIngredient: 'Ибупрофен',
      form: 'Капсулы',
      dosage: '400 мг',
      unit: 'капсул',
    ),
  ];

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'\s+'), ' ');

  @override
  Future<List<DrugCatalogEntry>> listAll() async =>
      alphabetizeDrugEntries(_entries);

  @override
  Future<List<DrugCatalogEntry>> search(String query, {int limit = 6}) async {
    final normalized = _normalize(query);
    if (normalized.length < 2 || limit <= 0) return const [];
    final words = normalized.split(' ');
    final matches = _entries.where((entry) {
      final text = _normalize(
        '${entry.name} ${entry.activeIngredient} ${entry.form} ${entry.dosage}',
      );
      return words.every(text.contains) ||
          drugNameTypoDistance(_normalize(entry.name), normalized) != null;
    }).toList();
    int rank(DrugCatalogEntry entry) {
      final name = _normalize(entry.name);
      final text = _normalize(
        '${entry.name} ${entry.activeIngredient} ${entry.form} ${entry.dosage}',
      );
      if (!words.every(text.contains)) {
        return 3 + (drugNameTypoDistance(name, normalized) ?? 3);
      }
      return name == normalized
          ? 0
          : name.startsWith(normalized)
          ? 1
          : name.contains(normalized)
          ? 2
          : 3;
    }

    // Stable order keeps variants in their curated order at equal relevance.
    matches.sort((a, b) {
      final relevance = rank(a).compareTo(rank(b));
      return relevance != 0
          ? relevance
          : _entries.indexOf(a).compareTo(_entries.indexOf(b));
    });
    return matches.take(limit).toList(growable: false);
  }

  @override
  Future<DrugCatalogEntry?> findByGtin(String gtin) async =>
      _entries.where((entry) => entry.gtin == gtin).firstOrNull;
}
