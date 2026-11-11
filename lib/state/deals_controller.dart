import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/contract_stage.dart';
import '../data/models/currency.dart';
import '../data/models/deal.dart';
import '../data/models/price_quote.dart';
import '../data/models/trade_contract.dart';
import '../data/repositories/deal_repository.dart';
import '../domain/price_calculator.dart';

class DealsController extends ChangeNotifier {
  DealsController(this._repo, {this.onEvent}) {
    _deals = _repo.loadAll();
    _sort();
  }

  final DealRepository _repo;

  /// Called with (dealId, code) for automatic status messages in the chat:
  /// `created`, `stage:<name>` or `deleted`.
  final void Function(String dealId, String code)? onEvent;
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

  /// Re-reads the storage (after restore or wipe).
  void reload() {
    _deals = _repo.loadAll();
    _sort();
    notifyListeners();
  }

  Future<void> replaceAll(List<Deal> deals) async {
    await _repo.replaceAll(deals);
    reload();
  }

  Deal createDraft({
    required String companyName,
    required double agencyFee,
    required double vat,
    double vatRefund = 9,
    String unit = '',
  }) {
    final now = DateTime.now();
    return Deal(
      id: _uuid.v4(),
      buyerContract: TradeContract.empty(
        ContractSide.buyer,
        intermediaryName: companyName,
        agencyFeePercent: agencyFee,
        vatPercent: vat,
        unit: unit,
      ),
      sellerContract: TradeContract.empty(
        ContractSide.seller,
        intermediaryName: companyName,
        agencyFeePercent: agencyFee,
        vatPercent: vat,
        vatRefundPercent: vatRefund,
        unit: unit,
      ),
      stageDates: {ContractStage.signed: now},
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Builds a deal whose two contracts reproduce the price calculation:
  /// Contract #1 sells at the computed price, Contract #2 buys at EXW with
  /// logistics, agent fee and VAT refund.
  Deal createFromQuote(PriceQuote q, {required String companyName}) {
    final b = PriceBreakdown(q);
    final draft = createDraft(
      companyName: companyName,
      agencyFee: q.agentPercent,
      vat: q.vatPercent,
      vatRefund: q.vatRefundPercent,
      unit: q.unit,
    );
    final rate = q.currency == Currency.usd ? 1.0 : q.ratePerUsd;
    final logisticsUsd = b.toUsd(b.logisticsTotal);
    return draft.copyWith(
      buyerContract: draft.buyerContract.copyWith(
        counterpartyName: q.buyerName,
        productName: q.productName,
        currency: q.currency,
        goodsRatePerUsd: rate,
        unitPrice: b.salePricePerUnit,
        quantity: q.quantity,
        agencyFeePercent: 0,
        vatEnabled: false,
        notes: q.notes,
      ),
      sellerContract: draft.sellerContract.copyWith(
        productName: q.productName,
        currency: q.currency,
        goodsRatePerUsd: rate,
        // A price per tonne stays per tonne in the factory contract.
        unitPrice: q.exwPerThousand ? q.exwPrice : b.goodsPerUnit,
        quantity: q.exwPerThousand ? q.quantity / 1000 : q.quantity,
        unit: q.exwPerThousand ? tonneUnit(q.unit) : q.unit,
        freightCost: logisticsUsd,
        logisticsCurrency: Currency.usd,
        logisticsRatePerUsd: 1,
        agencyFeePercent: q.agentPercent,
        // VAT on goods + logistics + agent, exactly as in the calculator.
        vatEnabled: q.vatEnabled,
        vatPercent: q.vatPercent,
        vatRefundEnabled: q.vatRefundEnabled,
        vatRefundPercent: q.vatRefundPercent,
        vatRefundBase: VatRefundBase.goods,
        vatBonusShare: q.vatBonusShare,
        vatBonusInProfit: q.vatBonusInProfit,
      ),
    );
  }

  Future<void> setVatRefundReceived(String id, bool received) async {
    final deal = byId(id);
    if (deal == null) return;
    await upsert(deal.copyWith(vatRefundReceived: received));
  }

  Future<void> upsert(Deal deal) async {
    final updated = deal.copyWith(updatedAt: DateTime.now());
    final i = _deals.indexWhere((d) => d.id == deal.id);
    if (i >= 0) {
      if (_deals[i].stage != updated.stage) {
        onEvent?.call(deal.id, 'stage:${updated.stage.name}');
      }
      _deals[i] = updated;
    } else {
      _deals.add(updated);
      onEvent?.call(deal.id, 'created');
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
    onEvent?.call(id, 'deleted');
  }

  void _sort() => _deals.sort((a, b) {
    final byDate = b.reportingDate.compareTo(a.reportingDate);
    return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
  });
}

/// Unit name for 1000 × [unit]: "т" for кг, "t" for kg, otherwise "1000 unit".
String tonneUnit(String unit) {
  final u = unit.trim().toLowerCase();
  if (u == 'кг') return 'т';
  if (u == 'kg') return 't';
  if (u == '公斤' || u == '千克') return '吨';
  return u.isEmpty ? '1000' : '1000 $unit';
}
