import 'package:flutter/material.dart';

import '../core/l10n/app_lang.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo)
    : _themeMode = _repo.themeMode,
      _languageCode = _repo.languageCode,
      _defaultAgencyFee = _repo.defaultAgencyFee,
      _defaultVat = _repo.defaultVat,
      _companyName = _repo.companyName,
      _defaultVatRefund = _repo.defaultVatRefund,
      _defaultUnit = _repo.defaultUnit,
      _accent = AccentColor.fromName(_repo.accent),
      _backgroundPath = _repo.backgroundPath,
      _backgroundOpacity = _repo.backgroundOpacity,
      _backgroundBlur = _repo.backgroundBlur,
      _observerMode = _repo.observerMode;

  final SettingsRepository _repo;

  /// Re-reads all values (after restore or wipe).
  void reload() {
    _themeMode = _repo.themeMode;
    _languageCode = _repo.languageCode;
    _defaultAgencyFee = _repo.defaultAgencyFee;
    _defaultVat = _repo.defaultVat;
    _companyName = _repo.companyName;
    _defaultVatRefund = _repo.defaultVatRefund;
    _defaultUnit = _repo.defaultUnit;
    _accent = AccentColor.fromName(_repo.accent);
    _backgroundPath = _repo.backgroundPath;
    _backgroundOpacity = _repo.backgroundOpacity;
    _backgroundBlur = _repo.backgroundBlur;
    _observerMode = _repo.observerMode;
    notifyListeners();
  }

  Map<String, dynamic> toBackup() => {
    'defaultAgencyFee': _defaultAgencyFee,
    'defaultVat': _defaultVat,
    'defaultVatRefund': _defaultVatRefund,
    'defaultUnit': _defaultUnit,
    'companyName': _companyName,
  };

  Future<void> restoreBackup(Map<dynamic, dynamic> m) async {
    double d(String k, double f) => (m[k] as num?)?.toDouble() ?? f;
    await _repo.setDefaultAgencyFee(d('defaultAgencyFee', 9));
    await _repo.setDefaultVat(d('defaultVat', 9));
    await _repo.setDefaultVatRefund(d('defaultVatRefund', 9));
    await _repo.setDefaultUnit(m['defaultUnit'] as String? ?? '');
    await _repo.setCompanyName(m['companyName'] as String? ?? '');
    reload();
  }

  ThemeMode _themeMode;
  String? _languageCode;
  double _defaultAgencyFee;
  double _defaultVat;
  String _companyName;
  double _defaultVatRefund;
  String _defaultUnit;
  AccentColor _accent;
  String? _backgroundPath;
  double _backgroundOpacity;
  double _backgroundBlur;
  bool _observerMode;

  AccentColor get accent => _accent;
  String? get backgroundPath => _backgroundPath;
  double get backgroundOpacity => _backgroundOpacity;
  double get backgroundBlur => _backgroundBlur;

  /// Read-only "Observer" mode: nothing can be created, edited or deleted.
  bool get observerMode => _observerMode;

  Future<void> setAccent(AccentColor a) async {
    _accent = a;
    notifyListeners();
    await _repo.setAccent(a.name);
  }

  Future<void> setBackgroundPath(String? path) async {
    _backgroundPath = path;
    notifyListeners();
    await _repo.setBackgroundPath(path);
  }

  Future<void> setBackgroundOpacity(double v) async {
    _backgroundOpacity = v;
    notifyListeners();
    await _repo.setBackgroundOpacity(v);
  }

  Future<void> setBackgroundBlur(double v) async {
    _backgroundBlur = v;
    notifyListeners();
    await _repo.setBackgroundBlur(v);
  }

  Future<void> setObserverMode(bool v) async {
    _observerMode = v;
    notifyListeners();
    await _repo.setObserverMode(v);
  }

  double get defaultVatRefund => _defaultVatRefund;
  String get defaultUnit => _defaultUnit;

  Future<void> setDefaultVatRefund(double value) async {
    _defaultVatRefund = value;
    notifyListeners();
    await _repo.setDefaultVatRefund(value);
  }

  Future<void> setDefaultUnit(String value) async {
    _defaultUnit = value.trim();
    notifyListeners();
    await _repo.setDefaultUnit(_defaultUnit);
  }

  ThemeMode get themeMode => _themeMode;

  /// Selected interface language; null = follow the device.
  AppLang? get lang => AppLang.fromTag(_languageCode);
  Locale? get locale => lang?.locale;
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
