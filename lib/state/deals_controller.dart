import 'package:flutter/foundation.dart';

import 'package:uuid/uuid.dart';

import '../data/models/contract_stage.dart';
import '../data/models/currency.dart';
import '../data/models/deal.dart';
import '../data/models/price_quote.dart';
import '../data/models/trade_contract.dart';
import '../data/repositories/deal_repository.dart';
import '../data/storage/attachment_store.dart';
import '../domain/access_policy.dart';
import '../domain/price_calculator.dart';

/// Deals of the current user. Every read goes through the [AccessPolicy]
/// (only visible deals, internal finance removed for non-owners) and every
/// write is checked against it, so no screen, export or report can obtain
/// data the role may not see.
class DealsController extends ChangeNotifier {
  DealsController(
    this._repo, {
    this.onEvent,
    AccessPolicy Function()? policy,
    String Function()? actor,
    AttachmentStore? attachments,
  }) : _policy = policy ?? (() => AccessPolicy.owner),
       _actor = actor ?? (() => ''),
       _files = attachments ?? MemoryAttachmentStore() {
    _deals = _repo.loadAll();
    _sort();
  }

  final DealRepository _repo;
  final AccessPolicy Function() _policy;
  final String Function() _actor;
  final AttachmentStore _files;

  /// Called with (dealId, code) for automatic status messages in the chat:
  /// `created`, `stage:<name>`, `trashed`, `restored` or `deleted`.
  final void Function(String dealId, String code)? onEvent;
  static const _uuid = Uuid();

  late List<Deal> _deals;

  AccessPolicy get policy => _policy();

  /// Active deals visible to the current user (newest first), with the
  /// fields the role may not see removed.
  List<Deal> get deals {
    final p = policy;
    return List.unmodifiable([
      for (final d in _deals)
        if (!d.isDeleted && p.canSee(d)) p.redact(d),
    ]);
  }

  /// Deals in the trash (owner and administrator only).
  List<Deal> get trash {
    final p = policy;
    if (!p.canDeleteDeals) return const [];
    return List.unmodifiable([
      for (final d in _deals)
        if (d.isDeleted && p.canSee(d)) p.redact(d),
    ]);
  }

  /// Every record including the trash, unredacted — for the owner's
  /// encrypted backup only.
  List<Deal> rawForBackup() {
    if (!policy.seesFinance) throw StateError('forbidden');
    return List.unmodifiable(_deals);
  }

  Deal? _raw(String id) {
    for (final d in _deals) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// A visible (redacted) deal, including deals in the trash.
  Deal? byId(String id) {
    final d = _raw(id);
    final p = policy;
    if (d == null || !p.canSee(d)) return null;
    if (d.isDeleted && !p.canDeleteDeals) return null;
    return p.redact(d);
  }

  /// Called when the user (and so the access policy) changes.
  void onSessionChanged() => notifyListeners();

  /// Re-reads the storage (after restore or wipe).
  void reload() {
    _deals = _repo.loadAll();
    _sort();
    notifyListeners();
  }

  /// Restore from a backup (owner only).
  Future<void> replaceAll(List<Deal> deals) async {
    if (!policy.seesFinance) throw StateError('forbidden');
    await _repo.replaceAll(deals);
    reload();
  }

  void _require(bool allowed) {
    if (!allowed) throw StateError('forbidden');
  }

  Deal createDraft({
    required String companyName,
    double agencyFee = 8,
    double? agentVat,
    double vat = 9,
    double vatRefund = 9,
    double vatShare = 0,
    double profitPerUnit = 0.33,
    String unit = '',
  }) {
    final now = DateTime.now();
    return Deal(
      id: _uuid.v4(),
      buyerContract: TradeContract.empty(
        ContractSide.buyer,
        intermediaryName: companyName,
        // The buyer contract carries no agent fee.
        agencyFeePercent: 0,
        vatPercent: vat,
        unit: unit,
      ),
      sellerContract: TradeContract.empty(
        ContractSide.seller,
        intermediaryName: companyName,
        agencyFeePercent: agencyFee,
        agentVatPercent: agentVat,
        vatPercent: vat,
        vatRefundPercent: vatRefund,
        vatBonusShare: vatShare,
        unit: unit,
      ),
      stageDates: {ContractStage.signed: now},
      stageHistory: [
        StageEvent(stage: ContractStage.signed, at: now, by: _actor()),
      ],
      pricingMode: PricingMode.profitPerUnit,
      marginValue: profitPerUnit,
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
      agentVat: q.agentVatPercent,
      vat: q.vatPercent,
      vatRefund: q.vatRefundPercent,
      vatShare: q.vatBonusShare,
      unit: q.unit,
    );
    final rate = q.currency == Currency.usd ? 1.0 : q.ratePerUsd;
    final logisticsUsd = b.logisticsUnset ? null : b.toUsd(b.logisticsTotal);
    return draft.copyWith(
      // The price is fixed by the calculation.
      pricingMode: PricingMode.manual,
      marginValue: 0,
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
        agencyBase: q.agentBase,
        agentVatPercent: q.agentVatPercent,
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
    final deal = _raw(id);
    if (deal == null) return;
    await upsert(deal.copyWith(vatRefundReceived: received));
  }

  /// Saves a deal from the full editor (owner only).
  Future<void> upsert(Deal deal) async {
    _require(policy.canEditDeals);
    await _save(deal);
  }

  Future<void> _save(Deal deal) async {
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

  Deal _visibleRaw(String id) {
    final d = _raw(id);
    if (d == null || !policy.canSee(d)) throw StateError('not found');
    return d;
  }

  Future<void> setStage(String id, ContractStage stage) async {
    _require(policy.canChangeStages);
    final deal = _visibleRaw(id);
    if (deal.stage == stage) return;
    await _save(deal.withStage(stage, by: _actor()));
  }

  Future<void> setDeliveryInfo(String id, String info) async {
    _require(policy.canChangeStages);
    await _save(_visibleRaw(id).copyWith(deliveryInfo: info.trim()));
  }

  Future<void> setClient(String id, String? clientId) async {
    _require(policy.canEditClients);
    await _save(_visibleRaw(id).copyWith(clientId: clientId));
  }

  Future<void> setAssignees(String id, List<String> userIds) async {
    _require(policy.canManageUsers);
    await _save(_visibleRaw(id).copyWith(assignedUserIds: userIds));
  }

  // ---------- Documents ----------

  Future<void> addAttachment(
    String dealId,
    String name,
    List<int> bytes,
  ) async {
    _require(policy.canManageDocuments);
    final deal = _visibleRaw(dealId);
    final a = DealAttachment(
      id: _uuid.v4(),
      name: name,
      size: bytes.length,
      addedAt: DateTime.now(),
      addedBy: _actor(),
    );
    await _files.write(a.id, bytes);
    await _save(deal.copyWith(attachments: [...deal.attachments, a]));
  }

  Future<Uint8List?> readAttachment(String dealId, String attachmentId) async {
    _require(policy.canManageDocuments);
    final deal = _visibleRaw(dealId);
    if (!deal.attachments.any((a) => a.id == attachmentId)) return null;
    return _files.read(attachmentId);
  }

  Future<void> removeAttachment(String dealId, String attachmentId) async {
    _require(policy.canManageDocuments);
    final deal = _visibleRaw(dealId);
    await _save(
      deal.copyWith(
        attachments: [
          for (final a in deal.attachments)
            if (a.id != attachmentId) a,
        ],
      ),
    );
    await _files.delete(attachmentId);
  }

  /// Raw file of a document for the owner's backup.
  Future<Uint8List?> attachmentForBackup(String attachmentId) {
    _require(policy.seesFinance);
    return _files.read(attachmentId);
  }

  /// Restores document files from a backup (owner only).
  Future<void> restoreAttachmentFiles(Map<String, List<int>> files) async {
    _require(policy.seesFinance);
    await _files.deleteAll();
    for (final e in files.entries) {
      await _files.write(e.key, e.value);
    }
  }

  // ---------- Trash ----------

  /// Moves the deal to the trash; it is deleted for good after
  /// [Deal.trashDays] days unless restored.
  Future<void> delete(String id) async {
    _require(policy.canDeleteDeals);
    final deal = _visibleRaw(id);
    await _save(deal.copyWith(deletedAt: DateTime.now()));
    onEvent?.call(id, 'trashed');
  }

  Future<void> restore(String id) async {
    _require(policy.canDeleteDeals);
    final deal = _visibleRaw(id);
    await _save(deal.copyWith(deletedAt: null));
    onEvent?.call(id, 'restored');
  }

  /// Deletes a deal from the trash for good, with its documents and chat.
  Future<void> purge(String id) async {
    _require(policy.canPurge);
    final deal = _visibleRaw(id);
    if (!deal.isDeleted) throw StateError('not in trash');
    await _purge(deal);
  }

  /// Removes deals whose 15 days in the trash are over. Runs at start-up
  /// for any user (it only applies the retention rule).
  Future<int> purgeExpired({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final expired = [
      for (final d in _deals)
        if (d.purgeAt != null && !d.purgeAt!.isAfter(t)) d,
    ];
    for (final d in expired) {
      await _purge(d);
    }
    return expired.length;
  }

  Future<void> _purge(Deal deal) async {
    for (final a in deal.attachments) {
      await _files.delete(a.id);
    }
    _deals.removeWhere((d) => d.id == deal.id);
    notifyListeners();
    await _repo.delete(deal.id);
    onEvent?.call(deal.id, 'deleted');
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
