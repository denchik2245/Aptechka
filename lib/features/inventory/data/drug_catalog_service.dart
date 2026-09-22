class DrugCatalogEntry {
  const DrugCatalogEntry({
    required this.gtin,
    required this.name,
    required this.activeIngredient,
    required this.form,
    required this.dosage,
    required this.unit,
  });

  final String gtin;
  final String name;
  final String activeIngredient;
  final String form;
  final String dosage;
  final String unit;
}

abstract interface class DrugCatalogService {
  Future<DrugCatalogEntry?> findByGtin(String gtin);
}

class DemoDrugCatalogService implements DrugCatalogService {
  const DemoDrugCatalogService();

  static const _entries = <String, DrugCatalogEntry>{
    '04600000000001': DrugCatalogEntry(
      gtin: '04600000000001',
      name: 'Ибупрофен',
      activeIngredient: 'Ибупрофен',
      form: 'Таблетки',
      dosage: '200 мг',
      unit: 'таблеток',
    ),
    '04600000000002': DrugCatalogEntry(
      gtin: '04600000000002',
      name: 'Лоратадин',
      activeIngredient: 'Лоратадин',
      form: 'Таблетки',
      dosage: '10 мг',
      unit: 'таблеток',
    ),
  };

  @override
  Future<DrugCatalogEntry?> findByGtin(String gtin) async => _entries[gtin];
}
