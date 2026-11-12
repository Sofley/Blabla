import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Opens all Hive boxes. On devices the boxes are AES-256 encrypted with a
/// key kept in the platform keystore (Android Keystore / iOS Keychain).
class LocalStore {
  LocalStore._(
    this.deals,
    this.quotes,
    this.settings,
    this.auth,
    this.routes,
    this.chat,
    this.clients,
    this.cipher,
  );

  static const _keyName = 'b2b_ledger_hive_key';

  final Box<Map> deals;
  final Box<Map> quotes;
  final Box settings;
  final Box auth;
  final Box<Map> routes;
  final Box<Map> chat;
  final Box<Map> clients;

  /// Cipher of all boxes (null in tests); reused for extra boxes such as
  /// the pre-migration snapshot.
  final HiveAesCipher? cipher;

  /// [encrypt] is false only in tests (no platform keystore there).
  static Future<LocalStore> open({bool encrypt = true}) async {
    HiveAesCipher? cipher;
    if (encrypt) {
      cipher = HiveAesCipher(await _loadKey());
    }
    return LocalStore._(
      await Hive.openBox<Map>('deals_v2', encryptionCipher: cipher),
      await Hive.openBox<Map>('quotes_v1', encryptionCipher: cipher),
      await Hive.openBox('settings_v2', encryptionCipher: cipher),
      await Hive.openBox('auth_v1', encryptionCipher: cipher),
      await Hive.openBox<Map>('routes_v1', encryptionCipher: cipher),
      await Hive.openBox<Map>('chat_v1', encryptionCipher: cipher),
      await Hive.openBox<Map>('clients_v1', encryptionCipher: cipher),
      cipher,
    );
  }

  static Future<List<int>> _loadKey() async {
    const storage = FlutterSecureStorage();
    final existing = await storage.read(key: _keyName);
    if (existing != null) return base64Url.decode(existing);
    final key = Hive.generateSecureKey();
    await storage.write(key: _keyName, value: base64Url.encode(key));
    return key;
  }

  /// Removes every record (used when the account is deleted).
  Future<void> wipe() async {
    await deals.clear();
    await quotes.clear();
    await settings.clear();
    await auth.clear();
    await routes.clear();
    await chat.clear();
    await clients.clear();
    for (final name in [snapshotBox, snapshotV4Box]) {
      if (await Hive.boxExists(name)) await Hive.deleteBoxFromDisk(name);
    }
  }

  /// Encrypted copy of the v2.x records taken before the v3 migration.
  static const snapshotBox = 'pre_v3_snapshot';

  /// Copy of the v3 records taken before the v4 (documents) migration.
  static const snapshotV4Box = 'pre_v4_snapshot';
}
