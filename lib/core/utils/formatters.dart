import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../data/models/currency.dart';

/// Locale-aware number, money and date formatting.
class Fmt {
  Fmt(this.locale);

  factory Fmt.of(BuildContext context) =>
      Fmt(Localizations.localeOf(context).toLanguageTag());

  final String locale;

  String money(double value, [Currency currency = kReportingCurrency]) {
    final f = NumberFormat.currency(
      locale: locale,
      symbol: currency.symbol,
      decimalDigits: 2,
    );
    return f.format(value);
  }

  /// Compact money for tight spaces (e.g. "$1.2K").
  String moneyCompact(double value, [Currency currency = kReportingCurrency]) {
    final f = NumberFormat.compactCurrency(
      locale: locale,
      symbol: currency.symbol,
      decimalDigits: value.abs() < 1000 ? 0 : 1,
    );
    return f.format(value);
  }

  String percent(double value) =>
      '${NumberFormat('#,##0.##', locale).format(value)}%';

  String date(DateTime d) => DateFormat.yMMMd(locale).format(d);

  String month(DateTime d) {
    final s = DateFormat.yMMMM(locale).format(d);
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  String monthShort(DateTime d) => DateFormat.MMM(locale).format(d);

  /// Plain decimal for editable fields (no grouping separators).
  static String editable(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// Parses user input, accepting both "," and "." and spaces as grouping.
  static double? parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned);
  }
}
