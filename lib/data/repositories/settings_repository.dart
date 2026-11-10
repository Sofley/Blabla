import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// User preferences stored in a Hive box.
class SettingsRepository {
  SettingsRepository(this._box);

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

  double get defaultVatRefund =>
      (_box.get('defaultVatRefund') as num?)?.toDouble() ?? 9;
  Future<void> setDefaultVatRefund(double v) => _box.put('defaultVatRefund', v);

  String get defaultUnit => _box.get('defaultUnit') as String? ?? '';
  Future<void> setDefaultUnit(String v) => _box.put('defaultUnit', v);

  String get companyName => _box.get('companyName') as String? ?? '';
  Future<void> setCompanyName(String v) => _box.put('companyName', v);
}
