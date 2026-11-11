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

  /// New calculation with the approved defaults: agent 8 % of V, agent VAT
  /// not set, no extra VAT (the client price is final), profit 0.33 per
  /// unit, VAT refund 9 % of FOB with our share from the settings (0 %).
  PriceQuote createDraft({
    double agentPercent = 8,
    double? agentVatPercent,
    double vatPercent = 9,
    double vatRefundPercent = 9,
    double vatBonusShare = 0,
    double profitPerUnit = 0.33,
    String unit = '',
  }) {
    final now = DateTime.now();
    return PriceQuote(
      id: _uuid.v4(),
      agentPercent: agentPercent,
      agentVatPercent: agentVatPercent,
      vatEnabled: false,
      vatPercent: vatPercent,
      vatRefundPercent: vatRefundPercent,
      vatBonusShare: vatBonusShare,
      profitValue: profitPerUnit,
      profitMode: ProfitMode.amount,
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
