import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../core/security/aes_gcm.dart';
import '../data/models/app_user.dart';
import '../data/models/chat_message.dart';
import '../data/models/client.dart';
import '../data/models/deal.dart';
import '../data/models/logistics_route.dart';
import '../data/models/price_quote.dart';

/// Argon2id parameters stored with every backup, so a file can always be
/// opened with the password it was made with.
class KdfParams {
  const KdfParams({
    this.memoryKiB = 19456, // 19 MiB — OWASP recommendation for Argon2id
    this.iterations = 2,
    this.parallelism = 1,
  });

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  Map<String, dynamic> toJson() => {
    'alg': 'argon2id',
    'm': memoryKiB,
    't': iterations,
    'p': parallelism,
  };

  static KdfParams fromJson(Map<dynamic, dynamic> j) {
    if (j['alg'] != 'argon2id') throw const FormatException('Unknown KDF');
    return KdfParams(
      memoryKiB: (j['m'] as num).toInt(),
      iterations: (j['t'] as num).toInt(),
      parallelism: (j['p'] as num).toInt(),
    );
  }
}

/// Key derived from the account password. Only the derived key is kept on
/// the phone (in the platform keystore) — never the password.
class BackupKey {
  const BackupKey({
    required this.key,
    required this.salt,
    this.params = const KdfParams(),
  });

  final Uint8List key;
  final Uint8List salt;
  final KdfParams params;

  static Future<BackupKey> derive(
    String password, {
    Uint8List? salt,
    KdfParams params = const KdfParams(),
  }) async {
    final s = salt ?? AesGcmBox.randomBytes(16);
    final key = await compute(_deriveEntry, (
      password,
      s,
      params.memoryKiB,
      params.iterations,
      params.parallelism,
    ));
    return BackupKey(key: key, salt: s, params: params);
  }

  static Future<Uint8List> _deriveEntry(
    (String, Uint8List, int, int, int) a,
  ) async {
    final algo = Argon2id(
      memory: a.$3,
      iterations: a.$4,
      parallelism: a.$5,
      hashLength: 32,
    );
    final k = await algo.deriveKeyFromPassword(password: a.$1, nonce: a.$2);
    return Uint8List.fromList(await k.extractBytes());
  }

  String serialize() => jsonEncode({
    'key': base64Url.encode(key),
    'salt': base64Url.encode(salt),
    'kdf': params.toJson(),
  });

  static BackupKey? deserialize(String? raw) {
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map;
      return BackupKey(
        key: base64Url.decode(j['key'] as String),
        salt: base64Url.decode(j['salt'] as String),
        params: KdfParams.fromJson(j['kdf'] as Map),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Everything a backup holds. Account credentials are never included:
/// after a restore the owner keeps the account of this phone.
class BackupContent {
  const BackupContent({
    required this.deals,
    required this.quotes,
    required this.settings,
    this.routes = const [],
    this.chat = const [],
    this.clients = const [],
    this.users = const [],
    this.attachments = const {},
    this.hasRoutes = false,
    this.encrypted = true,
    this.createdAt,
  });

  final List<Deal> deals;
  final List<PriceQuote> quotes;
  final Map<dynamic, dynamic> settings;
  final List<LogisticsRoute> routes;
  final List<ChatMessage> chat;
  final List<Client> clients;
  final List<AppUser> users;

  /// Document files by attachment id.
  final Map<String, Uint8List> attachments;

  /// Older backups have no tariff grid: keep the current one then.
  final bool hasRoutes;

  /// False for v2.x plain-JSON backups.
  final bool encrypted;
  final DateTime? createdAt;
}

/// Encrypted backup file (format "nexustrade-backup", version 4):
///
/// ```json
/// { "format": "nexustrade-backup", "version": 4, "createdAt": "...",
///   "kdf": {"alg": "argon2id", "m": 19456, "t": 2, "p": 1, "salt": "..."},
///   "cipher": "AES-256-GCM",
///   "data": "<base64: nonce | ciphertext | tag>" }
/// ```
/// The header (format, version, KDF, salt) is authenticated as AAD, so it
/// cannot be altered. Plain backups of v2.x ("b2b-ledger-backup",
/// versions 1–3) can still be restored.
class BackupService {
  const BackupService();

  static const format = 'nexustrade-backup';
  static const version = 4;
  static const legacyFormat = 'b2b-ledger-backup';

  /// Builds and encrypts a one-piece v4 backup with [key] (kept for
  /// compatibility and tests; the app writes the streaming v5 format).
  Future<Uint8List> encrypt(BackupContent c, BackupKey key) async {
    final plain = utf8.encode(jsonEncode(payload(c)));
    final header = _header(key);
    final sealed = await AesGcmBox.seal(
      plain,
      key.key,
      aad: utf8.encode(jsonEncode(header)),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          ...header,
          'createdAt': DateTime.now().toIso8601String(),
          'cipher': 'AES-256-GCM',
          'data': base64.encode(sealed),
        }),
      ),
    );
  }

  Map<String, dynamic> _header(BackupKey key) => {
    'format': format,
    'version': version,
    'kdf': {...key.params.toJson(), 'salt': base64Url.encode(key.salt)},
  };

  /// True when [json] is an encrypted v4 backup (a password is needed).
  static bool isEncrypted(Map<String, dynamic> json) =>
      json['format'] == format;

  /// Opens a v4 backup with the password it was made with.
  /// Throws [SecretBoxAuthenticationError] for a wrong password or a
  /// changed file, [FormatException] for something that is not a backup.
  Future<BackupContent> decrypt(
    Map<String, dynamic> json,
    String password, {
    BackupKey? knownKey,
  }) async {
    if (json['format'] != format) {
      throw const FormatException('Not a NexusTrade backup');
    }
    final kdf = json['kdf'] as Map;
    final salt = base64Url.decode(kdf['salt'] as String);
    final params = KdfParams.fromJson(kdf);
    // The key of this phone fits when the backup was made here with the
    // current password: no need to run Argon2 again.
    final key = knownKey != null && listEquals(knownKey.salt, salt)
        ? knownKey
        : await BackupKey.derive(password, salt: salt, params: params);
    final header = {
      'format': json['format'],
      'version': json['version'],
      'kdf': kdf,
    };
    final plain = await AesGcmBox.open(
      base64.decode(json['data'] as String),
      key.key,
      aad: utf8.encode(jsonEncode(header)),
    );
    final content = parse(jsonDecode(utf8.decode(plain)) as Map);
    return BackupContent(
      deals: content.deals,
      quotes: content.quotes,
      settings: content.settings,
      routes: content.routes,
      chat: content.chat,
      clients: content.clients,
      users: content.users,
      attachments: content.attachments,
      hasRoutes: content.hasRoutes,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  /// Reads a plain backup of v2.x (versions 1–3).
  BackupContent decodeLegacy(Map<String, dynamic> json) {
    if (json['format'] != legacyFormat) {
      throw const FormatException('Not a NexusTrade backup');
    }
    final c = parse(json);
    return BackupContent(
      deals: c.deals,
      quotes: c.quotes,
      settings: c.settings,
      routes: c.routes,
      chat: c.chat,
      hasRoutes: c.hasRoutes,
      encrypted: false,
      createdAt: DateTime.tryParse(json['exportedAt'] as String? ?? ''),
    );
  }

  /// Data part of a backup (also used by the streaming v5 format, which
  /// writes the files separately).
  Map<String, dynamic> payload(BackupContent c) => {
    'deals': [for (final d in c.deals) d.toJson()],
    'quotes': [for (final q in c.quotes) q.toJson()],
    'settings': c.settings,
    'routes': [for (final r in c.routes) r.toJson()],
    'chat': [for (final m in c.chat) m.toJson()],
    'clients': [for (final x in c.clients) x.toJson()],
    'users': [for (final u in c.users) u.toJson()],
    'attachments': {
      for (final e in c.attachments.entries) e.key: base64.encode(e.value),
    },
  };

  /// Reads the data part written by [payload].
  BackupContent parse(Map<dynamic, dynamic> json) {
    List<T> list<T>(String key, T Function(Map) read) => [
      for (final x in (json[key] as List? ?? const [])) read(x as Map),
    ];
    return BackupContent(
      deals: list('deals', Deal.fromJson),
      quotes: list('quotes', PriceQuote.fromJson),
      settings: (json['settings'] as Map?) ?? const {},
      routes: list('routes', LogisticsRoute.fromJson),
      chat: list('chat', ChatMessage.fromJson),
      clients: list('clients', Client.fromJson),
      users: list('users', AppUser.fromJson),
      attachments: {
        for (final e in ((json['attachments'] as Map?) ?? const {}).entries)
          e.key as String: base64.decode(e.value as String),
      },
      hasRoutes: json.containsKey('routes'),
    );
  }
}
