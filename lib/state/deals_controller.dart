import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/contract_stage.dart';
import '../data/models/deal.dart';
import '../data/models/trade_contract.dart';
import '../data/repositories/deal_repository.dart';

class DealsController extends ChangeNotifier {
  DealsController(this._repo) {
    _deals = _repo.loadAll();
    _sort();
  }

  final DealRepository _repo;
  static const _uuid = Uuid();

  late List<Deal> _deals;

  /// All deals, newest sales contract first.
  List<Deal> get deals => List.unmodifiable(_deals);

  Deal? byId(String id) {
    for (final d in _deals) {
      if (d.id == id) return d;
    }
    return null;
  }

  Deal createDraft({
    required String companyName,
    required double agencyFee,
    required double vat,
  }) {
    final now = DateTime.now();
    return Deal(
      id: _uuid.v4(),
      buyerContract: TradeContract.empty(
        ContractSide.buyer,
        intermediaryName: companyName,
        agencyFeePercent: agencyFee,
        vatPercent: vat,
      ),
      sellerContract: TradeContract.empty(
        ContractSide.seller,
        intermediaryName: companyName,
        agencyFeePercent: agencyFee,
        vatPercent: vat,
      ),
      stageDates: {ContractStage.signed: now},
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> upsert(Deal deal) async {
    final updated = deal.copyWith(updatedAt: DateTime.now());
    final i = _deals.indexWhere((d) => d.id == deal.id);
    if (i >= 0) {
      _deals[i] = updated;
    } else {
      _deals.add(updated);
    }
    _sort();
    notifyListeners();
    await _repo.save(updated);
  }

  Future<void> setStage(String id, ContractStage stage) async {
    final deal = byId(id);
    if (deal == null || deal.stage == stage) return;
    await upsert(deal.withStage(stage));
  }

  Future<void> delete(String id) async {
    _deals.removeWhere((d) => d.id == id);
    notifyListeners();
    await _repo.delete(id);
  }

  void _sort() => _deals.sort((a, b) {
    final byDate = b.reportingDate.compareTo(a.reportingDate);
    return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
  });
}
