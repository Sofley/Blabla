import 'contract_stage.dart';
import 'trade_contract.dart';

/// A back-to-back deal: two linked but strictly separate contracts.
class Deal {
  const Deal({
    required this.id,
    required this.buyerContract,
    required this.sellerContract,
    this.stage = ContractStage.signed,
    this.stageDates = const {},
    this.vatRefundReceived = false,
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
    DateTime? updatedAt,
  }) {
    return Deal(
      id: id,
      buyerContract: buyerContract ?? this.buyerContract,
      sellerContract: sellerContract ?? this.sellerContract,
      stage: stage ?? this.stage,
      stageDates: stageDates ?? this.stageDates,
      vatRefundReceived: vatRefundReceived ?? this.vatRefundReceived,
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
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
