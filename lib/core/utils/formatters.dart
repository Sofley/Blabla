import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../data/models/currency.dart';

/// Locale-aware number, money and date formatting.
class Fmt {
  /// [tag] may contain a script ("uz-Cyrl", "sr-Latn", "zh-Hans"); it is
  /// reduced to a locale that intl has number and date data for.
  Fmt(String tag) : locale = _verified(tag);

  static String _verified(String tag) {
    final canonical = tag.replaceAll('-', '_');
    bool dateOk(String l) {
      try {
        return DateFormat.localeExists(l);
      } catch (_) {
        // Date symbols not loaded yet (initializeDateFormatting): only the
        // built-in English data is available.
        return l.startsWith('en');
      }
    }

    bool ok(String l) => NumberFormat.localeExists(l) && dateOk(l);
    for (final candidate in [canonical, canonical.split('_').first]) {
      if (ok(candidate)) return candidate;
    }
    return 'en';
  }

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

  /// Unit price with up to 4 decimals (e.g. 0,0135 \$).
  String price(double value, Currency currency, {bool symbol = true}) {
    final n = NumberFormat('#,##0.00##', locale).format(value);
    if (!symbol) return n;
    final sym = currency.symbol;
    return locale.startsWith('ru') ? '$n $sym' : '$sym$n';
  }

  String number(double value) => NumberFormat('#,##0.##', locale).format(value);

  /// "14:05" for today, otherwise a short date.
  String timeOrDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return DateFormat.Hm(locale).format(d);
    }
    return DateFormat.MMMd(locale).format(d);
  }

  String dateTime(DateTime d) => DateFormat.yMd(locale).add_Hm().format(d);

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

  /// Like [editable] for optional amounts: null → empty field ("not set"),
  /// 0 → "0" (a confirmed zero stays visible).
  static String editableOpt(double? v) {
    if (v == null) return '';
    if (v == 0) return '0';
    return editable(v);
  }

  /// Parses an optional amount: empty input → null ("not set").
  static double? parseOpt(String input) {
    if (input.replaceAll(RegExp(r'[\s ]'), '').isEmpty) return null;
    return parse(input);
  }

  /// Parses user input, accepting both "," and "." and spaces as grouping.
  static double? parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned);
  }
}
