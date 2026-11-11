import 'contract_stage.dart';
import 'trade_contract.dart';

/// Contract scheme of a deal.
enum DealKind {
  /// Two separate contracts: Buyer ↔ Intermediary and Intermediary ↔ Seller.
  backToBack,

  /// One contract signed by Buyer, Seller (factory) and our company.
  threeParty;

  static DealKind fromName(String? n) =>
      DealKind.values.firstWhere((k) => k.name == n, orElse: () => backToBack);
}

/// Legal role of our company in a three-party contract.
enum CompanyRole {
  /// Buys the goods in its own name and imports them.
  buyerImporter,

  /// Factory ↔ buyer contract, our company pays (named "Payer").
  payer,

  /// Agency scheme: principal / commission agent.
  principalAgent;

  static CompanyRole fromName(String? n) =>
      CompanyRole.values.firstWhere((r) => r.name == n, orElse: () => payer);
}

/// How the buyer's contract price is set.
enum PricingMode {
  /// Price per unit typed by hand.
  manual,

  /// Our margin as % of the factory amount; the price is calculated.
  marginPercent,

  /// Our margin as a fixed sum (USD); the price is calculated.
  marginAmount,

  /// Our profit per unit of Contract #1 (USD, e.g. 0.33 $/kg); the price
  /// is calculated from the full cost of Contract #2.
  profitPerUnit;

  static PricingMode fromName(String? n) =>
      PricingMode.values.firstWhere((m) => m.name == n, orElse: () => manual);
}

/// A document attached to a deal. The file itself is stored encrypted
/// (see AttachmentStore); only metadata lives in the deal record.
class DealAttachment {
  const DealAttachment({
    required this.id,
    required this.name,
    required this.size,
    required this.addedAt,
    this.addedBy = '',
  });

  final String id;
  final String name;
  final int size;
  final DateTime addedAt;
  final String addedBy;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'addedAt': addedAt.toIso8601String(),
    'addedBy': addedBy,
  };

  static DealAttachment? fromJson(Map<dynamic, dynamic> j) {
    final id = j['id'] as String?;
    if (id == null) return null;
    return DealAttachment(
      id: id,
      name: j['name'] as String? ?? id,
      size: (j['size'] as num?)?.toInt() ?? 0,
      addedAt:
          DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
      addedBy: j['addedBy'] as String? ?? '',
    );
  }
}

/// A back-to-back deal: two linked but strictly separate contracts.
class Deal {
  const Deal({
    required this.id,
    required this.buyerContract,
    required this.sellerContract,
    this.stage = ContractStage.signed,
    this.stageDates = const {},
    this.vatRefundReceived = false,
    this.kind = DealKind.backToBack,
    this.role = CompanyRole.payer,
    this.pricingMode = PricingMode.manual,
    this.marginValue = 0,
    this.clientId,
    this.assignedUserIds = const [],
    this.stageHistory = const [],
    this.attachments = const [],
    this.deliveryInfo = '',
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Days a deleted deal stays in the trash before permanent deletion.
  static const trashDays = 15;

  final String id;

  /// Contract #1 — Buyer ↔ Intermediary.
  final TradeContract buyerContract;

  /// Contract #2 — Intermediary ↔ Seller / Manufacturer.
  final TradeContract sellerContract;

  final ContractStage stage;

  /// Date on which each stage was reached.
  final Map<ContractStage, DateTime> stageDates;

  /// Whether the VAT refund has actually been received by the intermediary.
  final bool vatRefundReceived;

  final DealKind kind;

  /// Our role (used in three-party contracts).
  final CompanyRole role;

  final PricingMode pricingMode;

  /// % of the factory amount, USD sum or USD per unit, depending on
  /// [pricingMode].
  final double marginValue;

  /// Client from the directory (the buyer of Contract #1).
  final String? clientId;

  /// Local users (manager / partner) the deal is assigned to.
  final List<String> assignedUserIds;

  /// Every stage change, oldest first (incl. names used before v3.0).
  final List<StageEvent> stageHistory;

  final List<DealAttachment> attachments;

  /// Delivery terms / logistics info visible to the client
  /// (route, terms, expected dates). Never contains internal costs.
  final String deliveryInfo;

  /// Set when the deal is in the trash.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Date after which a deleted deal is removed for good.
  DateTime? get purgeAt => deletedAt?.add(const Duration(days: trashDays));

  bool get isThreeParty => kind == DealKind.threeParty;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Deals are attributed to the month of the sales contract (#1).
  DateTime get reportingDate => buyerContract.date;

  String get displayTitle {
    final a = buyerContract.number.trim();
    final b = sellerContract.number.trim();
    if (a.isEmpty && b.isEmpty) return '—';
    if (b.isEmpty) return a;
    if (a.isEmpty) return b;
    return '$a / $b';
  }

  Deal copyWith({
    TradeContract? buyerContract,
    TradeContract? sellerContract,
    ContractStage? stage,
    Map<ContractStage, DateTime>? stageDates,
    bool? vatRefundReceived,
    DealKind? kind,
    CompanyRole? role,
    PricingMode? pricingMode,
    double? marginValue,
    Object? clientId = kKeep,
    List<String>? assignedUserIds,
    List<StageEvent>? stageHistory,
    List<DealAttachment>? attachments,
    String? deliveryInfo,
    Object? deletedAt = kKeep,
    DateTime? updatedAt,
  }) {
    return Deal(
      id: id,
      buyerContract: buyerContract ?? this.buyerContract,
      sellerContract: sellerContract ?? this.sellerContract,
      stage: stage ?? this.stage,
      stageDates: stageDates ?? this.stageDates,
      vatRefundReceived: vatRefundReceived ?? this.vatRefundReceived,
      kind: kind ?? this.kind,
      role: role ?? this.role,
      pricingMode: pricingMode ?? this.pricingMode,
      marginValue: marginValue ?? this.marginValue,
      clientId: identical(clientId, kKeep)
          ? this.clientId
          : clientId as String?,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
      stageHistory: stageHistory ?? this.stageHistory,
      attachments: attachments ?? this.attachments,
      deliveryInfo: deliveryInfo ?? this.deliveryInfo,
      deletedAt: identical(deletedAt, kKeep)
          ? this.deletedAt
          : deletedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Moves the deal to [newStage], keeping dates of reached stages only.
  /// The change is appended to [stageHistory]; nothing is ever removed
  /// from the history, even when a stage is rolled back.
  Deal withStage(ContractStage newStage, {DateTime? at, String by = ''}) {
    final now = at ?? DateTime.now();
    final dates = <ContractStage, DateTime>{};
    for (final s in ContractStage.values) {
      if (s.index > newStage.index) break;
      dates[s] = stageDates[s] ?? now;
    }
    return copyWith(
      stage: newStage,
      stageDates: dates,
      stageHistory: [
        ...stageHistory,
        StageEvent(stage: newStage, at: now, by: by),
      ],
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'buyerContract': buyerContract.toJson(),
    'sellerContract': sellerContract.toJson(),
    'stage': stage.name,
    'stageDates': {
      for (final e in stageDates.entries) e.key.name: e.value.toIso8601String(),
    },
    'vatRefundReceived': vatRefundReceived,
    'kind': kind.name,
    'role': role.name,
    'pricingMode': pricingMode.name,
    'marginValue': marginValue,
    'schema': kContractSchema,
    'clientId': clientId,
    'assignedUserIds': assignedUserIds,
    'stageHistory': [for (final e in stageHistory) e.toJson()],
    'attachments': [for (final a in attachments) a.toJson()],
    'deliveryInfo': deliveryInfo,
    'deletedAt': deletedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Deal.fromJson(Map<dynamic, dynamic> json) {
    final rawDates = (json['stageDates'] as Map?) ?? const {};
    final now = DateTime.now();
    // Stage dates: old stage names map onto the new stages; when two old
    // stages land on one new stage the earliest date wins.
    final dates = <ContractStage, DateTime>{};
    final legacyEvents = <StageEvent>[];
    for (final e in rawDates.entries) {
      final at = DateTime.tryParse(e.value as String? ?? '');
      if (at == null) continue;
      final name = e.key as String?;
      final stage = ContractStage.fromName(name);
      final prev = dates[stage];
      if (prev == null || at.isBefore(prev)) dates[stage] = at;
      legacyEvents.add(
        StageEvent(
          stage: stage,
          at: at,
          legacyName: ContractStage.isLegacyName(name) ? name : null,
        ),
      );
    }
    legacyEvents.sort((a, b) => a.at.compareTo(b.at));
    final rawHistory = json['stageHistory'] as List?;
    final history = rawHistory == null
        ? legacyEvents // v1–v2.1: rebuilt from the stored stage dates
        : [
            for (final e in rawHistory)
              if (e is Map) ?StageEvent.fromJson(e),
          ];
    return Deal(
      id: json['id'] as String,
      buyerContract: TradeContract.fromJson(
        json['buyerContract'] as Map<dynamic, dynamic>,
      ),
      sellerContract: TradeContract.fromJson(
        json['sellerContract'] as Map<dynamic, dynamic>,
      ),
      stage: ContractStage.fromName(json['stage'] as String?),
      stageDates: dates,
      stageHistory: history,
      vatRefundReceived: json['vatRefundReceived'] as bool? ?? false,
      kind: DealKind.fromName(json['kind'] as String?),
      role: CompanyRole.fromName(json['role'] as String?),
      pricingMode: PricingMode.fromName(json['pricingMode'] as String?),
      marginValue: (json['marginValue'] as num?)?.toDouble() ?? 0,
      clientId: json['clientId'] as String?,
      assignedUserIds: [
        for (final id in (json['assignedUserIds'] as List?) ?? const [])
          if (id is String) id,
      ],
      attachments: [
        for (final a in (json['attachments'] as List?) ?? const [])
          if (a is Map) ?DealAttachment.fromJson(a),
      ],
      deliveryInfo: json['deliveryInfo'] as String? ?? '',
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
