enum AppAppearance { system, light, dark }

enum InventorySort { name, expiry }

class AppSettings {
  const AppSettings({
    this.appearance = AppAppearance.system,
    this.textScale = 1,
    this.expiryWarningDays = 30,
    this.expiryAlerts = true,
    this.stockAlerts = true,
    this.lowStockThreshold = 2,
    this.intakeSchedule = true,
    this.inventorySort = InventorySort.name,
    this.defaultPharmacyId,
  });

  final AppAppearance appearance;
  final double textScale;
  final int expiryWarningDays;
  final bool expiryAlerts;
  final bool stockAlerts;
  final int lowStockThreshold;
  final bool intakeSchedule;
  final InventorySort inventorySort;
  final String? defaultPharmacyId;

  AppSettings copyWith({
    AppAppearance? appearance,
    double? textScale,
    int? expiryWarningDays,
    bool? expiryAlerts,
    bool? stockAlerts,
    int? lowStockThreshold,
    bool? intakeSchedule,
    InventorySort? inventorySort,
    String? defaultPharmacyId,
    bool clearDefaultPharmacy = false,
  }) => AppSettings(
    appearance: appearance ?? this.appearance,
    textScale: textScale ?? this.textScale,
    expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
    expiryAlerts: expiryAlerts ?? this.expiryAlerts,
    stockAlerts: stockAlerts ?? this.stockAlerts,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    intakeSchedule: intakeSchedule ?? this.intakeSchedule,
    inventorySort: inventorySort ?? this.inventorySort,
    defaultPharmacyId: clearDefaultPharmacy
        ? null
        : defaultPharmacyId ?? this.defaultPharmacyId,
  );

  Map<String, Object?> toJson() => {
    'appearance': appearance.name,
    'textScale': textScale,
    'expiryWarningDays': expiryWarningDays,
    'expiryAlerts': expiryAlerts,
    'stockAlerts': stockAlerts,
    'lowStockThreshold': lowStockThreshold,
    'intakeSchedule': intakeSchedule,
    'inventorySort': inventorySort.name,
    'defaultPharmacyId': defaultPharmacyId,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    appearance:
        AppAppearance.values
            .where((value) => value.name == json['appearance'])
            .firstOrNull ??
        AppAppearance.system,
    textScale: const [1.0, 1.15, 1.3].contains(json['textScale'])
        ? (json['textScale'] as num).toDouble()
        : 1,
    expiryWarningDays:
        const [7, 14, 30, 60, 90].contains(json['expiryWarningDays'])
        ? json['expiryWarningDays'] as int
        : 30,
    expiryAlerts: json['expiryAlerts'] is bool
        ? json['expiryAlerts'] as bool
        : true,
    stockAlerts: json['stockAlerts'] is bool
        ? json['stockAlerts'] as bool
        : true,
    lowStockThreshold:
        const [1, 2, 3, 5, 10].contains(json['lowStockThreshold'])
        ? json['lowStockThreshold'] as int
        : 2,
    intakeSchedule: json['intakeSchedule'] is bool
        ? json['intakeSchedule'] as bool
        : true,
    inventorySort:
        InventorySort.values
            .where((value) => value.name == json['inventorySort'])
            .firstOrNull ??
        InventorySort.name,
    defaultPharmacyId: json['defaultPharmacyId'] is String
        ? json['defaultPharmacyId'] as String
        : null,
  );
}
