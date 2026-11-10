import 'package:flutter/material.dart';

import '../data/repositories/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo)
    : _themeMode = _repo.themeMode,
      _languageCode = _repo.languageCode,
      _defaultAgencyFee = _repo.defaultAgencyFee,
      _defaultVat = _repo.defaultVat,
      _companyName = _repo.companyName;

  final SettingsRepository _repo;

  ThemeMode _themeMode;
  String? _languageCode;
  double _defaultAgencyFee;
  double _defaultVat;
  String _companyName;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _languageCode == null ? null : Locale(_languageCode!);
  String? get languageCode => _languageCode;
  double get defaultAgencyFee => _defaultAgencyFee;
  double get defaultVat => _defaultVat;
  String get companyName => _companyName;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _repo.setThemeMode(mode);
  }

  Future<void> setLanguageCode(String? code) async {
    _languageCode = code;
    notifyListeners();
    await _repo.setLanguageCode(code);
  }

  Future<void> setDefaultAgencyFee(double value) async {
    _defaultAgencyFee = value;
    notifyListeners();
    await _repo.setDefaultAgencyFee(value);
  }

  Future<void> setDefaultVat(double value) async {
    _defaultVat = value;
    notifyListeners();
    await _repo.setDefaultVat(value);
  }

  Future<void> setCompanyName(String value) async {
    _companyName = value.trim();
    notifyListeners();
    await _repo.setCompanyName(_companyName);
  }
}
