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
      (_box.get('defaultAgencyFee') as num?)?.toDouble() ?? 8;
  Future<void> setDefaultAgencyFee(double v) => _box.put('defaultAgencyFee', v);

  double get defaultVat => (_box.get('defaultVat') as num?)?.toDouble() ?? 9;
  Future<void> setDefaultVat(double v) => _box.put('defaultVat', v);

  double get defaultVatRefund =>
      (_box.get('defaultVatRefund') as num?)?.toDouble() ?? 9;
  Future<void> setDefaultVatRefund(double v) => _box.put('defaultVatRefund', v);

  String get defaultUnit => _box.get('defaultUnit') as String? ?? '';
  Future<void> setDefaultUnit(String v) => _box.put('defaultUnit', v);

  String get accent => _box.get('accent') as String? ?? 'blue';
  Future<void> setAccent(String v) => _box.put('accent', v);

  String? get backgroundPath => _box.get('backgroundPath') as String?;
  Future<void> setBackgroundPath(String? v) =>
      v == null ? _box.delete('backgroundPath') : _box.put('backgroundPath', v);

  /// Visibility of the background image, 0.1–1.0.
  double get backgroundOpacity =>
      (_box.get('backgroundOpacity') as num?)?.toDouble() ?? 0.45;
  Future<void> setBackgroundOpacity(double v) =>
      _box.put('backgroundOpacity', v);

  /// Blur radius of the background image, 0–25.
  double get backgroundBlur =>
      (_box.get('backgroundBlur') as num?)?.toDouble() ?? 8;
  Future<void> setBackgroundBlur(double v) => _box.put('backgroundBlur', v);

  /// Agent VAT %, null = not set («Не задано»).
  double? get defaultAgentVat =>
      (_box.get('defaultAgentVat') as num?)?.toDouble();
  Future<void> setDefaultAgentVat(double? v) => v == null
      ? _box.delete('defaultAgentVat')
      : _box.put('defaultAgentVat', v);

  /// Our share of the VAT refund received by the intermediary, 0–100 %.
  double get defaultVatShare =>
      (_box.get('defaultVatShare') as num?)?.toDouble() ?? 0;
  Future<void> setDefaultVatShare(double v) => _box.put('defaultVatShare', v);

  /// Default profit per unit (USD), e.g. 0.33 $/kg.
  double get defaultProfitPerUnit =>
      (_box.get('defaultProfitPerUnit') as num?)?.toDouble() ?? 0.33;
  Future<void> setDefaultProfitPerUnit(double v) =>
      _box.put('defaultProfitPerUnit', v);

  /// Version of the stored data (3 since NexusTrade 3.0).
  int get dataSchema => (_box.get('dataSchema') as num?)?.toInt() ?? 0;
  Future<void> setDataSchema(int v) => _box.put('dataSchema', v);

  String get companyName => _box.get('companyName') as String? ?? '';
  Future<void> setCompanyName(String v) => _box.put('companyName', v);
}
