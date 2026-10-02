enum MedicineStatus { okay, expiringSoon, expired, unknown }

class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.form,
    required this.dosage,
    required this.quantity,
    required this.unit,
    required this.location,
    this.pharmacyId = 'home',
    this.expiryDate,
    this.openedAt,
    this.afterOpeningDays,
    this.activeIngredient,
    this.gtin,
    this.notes,
    this.catalogEntryId,
    this.manufacturer,
    this.packageDescription,
    this.registrationId,
    this.registrationStatus,
    this.catalogVersion,
  });

  final String id;
  final String pharmacyId;
  final String name;
  final String? activeIngredient;
  final String form;
  final String dosage;
  final int quantity;
  final String unit;
  final DateTime? expiryDate;
  final DateTime? openedAt;
  final int? afterOpeningDays;
  final String location;
  final String? gtin;
  final String? notes;
  final String? catalogEntryId;
  final String? manufacturer;
  final String? packageDescription;
  final String? registrationId;
  final String? registrationStatus;
  final String? catalogVersion;
  String get dosageLabel => dosage.isEmpty ? 'Дозировка не указана' : dosage;

  String get groupKey =>
      '${name.trim().toLowerCase()}|${form.trim().toLowerCase()}|${dosage.trim().toLowerCase()}';

  DateTime? get afterOpeningExpiry {
    if (openedAt == null || afterOpeningDays == null) return null;
    return DateTime(
      openedAt!.year,
      openedAt!.month,
      openedAt!.day,
    ).add(Duration(days: afterOpeningDays!));
  }

  DateTime? get effectiveExpiryDate {
    final afterOpening = afterOpeningExpiry;
    if (expiryDate == null) return afterOpening;
    if (afterOpening == null) return expiryDate;
    return expiryDate!.isBefore(afterOpening) ? expiryDate : afterOpening;
  }

  bool get hasIncompleteExpiryData =>
      expiryDate == null || (openedAt != null && afterOpeningDays == null);

  MedicineStatus statusAt(DateTime now, {int warningDays = 30}) {
    final today = DateTime(now.year, now.month, now.day);
    final expiry = effectiveExpiryDate;
    if (expiry != null && expiry.isBefore(today)) return MedicineStatus.expired;
    if (hasIncompleteExpiryData || expiry == null) {
      return MedicineStatus.unknown;
    }
    if (expiry.difference(today).inDays <= warningDays) {
      return MedicineStatus.expiringSoon;
    }
    return MedicineStatus.okay;
  }

  int? daysUntilExpiry(DateTime now) {
    final expiry = effectiveExpiryDate;
    if (expiry == null || hasIncompleteExpiryData) return null;
    final today = DateTime(now.year, now.month, now.day);
    return expiry.difference(today).inDays;
  }

  Medicine copyWith({
    String? id,
    String? pharmacyId,
    int? quantity,
    String? location,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    DateTime? openedAt,
    bool clearOpenedAt = false,
    int? afterOpeningDays,
    bool clearAfterOpeningDays = false,
  }) => Medicine(
    id: id ?? this.id,
    pharmacyId: pharmacyId ?? this.pharmacyId,
    name: name,
    activeIngredient: activeIngredient,
    form: form,
    dosage: dosage,
    quantity: quantity ?? this.quantity,
    unit: unit,
    expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
    openedAt: clearOpenedAt ? null : openedAt ?? this.openedAt,
    afterOpeningDays: clearAfterOpeningDays
        ? null
        : afterOpeningDays ?? this.afterOpeningDays,
    location: location ?? this.location,
    gtin: gtin,
    notes: notes,
    catalogEntryId: catalogEntryId,
    manufacturer: manufacturer,
    packageDescription: packageDescription,
    registrationId: registrationId,
    registrationStatus: registrationStatus,
    catalogVersion: catalogVersion,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'pharmacyId': pharmacyId,
    'name': name,
    'activeIngredient': activeIngredient,
    'form': form,
    'dosage': dosage,
    'quantity': quantity,
    'unit': unit,
    'expiryDate': expiryDate?.toIso8601String(),
    'openedAt': openedAt?.toIso8601String(),
    'afterOpeningDays': afterOpeningDays,
    'location': location,
    'gtin': gtin,
    'notes': notes,
    'catalogEntryId': catalogEntryId,
    'manufacturer': manufacturer,
    'packageDescription': packageDescription,
    'registrationId': registrationId,
    'registrationStatus': registrationStatus,
    'catalogVersion': catalogVersion,
  };

  factory Medicine.fromJson(Map<String, Object?> json) => Medicine(
    id: json['id']! as String,
    pharmacyId: json['pharmacyId'] as String? ?? 'home',
    name: json['name']! as String,
    activeIngredient: json['activeIngredient'] as String?,
    form: json['form']! as String,
    dosage: json['dosage']! as String,
    quantity: json['quantity']! as int,
    unit: json['unit']! as String,
    expiryDate: json['expiryDate'] == null
        ? null
        : DateTime.parse(json['expiryDate']! as String),
    openedAt: json['openedAt'] == null
        ? null
        : DateTime.parse(json['openedAt']! as String),
    afterOpeningDays: json['afterOpeningDays'] as int?,
    location: json['location']! as String,
    gtin: json['gtin'] as String?,
    notes: json['notes'] as String?,
    catalogEntryId: json['catalogEntryId'] as String?,
    manufacturer: json['manufacturer'] as String?,
    packageDescription: json['packageDescription'] as String?,
    registrationId: json['registrationId'] as String?,
    registrationStatus: json['registrationStatus'] as String?,
    catalogVersion: json['catalogVersion'] as String?,
  );
}
