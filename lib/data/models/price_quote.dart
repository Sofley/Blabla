import 'currency.dart';
import 'trade_contract.dart'
    show AgencyBase, AgencyMode, LogisticsMethod, kKeep;

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
    this.logisticsValue,
    this.logisticsIsTotal = false,
    this.agentPercent = 8,
    this.agentBase = AgencyBase.goods,
    this.agentVatPercent,
    this.agentEnabled = true,
    this.agentMode = AgencyMode.percent,
    this.agentFixed,
    this.agentVatEnabled = false,
    this.logisticsMethod = LogisticsMethod.manual,
    this.transportTypeId,
    this.transportUnits,
    this.cargoTonnes,
    this.vatEnabled = false,
    this.vatPercent = 9,
    this.profitValue = 0,
    this.profitMode = ProfitMode.amount,
    this.vatRefundEnabled = true,
    this.vatRefundPercent = 9,
    this.vatBonusShare = 0,
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
  /// null = not entered («Не задано»), 0 = confirmed zero.
  final double? logisticsValue;
  final bool logisticsIsTotal;

  /// 4. Agent commission, percent of [agentBase]
  /// (V = goods + logistics since v3.0; goods only for older quotes).
  final double agentPercent;
  final AgencyBase agentBase;

  /// VAT of the agent on its fee; null = not set (no rate assumed).
  final double? agentVatPercent;

  /// Agent fee ON / OFF, percent of goods or a fixed sum for the batch
  /// (in [currency]; null = not set).
  final bool agentEnabled;
  final AgencyMode agentMode;
  final double? agentFixed;

  /// Agent VAT counted (ON / OFF).
  final bool agentVatEnabled;

  /// manual = per unit / for the batch ([logisticsIsTotal]); perTonne and
  /// perTransportUnit use [logisticsValue] as the rate.
  final LogisticsMethod logisticsMethod;
  final String? transportTypeId;
  final int? transportUnits;

  /// Weight in tonnes when the unit is neither t nor kg.
  final double? cargoTonnes;

  /// Weight of the batch in tonnes (from the unit or [cargoTonnes]).
  double? get tonnes {
    final u = unit.trim().toLowerCase();
    if (const {
      't',
      'т',
      'тонна',
      'тонн',
      'tn',
      'ton',
      'tonne',
      '吨',
    }.contains(u)) {
      return quantity;
    }
    if (const {'kg', 'кг', '公斤', '千克'}.contains(u)) return quantity / 1000;
    return cargoTonnes;
  }

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
    Object? logisticsValue = kKeep,
    bool? logisticsIsTotal,
    double? agentPercent,
    AgencyBase? agentBase,
    Object? agentVatPercent = kKeep,
    bool? agentEnabled,
    AgencyMode? agentMode,
    Object? agentFixed = kKeep,
    bool? agentVatEnabled,
    LogisticsMethod? logisticsMethod,
    Object? transportTypeId = kKeep,
    Object? transportUnits = kKeep,
    Object? cargoTonnes = kKeep,
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
    logisticsValue: identical(logisticsValue, kKeep)
        ? this.logisticsValue
        : (logisticsValue as num?)?.toDouble(),
    logisticsIsTotal: logisticsIsTotal ?? this.logisticsIsTotal,
    agentPercent: agentPercent ?? this.agentPercent,
    agentBase: agentBase ?? this.agentBase,
    agentEnabled: agentEnabled ?? this.agentEnabled,
    agentMode: agentMode ?? this.agentMode,
    agentFixed: identical(agentFixed, kKeep)
        ? this.agentFixed
        : (agentFixed as num?)?.toDouble(),
    agentVatEnabled: agentVatEnabled ?? this.agentVatEnabled,
    logisticsMethod: logisticsMethod ?? this.logisticsMethod,
    transportTypeId: identical(transportTypeId, kKeep)
        ? this.transportTypeId
        : transportTypeId as String?,
    transportUnits: identical(transportUnits, kKeep)
        ? this.transportUnits
        : (transportUnits as num?)?.toInt(),
    cargoTonnes: identical(cargoTonnes, kKeep)
        ? this.cargoTonnes
        : (cargoTonnes as num?)?.toDouble(),
    agentVatPercent: identical(agentVatPercent, kKeep)
        ? this.agentVatPercent
        : (agentVatPercent as num?)?.toDouble(),
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
    'agentBase': agentBase.name,
    'agentVatPercent': agentVatPercent,
    'agentEnabled': agentEnabled,
    'agentMode': agentMode.name,
    'agentFixed': agentFixed,
    'agentVatEnabled': agentVatEnabled,
    'logisticsMethod': logisticsMethod.name,
    'transportTypeId': transportTypeId,
    'transportUnits': transportUnits,
    'cargoTonnes': cargoTonnes,
    'schema': 3,
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
    final legacy = ((j['schema'] as num?)?.toInt() ?? 1) < 3;
    // v1.1 stored "logisticsPerUnit". Before v3.0 an empty field was saved
    // as 0, so a stored 0 becomes "not entered".
    final log =
        (j['logisticsValue'] as num?)?.toDouble() ??
        (j['logisticsPerUnit'] as num?)?.toDouble();
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
      logisticsValue: (legacy && log == 0) ? null : log,
      logisticsIsTotal: j['logisticsIsTotal'] as bool? ?? false,
      agentPercent: d('agentPercent', 9),
      // Quotes saved before v3.0 keep the agent fee on goods only.
      agentBase: AgencyBase.fromName(j['agentBase'] as String?),
      agentVatPercent: (j['agentVatPercent'] as num?)?.toDouble(),
      agentEnabled: j['agentEnabled'] as bool? ?? true,
      agentMode: AgencyMode.fromName(j['agentMode'] as String?),
      agentFixed: (j['agentFixed'] as num?)?.toDouble(),
      agentVatEnabled:
          j['agentVatEnabled'] as bool? ?? j['agentVatPercent'] != null,
      logisticsMethod: LogisticsMethod.fromName(
        j['logisticsMethod'] as String?,
      ),
      transportTypeId: j['transportTypeId'] as String?,
      transportUnits: (j['transportUnits'] as num?)?.toInt(),
      cargoTonnes: (j['cargoTonnes'] as num?)?.toDouble(),
      vatEnabled: j['vatEnabled'] as bool? ?? false,
      vatPercent: d('vatPercent', 9),
      // v1.1 stored "profitPerUnit".
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
