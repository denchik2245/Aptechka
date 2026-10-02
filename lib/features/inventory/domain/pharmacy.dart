class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.ownerLabel,
    required this.isShared,
    required this.canEdit,
    this.ownerAccountId,
  });

  final String id;
  final String name;
  final String ownerLabel;
  final bool isShared;
  final bool canEdit;
  final String? ownerAccountId;

  Pharmacy withOwner(String accountId) => Pharmacy(
    id: id,
    name: name,
    ownerLabel: 'Вы',
    isShared: isShared,
    canEdit: canEdit,
    ownerAccountId: accountId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'ownerLabel': ownerLabel,
    'isShared': isShared,
    'canEdit': canEdit,
    'ownerAccountId': ownerAccountId,
  };

  factory Pharmacy.fromJson(Map<String, Object?> json) => Pharmacy(
    id: json['id']! as String,
    name: json['name']! as String,
    ownerLabel: json['ownerLabel'] as String? ?? 'Вы',
    isShared: json['isShared'] as bool? ?? false,
    canEdit: json['canEdit'] as bool? ?? true,
    ownerAccountId: json['ownerAccountId'] as String?,
  );
}
