import 'package:hive_flutter/hive_flutter.dart';

import '../models/price_quote.dart';

class QuoteRepository {
  QuoteRepository(this._box);

  final Box<Map> _box;

  List<PriceQuote> loadAll() {
    final result = <PriceQuote>[];
    for (final raw in _box.values) {
      try {
        result.add(PriceQuote.fromJson(raw));
      } catch (_) {}
    }
    return result;
  }

  Future<void> save(PriceQuote q) => _box.put(q.id, q.toJson());

  Future<void> delete(String id) => _box.delete(id);

  Future<void> replaceAll(Iterable<PriceQuote> quotes) async {
    await _box.clear();
    await _box.putAll({for (final q in quotes) q.id: q.toJson()});
  }
}
