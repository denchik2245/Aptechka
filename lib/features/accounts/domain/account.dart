enum LoginMethod { email, yandex, vk, google, apple }

extension LoginMethodLabel on LoginMethod {
  String get label => switch (this) {
    LoginMethod.email => 'Почта',
    LoginMethod.yandex => 'Яндекс ID',
    LoginMethod.vk => 'VK ID',
    LoginMethod.google => 'Google',
    LoginMethod.apple => 'Apple',
  };
}

class LoginIdentity {
  const LoginIdentity({
    required this.method,
    required this.subject,
    required this.label,
  });
  final LoginMethod method;
  final String subject;
  final String label;
  Map<String, Object?> toJson() => {
    'method': method.name,
    'subject': subject,
    'label': label,
  };
  factory LoginIdentity.fromJson(Map<String, Object?> json) => LoginIdentity(
    method: LoginMethod.values.byName(json['method'] as String),
    subject: json['subject'] as String,
    label: json['label'] as String,
  );
}

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.name,
    required this.identities,
    required this.createdAt,
  });
  final String id;
  final String name;
  final List<LoginIdentity> identities;
  final DateTime createdAt;
  AccountProfile copyWith({String? name, List<LoginIdentity>? identities}) =>
      AccountProfile(
        id: id,
        name: name ?? this.name,
        identities: identities ?? this.identities,
        createdAt: createdAt,
      );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'identities': identities.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };
  factory AccountProfile.fromJson(Map<String, Object?> json) => AccountProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    identities: (json['identities'] as List)
        .map(
          (item) =>
              LoginIdentity.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class LocalAccounts {
  const LocalAccounts({this.profiles = const [], this.activeId});
  final List<AccountProfile> profiles;
  final String? activeId;
  AccountProfile? get active =>
      profiles.where((item) => item.id == activeId).firstOrNull;
  Map<String, Object?> toJson() => {
    'profiles': profiles.map((item) => item.toJson()).toList(),
    'activeId': activeId,
  };
  factory LocalAccounts.fromJson(Map<String, Object?> json) => LocalAccounts(
    profiles: (json['profiles'] as List? ?? [])
        .map(
          (item) =>
              AccountProfile.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(),
    activeId: json['activeId'] as String?,
  );
}
