import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Opens all Hive boxes. On devices the boxes are AES-256 encrypted with a
/// key kept in the platform keystore (Android Keystore / iOS Keychain).
class LocalStore {
  LocalStore._(this.deals, this.quotes, this.settings, this.auth);

  static const _keyName = 'b2b_ledger_hive_key';

  final Box<Map> deals;
  final Box<Map> quotes;
  final Box settings;
  final Box auth;

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
  }
}
