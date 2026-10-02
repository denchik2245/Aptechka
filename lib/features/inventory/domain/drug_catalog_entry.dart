class DrugCatalogEntry {
  const DrugCatalogEntry({
    required this.id,
    this.gtin,
    required this.name,
    required this.activeIngredient,
    required this.form,
    required this.dosage,
    required this.unit,
    this.manufacturer = '',
    this.packageDescription = '',
    this.registrationId = '',
    this.registrationStatus = '',
    this.sourceVersion = '',
  });

  final String id;
  final String? gtin;
  final String name;
  final String activeIngredient;
  final String form;
  final String dosage;
  final String unit;
  final String manufacturer;
  final String packageDescription;
  final String registrationId;
  final String registrationStatus;
  final String sourceVersion;
  bool get isInactive => registrationStatus == 'Недействующий';
  String get dosageLabel => dosage.isEmpty ? 'Дозировка не указана' : dosage;
}

abstract interface class DrugCatalogService {
  String get sourceLabel;
  Future<List<DrugCatalogEntry>> search(String query, {int limit = 6});
  Future<DrugCatalogEntry?> findByGtin(String gtin);
}
