import 'contract_stage.dart';
import 'deal_document.dart';
import 'trade_contract.dart';

export 'deal_document.dart';

/// Contract scheme of a deal.
enum DealKind {
  /// Two separate contracts: Buyer ↔ Intermediary and Intermediary ↔ Seller.
  backToBack,

  /// One contract signed by Buyer, Seller (factory) and our company.
  threeParty,

  /// One two-party contract: Buyer ↔ Seller only (since v3.0). Our
  /// calculation stays internal, as in the three-party scheme.
  twoParty;

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

/// Calculation results frozen at a moment of the deal (signing or
/// closing), so later edits never silently change what was agreed.
class CalcSnapshot {
  const CalcSnapshot({
    required this.event,
    required this.at,
    required this.values,
  });

  /// `signed` or `closed`.
  final String event;
  final DateTime at;

  /// USD amounts: goods, logistics, agency, agentVat, purchaseVat,
  /// expenses, revenue, turnover, vatRefund, vatBonus, profit, margin,
  /// fx (when known).
  final Map<String, double> values;

  Map<String, dynamic> toJson() => {
    'event': event,
    'at': at.toIso8601String(),
    'values': values,
  };

  static CalcSnapshot? fromJson(Map<dynamic, dynamic> j) {
    final at = DateTime.tryParse(j['at'] as String? ?? '');
    if (at == null) return null;
    return CalcSnapshot(
      event: j['event'] as String? ?? 'signed',
      at: at,
      values: {
        for (final e in ((j['values'] as Map?) ?? const {}).entries)
          if (e.value is num) e.key as String: (e.value as num).toDouble(),
      },
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
    this.documents = const [],
    this.deliveryInfo = '',
    this.deletedAt,
    this.dealNumber = '',
    this.snapshots = const [],
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

  /// Dossier of the deal: official contract, invoices, annexes,
  /// supplementary agreements, corrections, other documents.
  final List<DealDocument> documents;

  /// Every stored file of the deal (all versions of all documents).
  Iterable<String> get fileIds sync* {
    for (final d in documents) {
      for (final v in d.versions) {
        yield v.fileId;
      }
    }
  }

  /// Delivery terms / logistics info visible to the client
  /// (route, terms, expected dates). Never contains internal costs.
  final String deliveryInfo;

  /// Set when the deal is in the trash.
  final DateTime? deletedAt;

  /// Number of the electronic deal, NT-YYYY-NNNN (assigned automatically,
  /// editable by hand).
  final String dealNumber;

  /// Calculation results frozen at signing and at closing.
  final List<CalcSnapshot> snapshots;

  bool get isDeleted => deletedAt != null;

  /// Date after which a deleted deal is removed for good.
  DateTime? get purgeAt => deletedAt?.add(const Duration(days: trashDays));

  bool get isThreeParty => kind == DealKind.threeParty;
  bool get isTwoParty => kind == DealKind.twoParty;

  /// One contract with the buyer (three-party or two-party) plus an
  /// internal calculation tab, instead of two separate contracts.
  bool get isSingleContract => isThreeParty || isTwoParty;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Deals are attributed to the month of the sales contract (#1).
  DateTime get reportingDate => buyerContract.date;

  /// The deal number when set, otherwise the contract numbers.
  String get displayTitle {
    if (dealNumber.trim().isNotEmpty) return dealNumber.trim();
    return contractNumbers;
  }

  /// Numbers of Contract #1 / Contract #2.
  String get contractNumbers {
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
    List<DealDocument>? documents,
    String? deliveryInfo,
    Object? deletedAt = kKeep,
    String? dealNumber,
    List<CalcSnapshot>? snapshots,
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
      documents: documents ?? this.documents,
      deliveryInfo: deliveryInfo ?? this.deliveryInfo,
      deletedAt: identical(deletedAt, kKeep)
          ? this.deletedAt
          : deletedAt as DateTime?,
      dealNumber: dealNumber ?? this.dealNumber,
      snapshots: snapshots ?? this.snapshots,
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
    'documents': [for (final d in documents) d.toJson()],
    'deliveryInfo': deliveryInfo,
    'deletedAt': deletedAt?.toIso8601String(),
    'dealNumber': dealNumber,
    'snapshots': [for (final x in snapshots) x.toJson()],
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
      documents: json['documents'] is List
          ? [
              for (final x in json['documents'] as List)
                if (x is Map) ?DealDocument.fromJson(x),
            ]
          : [
              // 3.0 test build: plain attachments → "other" documents.
              for (final a in (json['attachments'] as List?) ?? const [])
                if (a is Map) ?DealDocument.fromLegacyAttachment(a),
            ],
      deliveryInfo: json['deliveryInfo'] as String? ?? '',
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
      dealNumber: json['dealNumber'] as String? ?? '',
      snapshots: [
        for (final x in (json['snapshots'] as List?) ?? const [])
          if (x is Map) ?CalcSnapshot.fromJson(x),
      ],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
