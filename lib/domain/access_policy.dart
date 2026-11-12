import '../data/models/app_user.dart';
import '../data/models/deal.dart';
import '../data/models/trade_contract.dart';

/// What the current user may see and do. Enforced in the data layer:
/// [DealsController] returns only deals that pass [canSee], already passed
/// through [redact], and refuses writes the role does not allow. Screens,
/// exports, analytics and the assistant therefore never receive internal
/// finance of a deal unless the user is the owner.
class AccessPolicy {
  const AccessPolicy({required this.role, this.userId, this.clientId});

  static const owner = AccessPolicy(role: UserRole.owner);

  factory AccessPolicy.forUser(AppUser? user) => user == null
      ? owner
      : AccessPolicy(role: user.role, userId: user.id, clientId: user.clientId);

  final UserRole role;
  final String? userId;

  /// For clients: the client record whose deals are visible.
  final String? clientId;

  bool get isOwner => role == UserRole.owner;

  /// Profit, agent fees, logistics costs, VAT refund, margin, internal
  /// reports, price calculator, monthly profit analytics, backups.
  bool get seesFinance => isOwner;

  /// Full deal editor (prices and contracts).
  bool get canEditDeals => isOwner;

  bool get canChangeStages =>
      isOwner || role == UserRole.admin || role == UserRole.manager;

  bool get canManageDocuments => canChangeStages;

  /// Move to / restore from the trash.
  bool get canDeleteDeals => isOwner || role == UserRole.admin;

  /// Permanent deletion from the trash.
  bool get canPurge => isOwner;

  bool get canManageUsers => isOwner || role == UserRole.admin;

  bool get canSeeClients =>
      isOwner || role == UserRole.admin || role == UserRole.manager;

  bool get canEditClients => isOwner || role == UserRole.admin;

  /// Contract #1 amount (what the buyer pays) — not internal, but the
  /// partner sees only basic info.
  bool get seesContractSums => role != UserRole.partner;

  bool get canUseChat =>
      isOwner || role == UserRole.admin || role == UserRole.manager;

  bool get canChangeSettings => isOwner;

  bool canSee(Deal d) => switch (role) {
    UserRole.owner || UserRole.admin => true,
    UserRole.manager ||
    UserRole.partner => userId != null && d.assignedUserIds.contains(userId),
    UserRole.client => clientId != null && d.clientId == clientId,
  };

  /// Copy of [d] without anything the role may not see. Money fields of
  /// the purchase side, logistics, agent fees, VAT refund, margin and
  /// internal notes are removed for every role except the owner.
  Deal redact(Deal d) {
    if (seesFinance) return d;
    TradeContract strip(TradeContract c, {required bool keepPrice}) =>
        TradeContract(
          side: c.side,
          number: c.number,
          date: c.date,
          counterpartyName: c.counterpartyName,
          intermediaryName: c.intermediaryName,
          productName: c.productName,
          currency: c.currency,
          unitPrice: keepPrice ? c.unitPrice : 0,
          quantity: c.quantity,
          unit: c.unit,
          goodsRatePerUsd: keepPrice ? c.goodsRatePerUsd : 1,
          agencyFeePercent: 0,
          vatEnabled: keepPrice && c.vatEnabled,
          vatPercent: keepPrice ? c.vatPercent : 0,
          vatRefundEnabled: false,
          vatRefundPercent: 0,
          vatBonusShare: 0,
          vatBonusInProfit: false,
        );
    // In a two- or three-party contract the seller is a party the client
    // knows; in back-to-back the factory contract is internal.
    final hideFactory = role == UserRole.client && !d.isSingleContract;
    final seller = strip(d.sellerContract, keepPrice: false);
    return Deal(
      id: d.id,
      buyerContract: strip(d.buyerContract, keepPrice: seesContractSums),
      // In a back-to-back deal the factory contract is internal: a client
      // does not even see who the factory is.
      sellerContract: hideFactory
          ? TradeContract(
              side: ContractSide.seller,
              date: d.sellerContract.date,
            )
          : seller,
      stage: d.stage,
      stageDates: d.stageDates,
      kind: d.kind,
      role: d.role,
      clientId: d.clientId,
      assignedUserIds: isOwner || role == UserRole.admin
          ? d.assignedUserIds
          : const [],
      stageHistory: d.stageHistory,
      attachments: canManageDocuments ? d.attachments : const [],
      deliveryInfo: d.deliveryInfo,
      deletedAt: d.deletedAt,
      dealNumber: d.dealNumber,
      // Calculation snapshots are internal finance: never copied.
      createdAt: d.createdAt,
      updatedAt: d.updatedAt,
    );
  }
}
