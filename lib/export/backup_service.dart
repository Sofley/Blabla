import 'dart:convert';
import 'dart:typed_data';

import '../data/models/chat_message.dart';
import '../data/models/deal.dart';
import '../data/models/logistics_route.dart';
import '../data/models/price_quote.dart';

/// Full backup of business data (deals, price quotes, defaults) as JSON.
/// Account credentials are never included.
class BackupService {
  const BackupService();

  static const format = 'b2b-ledger-backup';
  static const version = 3;

  Uint8List encode({
    required List<Deal> deals,
    required List<PriceQuote> quotes,
    required Map<String, dynamic> settings,
    List<LogisticsRoute> routes = const [],
    List<ChatMessage> chat = const [],
  }) {
    final data = {
      'format': format,
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'deals': [for (final d in deals) d.toJson()],
      'quotes': [for (final q in quotes) q.toJson()],
      'settings': settings,
      'routes': [for (final r in routes) r.toJson()],
      'chat': [for (final m in chat) m.toJson()],
    };
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
  }

  /// Throws [FormatException] when the file is not a valid backup.
  BackupContent decode(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const FormatException('Not a NexusTrade backup');
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
      routes: [
        for (final r in (json['routes'] as List? ?? const []))
          LogisticsRoute.fromJson(r as Map),
      ],
      chat: [
        for (final m in (json['chat'] as List? ?? const []))
          ChatMessage.fromJson(m as Map),
      ],
      hasRoutes: json.containsKey('routes'),
    );
  }
}

class BackupContent {
  const BackupContent({
    required this.deals,
    required this.quotes,
    required this.settings,
    this.routes = const [],
    this.chat = const [],
    this.hasRoutes = false,
  });

  final List<Deal> deals;
  final List<PriceQuote> quotes;
  final Map<dynamic, dynamic> settings;
  final List<LogisticsRoute> routes;
  final List<ChatMessage> chat;

  /// Older backups have no tariff grid: keep the current one then.
  final bool hasRoutes;
}
