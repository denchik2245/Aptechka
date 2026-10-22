import 'dart:convert';

import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';

/// A display group, not a replacement for the original catalog records.
class DrugCatalogVariant {
  DrugCatalogVariant(List<DrugCatalogEntry> entries)
    : assert(entries.isNotEmpty),
      entries = List.unmodifiable(entries);

  final List<DrugCatalogEntry> entries;
  DrugCatalogEntry get entry => entries.first;
  bool get isAmbiguous => entries.length > 1;
  DrugPackageLabel get package => describeDrugPackage(entry);
}

String _textKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Only GTIN and record ID may differ. Registration, status, formulation,
/// ingredient, package description and source version remain distinct.
List<DrugCatalogVariant> groupDrugCatalogVariants(
  Iterable<DrugCatalogEntry> entries,
) {
  final groups = <String, List<DrugCatalogEntry>>{};
  for (final entry in entries) {
    final key = jsonEncode(
      [
        entry.name,
        entry.activeIngredient,
        entry.form,
        entry.dosage,
        entry.unit,
        entry.manufacturer,
        entry.packageDescription,
        entry.registrationId,
        entry.registrationStatus,
        entry.sourceVersion,
      ].map(_textKey).toList(),
    );
    (groups[key] ??= []).add(entry);
  }
  final variants = groups.values.map(DrugCatalogVariant.new).toList();
  variants.sort((a, b) {
    for (final result in [
      _textKey(a.entry.form).compareTo(_textKey(b.entry.form)),
      _textKey(a.entry.dosage).compareTo(_textKey(b.entry.dosage)),
      (a.entry.isInactive ? 1 : 0).compareTo(b.entry.isInactive ? 1 : 0),
      _textKey(a.entry.manufacturer).compareTo(_textKey(b.entry.manufacturer)),
      (a.package.quantity ?? 0).compareTo(b.package.quantity ?? 0),
      _textKey(a.entry.packageDescription)
          .compareTo(_textKey(b.entry.packageDescription)),
    ]) {
      if (result != 0) return result;
    }
    return a.entry.id.compareTo(b.entry.id);
  });
  return variants;
}

class DrugPackageLabel {
  const DrugPackageLabel(
    this.title, {
    this.detail,
    this.quantity,
    this.quantityUnit,
  });

  final String title;
  final String? detail;
  final int? quantity;
  final String? quantityUnit;
}

/// Parse only a complete container description in pieces for tablets/capsules.
/// Form qualifiers remain on the entry. Volume and dosage never become counts.
DrugPackageLabel describeDrugPackage(DrugCatalogEntry entry) {
  final form = _textKey(entry.form);
  final words = RegExp(r'^капсулы(?:$|[\s,])').hasMatch(form)
      ? ('капсула', 'капсулы', 'капсул')
      : RegExp(r'^таблетки(?:$|[\s,])').hasMatch(form)
      ? ('таблетка', 'таблетки', 'таблеток')
      : null;
  final match = RegExp(
    r'^(?:(\d+)\s*[xх×]\s*)?(упаковка ячейковая контурная|блистер|упаковка|банка|флакон)\s+по\s+(\d+)\s+шт\.?$',
    caseSensitive: false,
  ).firstMatch(entry.packageDescription.trim());
  if (words != null && match != null) {
    final containers = int.tryParse(match.group(1) ?? '1');
    final perContainer = int.tryParse(match.group(3)!);
    if (containers != null &&
        perContainer != null &&
        containers > 0 &&
        perContainer > 0 &&
        containers <= 100 &&
        perContainer <= 1000) {
      final containerWords = switch (_textKey(match.group(2)!)) {
        'банка' => ('банка', 'банки', 'банок'),
        'флакон' => ('флакон', 'флакона', 'флаконов'),
        'упаковка' => ('упаковка', 'упаковки', 'упаковок'),
        _ => ('блистер', 'блистера', 'блистеров'),
      };
      final quantity = containers * perContainer;
      return DrugPackageLabel(
        russianCount(quantity, words.$1, words.$2, words.$3),
        detail:
            '${russianCount(containers, containerWords.$1, containerWords.$2, containerWords.$3)} по $perContainer',
        quantity: quantity,
        quantityUnit: words.$3,
      );
    }
  }
  return DrugPackageLabel(
    entry.packageDescription.isEmpty
        ? 'Упаковка не указана'
        : entry.displayPackage,
  );
}
