/// How the user identifies: by e-mail or by phone number.
enum LoginType {
  email,
  phone;

  static LoginType fromName(String? n) =>
      LoginType.values.firstWhere((t) => t.name == n, orElse: () => email);
}

/// Optional fast unlock method used instead of typing the password.
enum QuickUnlock {
  none,
  pin4,
  pin6,
  pattern;

  static QuickUnlock fromName(String? n) =>
      QuickUnlock.values.firstWhere((t) => t.name == n, orElse: () => none);

  int get pinLength => switch (this) {
    QuickUnlock.pin4 => 4,
    QuickUnlock.pin6 => 6,
    _ => 0,
  };

  bool get isPin => this == pin4 || this == pin6;
}

/// Local user account. Secrets are stored only as salted PBKDF2 hashes.
class Account {
  const Account({
    required this.loginType,
    required this.login,
    this.displayName = '',
    required this.passwordSalt,
    required this.passwordHash,
    this.quickUnlock = QuickUnlock.none,
    this.quickSalt = '',
    this.quickHash = '',
    required this.createdAt,
  });

  final LoginType loginType;
  final String login;
  final String displayName;
  final String passwordSalt;
  final String passwordHash;
  final QuickUnlock quickUnlock;
  final String quickSalt;
  final String quickHash;
  final DateTime createdAt;

  Account copyWith({
    String? displayName,
    String? passwordSalt,
    String? passwordHash,
    QuickUnlock? quickUnlock,
    String? quickSalt,
    String? quickHash,
  }) => Account(
    loginType: loginType,
    login: login,
    displayName: displayName ?? this.displayName,
    passwordSalt: passwordSalt ?? this.passwordSalt,
    passwordHash: passwordHash ?? this.passwordHash,
    quickUnlock: quickUnlock ?? this.quickUnlock,
    quickSalt: quickSalt ?? this.quickSalt,
    quickHash: quickHash ?? this.quickHash,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'loginType': loginType.name,
    'login': login,
    'displayName': displayName,
    'passwordSalt': passwordSalt,
    'passwordHash': passwordHash,
    'quickUnlock': quickUnlock.name,
    'quickSalt': quickSalt,
    'quickHash': quickHash,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Account.fromJson(Map<dynamic, dynamic> j) => Account(
    loginType: LoginType.fromName(j['loginType'] as String?),
    login: j['login'] as String,
    displayName: j['displayName'] as String? ?? '',
    passwordSalt: j['passwordSalt'] as String,
    passwordHash: j['passwordHash'] as String,
    quickUnlock: QuickUnlock.fromName(j['quickUnlock'] as String?),
    quickSalt: j['quickSalt'] as String? ?? '',
    quickHash: j['quickHash'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
