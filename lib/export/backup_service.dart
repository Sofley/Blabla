import 'dart:convert';
import 'dart:typed_data';

import '../data/models/deal.dart';
import '../data/models/price_quote.dart';

/// Full backup of business data (deals, price quotes, defaults) as JSON.
/// Account credentials are never included.
class BackupService {
  const BackupService();

  static const format = 'b2b-ledger-backup';
  static const version = 2;

  Uint8List encode({
    required List<Deal> deals,
    required List<PriceQuote> quotes,
    required Map<String, dynamic> settings,
  }) {
    final data = {
      'format': format,
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'deals': [for (final d in deals) d.toJson()],
      'quotes': [for (final q in quotes) q.toJson()],
      'settings': settings,
    };
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
  }

  /// Throws [FormatException] when the file is not a valid backup.
  BackupContent decode(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const FormatException('Not a B2B Ledger backup');
    }
    return BackupContent(
      deals: [
        for (final d in (json['deals'] as List? ?? const []))
          Deal.fromJson(d as Map),
      ],
      quotes: [
        for (final q in (json['quotes'] as List? ?? const []))
          PriceQuote.fromJson(q as Map),
      ],
      settings: (json['settings'] as Map?) ?? const {},
    );
  }
}

class BackupContent {
  const BackupContent({
    required this.deals,
    required this.quotes,
    required this.settings,
  });

  final List<Deal> deals;
  final List<PriceQuote> quotes;
  final Map<dynamic, dynamic> settings;
}
