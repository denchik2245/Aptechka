import 'package:aptechka/core/utils/drug_text.dart';

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
  String get displayName => readableDrugName(name);
  String get displayIngredient => readableDrugText(activeIngredient);
  String get displayForm => readableDrugText(form);
  String get displayManufacturer => readableManufacturer(manufacturer);
  String get displayPackage => readableDrugText(packageDescription);
}

abstract interface class DrugCatalogService {
  String get sourceLabel;
  Future<List<DrugCatalogEntry>> listAll();
  Future<List<DrugCatalogEntry>> search(String query, {int limit = 6});
  Future<DrugCatalogEntry?> findByGtin(String gtin);
}
