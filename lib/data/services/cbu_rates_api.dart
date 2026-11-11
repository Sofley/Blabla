import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/exchange_rate.dart';

/// Official exchange rates of the Central Bank of Uzbekistan (cbu.uz).
/// Public JSON, no key needed. Rates are in UZS per [nominal] units.
class CbuRatesApi {
  CbuRatesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final endpoint = Uri.parse(
    'https://cbu.uz/ru/arkhiv-kursov-valyut/json/',
  );

  Future<List<ExchangeRate>> fetch() async {
    final res = await _client
        .get(endpoint, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', endpoint);
    }
    return parse(utf8.decode(res.bodyBytes));
  }

  /// Parses the cbu.uz JSON array (numbers come as strings, date dd.MM.yyyy).
  static List<ExchangeRate> parse(String body) {
    final data = jsonDecode(body) as List<dynamic>;
    double num(Object? v) =>
        double.tryParse('${v ?? ''}'.replaceAll(',', '.').trim()) ?? 0;
    return [
      for (final raw in data.cast<Map<String, dynamic>>())
        if (num(raw['Rate']) > 0)
          ExchangeRate(
            code: '${raw['Ccy']}',
            name: '${raw['CcyNm_RU'] ?? raw['Ccy']}',
            rate: num(raw['Rate']),
            nominal: num(raw['Nominal']) == 0 ? 1 : num(raw['Nominal']),
            diff: num(raw['Diff']),
            date: _date('${raw['Date'] ?? ''}'),
          ),
    ];
  }

  static DateTime _date(String s) {
    final p = s.split('.');
    if (p.length == 3) {
      final d = int.tryParse(p[0]),
          m = int.tryParse(p[1]),
          y = int.tryParse(p[2]);
      if (d != null && m != null && y != null) return DateTime(y, m, d);
    }
    return DateTime.now();
  }
}
