import 'currency.dart';

/// Which side of the back-to-back structure a contract belongs to.
enum ContractSide {
  /// Contract #1: Buyer ↔ Intermediary (sales side).
  buyer,

  /// Contract #2: Intermediary ↔ Seller / Manufacturer (purchase side).
  seller,
}

/// What the VAT refund percentage is applied to.
enum VatRefundBase {
  /// Goods purchase cost (EXW price × quantity).
  goods,

  /// Whole contract total (goods + logistics + agency + VAT).
  contractTotal;

  static VatRefundBase fromName(String? n) => VatRefundBase.values.firstWhere(
    (b) => b.name == n,
    orElse: () => VatRefundBase.goods,
  );
}

/// What the agent fee percentage is applied to.
enum AgencyBase {
  /// Goods (FOB / EXW) only — how deals were calculated before v3.0.
  goods,

  /// V = goods (FOB) + logistics — the approved base since v3.0.
  goodsAndLogistics;

  static AgencyBase fromName(String? n) => AgencyBase.values.firstWhere(
    (b) => b.name == n,
    orElse: () => AgencyBase.goods,
  );
}

/// Sentinel for [TradeContract.copyWith] so a nullable field can be cleared.
const Object kKeep = _Keep();

class _Keep {
  const _Keep();
}

/// Current storage schema. 3 = nullable optional amounts (v3.0).
const int kContractSchema = 3;

/// One standalone foreign-trade contract with its own requisites, parties,
/// cost inputs and notes. The two contracts of a deal never share fields.
class TradeContract {
  const TradeContract({
    required this.side,
    this.number = '',
    required this.date,
    this.counterpartyName = '',
    this.intermediaryName = '',
    this.productName = '',
    this.currency = Currency.cny,
    this.unitPrice = 0,
    this.quantity = 1,
    this.unit = '',
    double? goodsRatePerUsd,
    this.transportCost,
    this.freightCost,
    this.portFees,
    this.logisticsCurrency = Currency.usd,
    double? logisticsRatePerUsd,
    this.agencyFeePercent = 9,
    this.agencyBase = AgencyBase.goods,
    this.agentVatPercent,
    this.closingRatePerUsd,
    this.vatEnabled = true,
    this.vatPercent = 9,
    this.vatRefundEnabled = false,
    this.vatRefundPercent = 9,
    this.vatRefundBase = VatRefundBase.goods,
    this.vatBonusShare = 50,
    this.vatBonusInProfit = false,
    this.notes = '',
  }) : goodsRatePerUsd = goodsRatePerUsd ?? 0,
       logisticsRatePerUsd = logisticsRatePerUsd ?? 0;

  factory TradeContract.empty(
    ContractSide side, {
    String intermediaryName = '',
    double agencyFeePercent = 8,
    double? agentVatPercent,
    double vatPercent = 9,
    double vatRefundPercent = 9,
    double vatBonusShare = 0,
    String unit = '',
  }) {
    final currency = side == ContractSide.seller ? Currency.cny : Currency.usd;
    return TradeContract(
      side: side,
      date: DateTime.now(),
      intermediaryName: intermediaryName,
      currency: currency,
      unit: unit,
      goodsRatePerUsd: currency.defaultRatePerUsd,
      logisticsRatePerUsd: Currency.usd.defaultRatePerUsd,
      agencyFeePercent: agencyFeePercent,
      agencyBase: AgencyBase.goodsAndLogistics,
      agentVatPercent: agentVatPercent,
      // 2.30 $/kg is a final price: no extra VAT unless switched on.
      vatEnabled: false,
      vatPercent: vatPercent,
      vatRefundEnabled: side == ContractSide.seller,
      vatRefundPercent: vatRefundPercent,
      vatBonusShare: vatBonusShare,
    );
  }

  final ContractSide side;

  // Requisites
  final String number;
  final DateTime date;

  /// Buyer (contract #1) or Seller / Manufacturer (contract #2).
  final String counterpartyName;

  /// Intermediary company (party in both contracts, stored separately).
  final String intermediaryName;

  // Goods
  final String productName;
  final Currency currency;

  /// Price per unit in [currency].
  final double unitPrice;
  final double quantity;

  /// Unit of measure (pcs, kg, t…). Empty = not specified.
  final String unit;

  /// Units of [currency] per 1 USD on the signing date.
  final double goodsRatePerUsd;

  // Logistics. null = not entered («Не задано»), 0 = confirmed zero.
  final double? transportCost;
  final double? freightCost;
  final double? portFees;
  final Currency logisticsCurrency;

  /// Units of [logisticsCurrency] per 1 USD on the signing date.
  final double logisticsRatePerUsd;

  // Fees & taxes
  final double agencyFeePercent;

  /// What [agencyFeePercent] is applied to.
  final AgencyBase agencyBase;

  /// VAT charged by the agent on its fee (part of the client price, not our
  /// VAT). null = not set («Не задано»): no rate is assumed.
  final double? agentVatPercent;

  /// Units of [currency] per 1 USD on the closing date. Used only to show
  /// the exchange difference; it never changes the profit.
  final double? closingRatePerUsd;
  final bool vatEnabled;
  final double vatPercent;

  /// VAT refunded to the intermediary company (income).
  final bool vatRefundEnabled;
  final double vatRefundPercent;
  final VatRefundBase vatRefundBase;

  /// Our share of the VAT refund, 0–100 % (the rest goes to partners).
  final double vatBonusShare;

  /// Whether our share ("VAT bonus") is added to net profit.
  /// When off it is shown for reference only.
  final bool vatBonusInProfit;

  // Remarks / Notes
  final String notes;

  /// Total goods cost in the contract currency.
  double get goodsCost => unitPrice * quantity;

  double get logisticsTotal =>
      (transportCost ?? 0) + (freightCost ?? 0) + (portFees ?? 0);

  /// Whether at least one logistics amount was entered (zero included).
  bool get logisticsEntered =>
      transportCost != null || freightCost != null || portFees != null;

  double get effectiveVatPercent => vatEnabled ? vatPercent : 0;

  TradeContract copyWith({
    String? number,
    DateTime? date,
    String? counterpartyName,
    String? intermediaryName,
    String? productName,
    Currency? currency,
    double? unitPrice,
    double? quantity,
    String? unit,
    double? goodsRatePerUsd,
    Object? transportCost = kKeep,
    Object? freightCost = kKeep,
    Object? portFees = kKeep,
    Currency? logisticsCurrency,
    double? logisticsRatePerUsd,
    double? agencyFeePercent,
    AgencyBase? agencyBase,
    Object? agentVatPercent = kKeep,
    Object? closingRatePerUsd = kKeep,
    bool? vatEnabled,
    double? vatPercent,
    bool? vatRefundEnabled,
    double? vatRefundPercent,
    VatRefundBase? vatRefundBase,
    double? vatBonusShare,
    bool? vatBonusInProfit,
    String? notes,
  }) {
    return TradeContract(
      side: side,
      number: number ?? this.number,
      date: date ?? this.date,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      intermediaryName: intermediaryName ?? this.intermediaryName,
      productName: productName ?? this.productName,
      currency: currency ?? this.currency,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      goodsRatePerUsd: goodsRatePerUsd ?? this.goodsRatePerUsd,
      transportCost: identical(transportCost, kKeep)
          ? this.transportCost
          : (transportCost as num?)?.toDouble(),
      freightCost: identical(freightCost, kKeep)
          ? this.freightCost
          : (freightCost as num?)?.toDouble(),
      portFees: identical(portFees, kKeep)
          ? this.portFees
          : (portFees as num?)?.toDouble(),
      logisticsCurrency: logisticsCurrency ?? this.logisticsCurrency,
      logisticsRatePerUsd: logisticsRatePerUsd ?? this.logisticsRatePerUsd,
      agencyFeePercent: agencyFeePercent ?? this.agencyFeePercent,
      agencyBase: agencyBase ?? this.agencyBase,
      agentVatPercent: identical(agentVatPercent, kKeep)
          ? this.agentVatPercent
          : (agentVatPercent as num?)?.toDouble(),
      closingRatePerUsd: identical(closingRatePerUsd, kKeep)
          ? this.closingRatePerUsd
          : (closingRatePerUsd as num?)?.toDouble(),
      vatEnabled: vatEnabled ?? this.vatEnabled,
      vatPercent: vatPercent ?? this.vatPercent,
      vatRefundEnabled: vatRefundEnabled ?? this.vatRefundEnabled,
      vatRefundPercent: vatRefundPercent ?? this.vatRefundPercent,
      vatRefundBase: vatRefundBase ?? this.vatRefundBase,
      vatBonusShare: vatBonusShare ?? this.vatBonusShare,
      vatBonusInProfit: vatBonusInProfit ?? this.vatBonusInProfit,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': kContractSchema,
    'side': side.name,
    'number': number,
    'date': date.toIso8601String(),
    'counterpartyName': counterpartyName,
    'intermediaryName': intermediaryName,
    'productName': productName,
    'currency': currency.code,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'unit': unit,
    'goodsRatePerUsd': goodsRatePerUsd,
    'transportCost': transportCost,
    'freightCost': freightCost,
    'portFees': portFees,
    'logisticsCurrency': logisticsCurrency.code,
    'logisticsRatePerUsd': logisticsRatePerUsd,
    'agencyFeePercent': agencyFeePercent,
    'agencyBase': agencyBase.name,
    'agentVatPercent': agentVatPercent,
    'closingRatePerUsd': closingRatePerUsd,
    'vatEnabled': vatEnabled,
    'vatPercent': vatPercent,
    'vatRefundEnabled': vatRefundEnabled,
    'vatRefundPercent': vatRefundPercent,
    'vatRefundBase': vatRefundBase.name,
    'vatBonusShare': vatBonusShare,
    'vatBonusInProfit': vatBonusInProfit,
    'notes': notes,
  };

  factory TradeContract.fromJson(Map<dynamic, dynamic> json) {
    double d(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    final currency = Currency.fromCode(json['currency'] as String?);
    final logCurrency = Currency.fromCode(json['logisticsCurrency'] as String?);
    // v1 stored only a lump sum "goodsCost": treat it as 1 × price.
    final hasUnitPrice = json.containsKey('unitPrice');
    // Before schema 3 an empty optional amount was saved as 0, so a stored
    // 0 cannot be told apart from "not entered": it becomes "not entered".
    final legacy = ((json['schema'] as num?)?.toInt() ?? 1) < kContractSchema;
    double? opt(String key) {
      final v = (json[key] as num?)?.toDouble();
      if (v == null || (legacy && v == 0)) return null;
      return v;
    }

    return TradeContract(
      side: ContractSide.values.firstWhere(
        (s) => s.name == json['side'],
        orElse: () => ContractSide.buyer,
      ),
      number: json['number'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      counterpartyName: json['counterpartyName'] as String? ?? '',
      intermediaryName: json['intermediaryName'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      currency: currency,
      unitPrice: hasUnitPrice ? d('unitPrice', 0) : d('goodsCost', 0),
      quantity: hasUnitPrice ? d('quantity', 1) : 1,
      unit: json['unit'] as String? ?? '',
      goodsRatePerUsd: d('goodsRatePerUsd', currency.defaultRatePerUsd),
      transportCost: opt('transportCost'),
      freightCost: opt('freightCost'),
      portFees: opt('portFees'),
      logisticsCurrency: logCurrency,
      logisticsRatePerUsd: d(
        'logisticsRatePerUsd',
        logCurrency.defaultRatePerUsd,
      ),
      agencyFeePercent: d('agencyFeePercent', 9),
      // Deals saved before v3.0 kKeep the agent fee on goods only.
      agencyBase: AgencyBase.fromName(json['agencyBase'] as String?),
      agentVatPercent: (json['agentVatPercent'] as num?)?.toDouble(),
      closingRatePerUsd: (json['closingRatePerUsd'] as num?)?.toDouble(),
      vatEnabled: json['vatEnabled'] as bool? ?? true,
      vatPercent: d('vatPercent', 9),
      vatRefundEnabled: json['vatRefundEnabled'] as bool? ?? false,
      vatRefundPercent: d('vatRefundPercent', 9),
      vatRefundBase: VatRefundBase.fromName(json['vatRefundBase'] as String?),
      // Records saved before v2.1 counted the whole refund as profit.
      vatBonusShare: d('vatBonusShare', 100),
      vatBonusInProfit: json['vatBonusInProfit'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
    );
  }
}
