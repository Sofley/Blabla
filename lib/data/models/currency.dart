/// Supported currencies. Amounts are converted into the reporting
/// currency (USD) using the rate fixed on the contract signing date.
enum Currency {
  usd('USD', r'$'),
  eur('EUR', '€'),
  cny('CNY', '¥'),
  rub('RUB', '₽'),
  uzs('UZS', 'сўм'),
  kzt('KZT', '₸'),
  aed('AED', 'د.إ');

  const Currency(this.code, this.symbol);

  final String code;
  final String symbol;

  /// Indicative default: units of this currency per 1 USD.
  /// Always overridden by the user with the rate on the signing date.
  double get defaultRatePerUsd => switch (this) {
    Currency.usd => 1.0,
    Currency.eur => 0.92,
    Currency.cny => 7.20,
    Currency.rub => 95.0,
    Currency.uzs => 12800.0,
    Currency.kzt => 490.0,
    Currency.aed => 3.6725,
  };

  static Currency fromCode(String? code, {Currency fallback = Currency.usd}) {
    for (final c in Currency.values) {
      if (c.code == code) return c;
    }
    return fallback;
  }

  /// Currencies offered for logistics costs (freight is billed in hard currency).
  static const logistics = [Currency.usd, Currency.eur];
}

/// Reporting (base) currency of all analytics.
const Currency kReportingCurrency = Currency.usd;
