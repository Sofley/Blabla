/// Roles of Stage 1 (offline). Internal finance — profit, agent fees,
/// logistics costs, internal calculations and reports — is available to
/// the [owner] only.
enum UserRole {
  /// Full control (the registered account).
  owner,

  /// Administrator: users, deals, documents, stages; no internal finance.
  admin,

  /// Manager: assigned deals, documents, stages; no internal finance.
  manager,

  /// Partner: basic info and stages of assigned deals, read only.
  partner,

  /// Client: own deals only, read only.
  client;

  static UserRole fromName(String? n) => UserRole.values.firstWhere(
    (r) => r.name == n,
    orElse: () => UserRole.client, // unknown → the most restricted role
  );
}

/// A local user profile on this device (until the server of Stage 4).
/// The owner is not stored here: it is the registered account.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.pinHash,
    required this.pinSalt,
    this.clientId,
    required this.createdAt,
  });

  /// Id of the owner session (the registered account).
  static const ownerId = 'owner';

  final String id;
  final String name;
  final UserRole role;

  /// PBKDF2 hash of the profile PIN (never the PIN itself).
  final String pinHash;
  final String pinSalt;

  /// For [UserRole.client]: the client from the directory whose deals
  /// this user may see.
  final String? clientId;
  final DateTime createdAt;

  AppUser copyWith({
    String? name,
    UserRole? role,
    String? pinHash,
    String? pinSalt,
    Object? clientId = _keep,
  }) => AppUser(
    id: id,
    name: name ?? this.name,
    role: role ?? this.role,
    pinHash: pinHash ?? this.pinHash,
    pinSalt: pinSalt ?? this.pinSalt,
    clientId: identical(clientId, _keep) ? this.clientId : clientId as String?,
    createdAt: createdAt,
  );

  static const Object _keep = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.name,
    'pinHash': pinHash,
    'pinSalt': pinSalt,
    'clientId': clientId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromJson(Map<dynamic, dynamic> j) => AppUser(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    // A stored profile can never be the owner: that is the account itself.
    role: switch (UserRole.fromName(j['role'] as String?)) {
      UserRole.owner => UserRole.client,
      final r => r,
    },
    pinHash: j['pinHash'] as String? ?? '',
    pinSalt: j['pinSalt'] as String? ?? '',
    clientId: j['clientId'] as String?,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
