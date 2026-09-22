enum MedicineStatus { okay, expiringSoon, expired }

class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.form,
    required this.dosage,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    required this.location,
    this.activeIngredient,
    this.gtin,
    this.notes,
  });

  final String id;
  final String name;
  final String? activeIngredient;
  final String form;
  final String dosage;
  final int quantity;
  final String unit;
  final DateTime expiryDate;
  final String location;
  final String? gtin;
  final String? notes;

  MedicineStatus statusAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    if (expiry.isBefore(today)) {
      return MedicineStatus.expired;
    }
    if (expiry.difference(today).inDays <= 30) {
      return MedicineStatus.expiringSoon;
    }
    return MedicineStatus.okay;
  }

  int daysUntilExpiry(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'activeIngredient': activeIngredient,
    'form': form,
    'dosage': dosage,
    'quantity': quantity,
    'unit': unit,
    'expiryDate': expiryDate.toIso8601String(),
    'location': location,
    'gtin': gtin,
    'notes': notes,
  };

  factory Medicine.fromJson(Map<String, Object?> json) => Medicine(
    id: json['id']! as String,
    name: json['name']! as String,
    activeIngredient: json['activeIngredient'] as String?,
    form: json['form']! as String,
    dosage: json['dosage']! as String,
    quantity: json['quantity']! as int,
    unit: json['unit']! as String,
    expiryDate: DateTime.parse(json['expiryDate']! as String),
    location: json['location']! as String,
    gtin: json['gtin'] as String?,
    notes: json['notes'] as String?,
  );
}
