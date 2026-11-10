import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// User preferences stored in a Hive box.
class SettingsRepository {
  SettingsRepository(this._box);

  static const boxName = 'settings_v1';

  static Future<SettingsRepository> open() async {
    final box = await Hive.openBox(boxName);
    return SettingsRepository(box);
  }

  final Box _box;

  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == _box.get('themeMode'),
    orElse: () => ThemeMode.system,
  );
  Future<void> setThemeMode(ThemeMode mode) => _box.put('themeMode', mode.name);

  /// `null` means follow the device language.
  String? get languageCode => _box.get('languageCode') as String?;
  Future<void> setLanguageCode(String? code) => code == null
      ? _box.delete('languageCode')
      : _box.put('languageCode', code);

  double get defaultAgencyFee =>
      (_box.get('defaultAgencyFee') as num?)?.toDouble() ?? 9;
  Future<void> setDefaultAgencyFee(double v) => _box.put('defaultAgencyFee', v);

  double get defaultVat => (_box.get('defaultVat') as num?)?.toDouble() ?? 9;
  Future<void> setDefaultVat(double v) => _box.put('defaultVat', v);

  String get companyName => _box.get('companyName') as String? ?? '';
  Future<void> setCompanyName(String v) => _box.put('companyName', v);
}
