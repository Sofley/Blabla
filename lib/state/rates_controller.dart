import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/models/currency.dart';
import '../data/models/exchange_rate.dart';
import '../data/services/cbu_rates_api.dart';

/// CBU rates (downloaded, cached offline) and PBOC rates (entered by hand:
/// the People's Bank of China has no open API).
class RatesController extends ChangeNotifier {
  RatesController(this._box, {CbuRatesApi? api}) : _api = api ?? CbuRatesApi() {
    reload();
  }

  final Box _box;
  final CbuRatesApi _api;

  /// Currencies shown first in the CBU list.
  static const featured = [
    'USD',
    'EUR',
    'CNY',
    'RUB',
    'KZT',
    'AED',
    'GBP',
    'JPY',
    'TRY',
  ];

  /// Rates the user can set for PBOC (CNY per unit).
  static const pbocCodes = ['USD', 'EUR', 'RUB', 'KZT', 'AED'];

  List<ExchangeRate> _cbu = [];
  Map<String, ExchangeRate> _pboc = {};
  DateTime? _fetchedAt;
  bool _loading = false;
  String? _error;

  List<ExchangeRate> get cbu => _cbu;
  Map<String, ExchangeRate> get pboc => _pboc;
  DateTime? get fetchedAt => _fetchedAt;
  bool get loading => _loading;
  String? get error => _error;

  void reload() {
    _cbu = [
      for (final r in (_box.get('cbuRates') as List? ?? const []))
        ExchangeRate.fromJson(r as Map),
    ];
    _sortCbu();
    _pboc = {
      for (final r in (_box.get('pbocRates') as List? ?? const []))
        (r as Map)['code'] as String: ExchangeRate.fromJson(r),
    };
    final ms = _box.get('cbuFetchedAt') as int?;
    _fetchedAt = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    notifyListeners();
  }

  void _sortCbu() {
    int rank(String c) {
      final i = featured.indexOf(c);
      return i < 0 ? 999 : i;
    }

    _cbu.sort((a, b) {
      final r = rank(a.code).compareTo(rank(b.code));
      return r != 0 ? r : a.code.compareTo(b.code);
    });
  }

  /// Downloads fresh CBU rates. Keeps the cached ones if offline.
  Future<bool> refreshCbu() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rates = await _api.fetch();
      _cbu = rates;
      _sortCbu();
      _fetchedAt = DateTime.now();
      await _box.put('cbuRates', [for (final r in rates) r.toJson()]);
      await _box.put('cbuFetchedAt', _fetchedAt!.millisecondsSinceEpoch);
      return true;
    } catch (e) {
      _error = '$e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  ExchangeRate? cbuRate(String code) {
    for (final r in _cbu) {
      if (r.code == code) return r;
    }
    return null;
  }

  /// CNY per 1 unit of [code] derived from CBU (cross through UZS).
  double? cbuCrossToCny(String code) {
    final cny = cbuRate('CNY'), x = cbuRate(code);
    if (cny == null || x == null || cny.perUnit == 0) return null;
    return x.perUnit / cny.perUnit;
  }

  Future<void> setPboc(String code, double cnyPerUnit) async {
    if (cnyPerUnit <= 0) {
      _pboc.remove(code);
    } else {
      _pboc[code] = ExchangeRate(
        code: code,
        name: code,
        rate: cnyPerUnit,
        date: DateTime.now(),
      );
    }
    await _box.put('pbocRates', [for (final r in _pboc.values) r.toJson()]);
    notifyListeners();
  }

  /// Units of [c] per 1 USD for the calculators: PBOC rate for CNY when
  /// entered, otherwise the CBU cross rate. `null` when unknown.
  double? ratePerUsd(Currency c) {
    if (c == Currency.usd) return 1;
    if (c == Currency.cny) {
      final p = _pboc['USD'];
      if (p != null) return p.perUnit;
    }
    final usd = cbuRate('USD');
    if (usd == null) return null;
    if (c == Currency.uzs) return usd.perUnit;
    final other = cbuRate(c.code);
    if (other == null || other.perUnit == 0) return null;
    return usd.perUnit / other.perUnit;
  }

  Map<String, dynamic> toBackup() => {
    'pbocRates': [for (final r in _pboc.values) r.toJson()],
  };

  Future<void> restoreBackup(Map<dynamic, dynamic> m) async {
    if (!m.containsKey('pbocRates')) return;
    await _box.put('pbocRates', m['pbocRates'] ?? const []);
    reload();
  }
}
