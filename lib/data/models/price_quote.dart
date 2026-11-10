import 'currency.dart';

/// Our own price calculation ("price builder"): the selling price is built
/// bottom-up from the EXW purchase price, logistics, agent fee and our markup.
/// All money fields are per unit in [currency].
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
    this.logisticsPerUnit = 0,
    this.agentPercent = 9,
    this.profitPerUnit = 0,
    this.vatRefundEnabled = true,
    this.vatRefundPercent = 9,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productName;
  final String buyerName;
  final double quantity;
  final String unit;
  final Currency currency;

  /// Units of [currency] per 1 USD.
  final double ratePerUsd;

  /// Delivery terms of the purchase price (EXW, FOB, FCA…).
  final String incoterms;

  /// Purchase price per unit at the factory.
  final double exwPrice;

  /// Delivery cost per unit.
  final double logisticsPerUnit;

  /// Agent fee, percent of the purchase price.
  final double agentPercent;

  /// Our markup per unit, included in the selling price.
  final double profitPerUnit;

  /// VAT refund paid back to the intermediary, percent of the purchase price.
  final bool vatRefundEnabled;
  final double vatRefundPercent;

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
    double? logisticsPerUnit,
    double? agentPercent,
    double? profitPerUnit,
    bool? vatRefundEnabled,
    double? vatRefundPercent,
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
    logisticsPerUnit: logisticsPerUnit ?? this.logisticsPerUnit,
    agentPercent: agentPercent ?? this.agentPercent,
    profitPerUnit: profitPerUnit ?? this.profitPerUnit,
    vatRefundEnabled: vatRefundEnabled ?? this.vatRefundEnabled,
    vatRefundPercent: vatRefundPercent ?? this.vatRefundPercent,
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
    'logisticsPerUnit': logisticsPerUnit,
    'agentPercent': agentPercent,
    'profitPerUnit': profitPerUnit,
    'vatRefundEnabled': vatRefundEnabled,
    'vatRefundPercent': vatRefundPercent,
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
      logisticsPerUnit: d('logisticsPerUnit', 0),
      agentPercent: d('agentPercent', 9),
      profitPerUnit: d('profitPerUnit', 0),
      vatRefundEnabled: j['vatRefundEnabled'] as bool? ?? true,
      vatRefundPercent: d('vatRefundPercent', 9),
      notes: j['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
