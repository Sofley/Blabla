import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/price_quote.dart';
import '../data/repositories/quote_repository.dart';

class QuotesController extends ChangeNotifier {
  QuotesController(this._repo) {
    reload();
  }

  final QuoteRepository _repo;
  static const _uuid = Uuid();

  List<PriceQuote> _quotes = [];

  /// Most recently edited first.
  List<PriceQuote> get quotes => List.unmodifiable(_quotes);

  PriceQuote? byId(String id) {
    for (final q in _quotes) {
      if (q.id == id) return q;
    }
    return null;
  }

  void reload() {
    _quotes = _repo.loadAll()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  PriceQuote createDraft({
    double agentPercent = 9,
    double vatPercent = 9,
    double vatRefundPercent = 9,
    String unit = '',
  }) {
    final now = DateTime.now();
    return PriceQuote(
      id: _uuid.v4(),
      agentPercent: agentPercent,
      vatEnabled: true,
      vatPercent: vatPercent,
      vatRefundPercent: vatRefundPercent,
      unit: unit,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> upsert(PriceQuote q) async {
    final updated = q.copyWith(updatedAt: DateTime.now());
    _quotes
      ..removeWhere((e) => e.id == q.id)
      ..insert(0, updated);
    notifyListeners();
    await _repo.save(updated);
  }

  Future<void> delete(String id) async {
    _quotes.removeWhere((q) => q.id == id);
    notifyListeners();
    await _repo.delete(id);
  }

  Future<void> replaceAll(List<PriceQuote> quotes) async {
    await _repo.replaceAll(quotes);
    reload();
  }
}
