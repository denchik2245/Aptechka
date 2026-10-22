import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:flutter/material.dart';

class DrugCatalogDetails extends StatelessWidget {
  const DrugCatalogDetails({
    required this.variant,
    this.initiallyExpanded = false,
    super.key,
  });

  final DrugCatalogVariant variant;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final entry = variant.entry;
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: const Text('Данные из справочника'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.activeIngredient.isNotEmpty)
          Text('Действующее вещество: ${entry.displayIngredient}'),
        Text('Форма: ${entry.displayForm}'),
        Text('Дозировка: ${entry.dosageLabel}'),
        if (entry.manufacturer.isNotEmpty)
          Text('Производитель: ${entry.displayManufacturer}'),
        if (entry.packageDescription.isNotEmpty)
          Text('Упаковка: ${entry.displayPackage}'),
        if (entry.registrationId.isNotEmpty)
          SelectableText('РУ: ${entry.registrationId}'),
        if (entry.registrationStatus.isNotEmpty)
          Text('Статус записи: ${entry.registrationStatus}'),
        if (entry.sourceVersion.isNotEmpty)
          Text('Версия справочника: ${entry.sourceVersion}'),
        if (variant.isAmbiguous) ...[
          const SizedBox(height: 12),
          const Text(
            'Характеристики этих записей совпадают. Точный код вашей упаковки определяется сканированием.',
          ),
        ],
        for (final record in variant.entries)
          if (record.gtin != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText('GTIN: ${record.gtin}'),
            ),
      ],
    );
  }
}
