import 'currency.dart';

/// How step 6 ("my profit / my commission") is entered.
enum ProfitMode {
  /// Fixed amount per unit.
  amount,

  /// Commission, % of the cost (steps 1–5).
  percent,

  /// The final price for the buyer is given; profit is what remains.
  salePrice;

  static ProfitMode fromName(String? n) =>
      ProfitMode.values.firstWhere((m) => m.name == n, orElse: () => amount);
}

/// Our own price calculation ("price builder"). The selling price is built
/// step by step, in this order:
///   1. goods price (EXW) per unit
///   2. quantity / volume
///   3. logistics (per unit or for the whole batch)
///   4. agent commission, % of the goods price
///   5. VAT, % of goods + logistics + agent
///   6. my profit / my commission (amount per unit or % of steps 1–5)
/// plus an optional VAT refund paid back to the intermediary.
/// Money fields are in [currency].
class PriceQuote {
  const PriceQuote({
    required this.id,
    this.productName = '',
    this.buyerName = '',
    this.quantity = 1,
    this.unit = '',
    this.currency = Currency.usd,
    this.ratePerUsd = 1,
    this.incoterms = 'EXW',
    this.exwPrice = 0,
    this.exwPerThousand = false,
    this.logisticsValue = 0,
    this.logisticsIsTotal = false,
    this.agentPercent = 9,
    this.vatEnabled = false,
    this.vatPercent = 9,
    this.profitValue = 0,
    this.profitMode = ProfitMode.amount,
    this.vatRefundEnabled = true,
    this.vatRefundPercent = 9,
    this.vatBonusShare = 50,
    this.vatBonusInProfit = false,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productName;
  final String buyerName;

  /// Quantity / volume of goods.
  final double quantity;
  final String unit;
  final Currency currency;

  /// Units of [currency] per 1 USD.
  final double ratePerUsd;

  /// Delivery terms of the purchase price (EXW, FOB, FCA…).
  final String incoterms;

  /// 1. Purchase price at the factory: per unit, or per 1000 units
  /// (per tonne when the unit is kg) when [exwPerThousand].
  final double exwPrice;
  final bool exwPerThousand;

  /// 3. Logistics: per unit, or for the whole batch when [logisticsIsTotal].
  final double logisticsValue;
  final bool logisticsIsTotal;

  /// 4. Agent commission, percent of the purchase price.
  final double agentPercent;

  /// 5. VAT charged in the price, percent of goods + logistics + agent.
  final bool vatEnabled;
  final double vatPercent;

  /// 6. My profit / my commission: amount per unit, percent of the cost
  /// (steps 1–5), or the buyer's price per unit — see [profitMode].
  final double profitValue;
  final ProfitMode profitMode;

  bool get profitIsPercent => profitMode == ProfitMode.percent;

  /// VAT refund paid back to the intermediary, percent of the purchase price.
  final bool vatRefundEnabled;
  final double vatRefundPercent;

  /// Our share of the refund (0–100 %) and whether it counts as profit.
  final double vatBonusShare;
  final bool vatBonusInProfit;

  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PriceQuote copyWith({
    String? productName,
    String? buyerName,
    double? quantity,
    String? unit,
    Currency? currency,
    double? ratePerUsd,
    String? incoterms,
    double? exwPrice,
    bool? exwPerThousand,
    double? logisticsValue,
    bool? logisticsIsTotal,
    double? agentPercent,
    bool? vatEnabled,
    double? vatPercent,
    double? profitValue,
    ProfitMode? profitMode,
    bool? vatRefundEnabled,
    double? vatRefundPercent,
    double? vatBonusShare,
    bool? vatBonusInProfit,
    String? notes,
    DateTime? updatedAt,
  }) => PriceQuote(
    id: id,
    productName: productName ?? this.productName,
    buyerName: buyerName ?? this.buyerName,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    currency: currency ?? this.currency,
    ratePerUsd: ratePerUsd ?? this.ratePerUsd,
    incoterms: incoterms ?? this.incoterms,
    exwPrice: exwPrice ?? this.exwPrice,
    exwPerThousand: exwPerThousand ?? this.exwPerThousand,
    logisticsValue: logisticsValue ?? this.logisticsValue,
    logisticsIsTotal: logisticsIsTotal ?? this.logisticsIsTotal,
    agentPercent: agentPercent ?? this.agentPercent,
    vatEnabled: vatEnabled ?? this.vatEnabled,
    vatPercent: vatPercent ?? this.vatPercent,
    profitValue: profitValue ?? this.profitValue,
    profitMode: profitMode ?? this.profitMode,
    vatRefundEnabled: vatRefundEnabled ?? this.vatRefundEnabled,
    vatRefundPercent: vatRefundPercent ?? this.vatRefundPercent,
    vatBonusShare: vatBonusShare ?? this.vatBonusShare,
    vatBonusInProfit: vatBonusInProfit ?? this.vatBonusInProfit,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productName': productName,
    'buyerName': buyerName,
    'quantity': quantity,
    'unit': unit,
    'currency': currency.code,
    'ratePerUsd': ratePerUsd,
    'incoterms': incoterms,
    'exwPrice': exwPrice,
    'exwPerThousand': exwPerThousand,
    'logisticsValue': logisticsValue,
    'logisticsIsTotal': logisticsIsTotal,
    'agentPercent': agentPercent,
    'vatEnabled': vatEnabled,
    'vatPercent': vatPercent,
    'profitValue': profitValue,
    'profitMode': profitMode.name,
    'vatRefundEnabled': vatRefundEnabled,
    'vatRefundPercent': vatRefundPercent,
    'vatBonusShare': vatBonusShare,
    'vatBonusInProfit': vatBonusInProfit,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PriceQuote.fromJson(Map<dynamic, dynamic> j) {
    double d(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
    final now = DateTime.now();
    return PriceQuote(
      id: j['id'] as String,
      productName: j['productName'] as String? ?? '',
      buyerName: j['buyerName'] as String? ?? '',
      quantity: d('quantity', 1),
      unit: j['unit'] as String? ?? '',
      currency: Currency.fromCode(j['currency'] as String?),
      ratePerUsd: d('ratePerUsd', 1),
      incoterms: j['incoterms'] as String? ?? 'EXW',
      exwPrice: d('exwPrice', 0),
      exwPerThousand: j['exwPerThousand'] as bool? ?? false,
      // v1.1 stored "logisticsPerUnit" / "profitPerUnit".
      logisticsValue: d('logisticsValue', d('logisticsPerUnit', 0)),
      logisticsIsTotal: j['logisticsIsTotal'] as bool? ?? false,
      agentPercent: d('agentPercent', 9),
      vatEnabled: j['vatEnabled'] as bool? ?? false,
      vatPercent: d('vatPercent', 9),
      profitValue: d('profitValue', d('profitPerUnit', 0)),
      profitMode: j['profitMode'] != null
          ? ProfitMode.fromName(j['profitMode'] as String?)
          : (j['profitIsPercent'] == true
                ? ProfitMode.percent
                : ProfitMode.amount),
      vatRefundEnabled: j['vatRefundEnabled'] as bool? ?? true,
      vatRefundPercent: d('vatRefundPercent', 9),
      // Quotes saved before v2.1 counted the whole refund as profit.
      vatBonusShare: d('vatBonusShare', 100),
      vatBonusInProfit: j['vatBonusInProfit'] as bool? ?? true,
      notes: j['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
