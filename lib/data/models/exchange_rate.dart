/// Official rate of a currency against the bank's base currency
/// (UZS for CBU, CNY for PBOC).
class ExchangeRate {
  const ExchangeRate({
    required this.code,
    required this.name,
    required this.rate,
    this.nominal = 1,
    this.diff = 0,
    required this.date,
  });

  final String code;
  final String name;

  /// Base-currency units per [nominal] units of [code].
  final double rate;
  final double nominal;

  /// Change against the previous day.
  final double diff;
  final DateTime date;

  /// Base-currency units per 1 unit of [code].
  double get perUnit => nominal > 0 ? rate / nominal : rate;

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'rate': rate,
    'nominal': nominal,
    'diff': diff,
    'date': date.toIso8601String(),
  };

  factory ExchangeRate.fromJson(Map<dynamic, dynamic> j) => ExchangeRate(
    code: j['code'] as String,
    name: j['name'] as String? ?? '',
    rate: (j['rate'] as num).toDouble(),
    nominal: (j['nominal'] as num?)?.toDouble() ?? 1,
    diff: (j['diff'] as num?)?.toDouble() ?? 0,
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
  );
}
