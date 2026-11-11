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
  marginAmount;

  static PricingMode fromName(String? n) =>
      PricingMode.values.firstWhere((m) => m.name == n, orElse: () => manual);
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
    required this.createdAt,
    required this.updatedAt,
  });

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

  /// % of the factory amount or USD sum, depending on [pricingMode].
  final double marginValue;

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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Moves the deal to [newStage], keeping dates of reached stages only.
  Deal withStage(ContractStage newStage, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final dates = <ContractStage, DateTime>{};
    for (final s in ContractStage.values) {
      if (s.index > newStage.index) break;
      dates[s] = stageDates[s] ?? now;
    }
    return copyWith(stage: newStage, stageDates: dates, updatedAt: now);
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
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Deal.fromJson(Map<dynamic, dynamic> json) {
    final rawDates = (json['stageDates'] as Map?) ?? const {};
    final now = DateTime.now();
    return Deal(
      id: json['id'] as String,
      buyerContract: TradeContract.fromJson(
        json['buyerContract'] as Map<dynamic, dynamic>,
      ),
      sellerContract: TradeContract.fromJson(
        json['sellerContract'] as Map<dynamic, dynamic>,
      ),
      stage: ContractStage.fromName(json['stage'] as String?),
      stageDates: {
        for (final e in rawDates.entries)
          if (DateTime.tryParse(e.value as String? ?? '') != null)
            ContractStage.fromName(e.key as String?): DateTime.parse(
              e.value as String,
            ),
      },
      vatRefundReceived: json['vatRefundReceived'] as bool? ?? false,
      kind: DealKind.fromName(json['kind'] as String?),
      role: CompanyRole.fromName(json['role'] as String?),
      pricingMode: PricingMode.fromName(json['pricingMode'] as String?),
      marginValue: (json['marginValue'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
