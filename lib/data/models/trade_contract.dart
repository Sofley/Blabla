import 'currency.dart';

/// Which side of the back-to-back structure a contract belongs to.
enum ContractSide {
  /// Contract #1: Buyer ↔ Intermediary (sales side).
  buyer,

  /// Contract #2: Intermediary ↔ Seller / Manufacturer (purchase side).
  seller,
}

/// One standalone foreign-trade contract with its own requisites, parties,
/// cost inputs and notes. The two contracts of a deal never share fields.
class TradeContract {
  const TradeContract({
    required this.side,
    this.number = '',
    required this.date,
    this.counterpartyName = '',
    this.intermediaryName = '',
    this.currency = Currency.cny,
    this.goodsCost = 0,
    double? goodsRatePerUsd,
    this.transportCost = 0,
    this.freightCost = 0,
    this.portFees = 0,
    this.logisticsCurrency = Currency.usd,
    double? logisticsRatePerUsd,
    this.agencyFeePercent = 9,
    this.vatEnabled = true,
    this.vatPercent = 9,
    this.notes = '',
  }) : goodsRatePerUsd = goodsRatePerUsd ?? 0,
       logisticsRatePerUsd = logisticsRatePerUsd ?? 0;

  factory TradeContract.empty(
    ContractSide side, {
    String intermediaryName = '',
    double agencyFeePercent = 9,
    double vatPercent = 9,
  }) {
    final currency = side == ContractSide.seller ? Currency.cny : Currency.usd;
    return TradeContract(
      side: side,
      date: DateTime.now(),
      intermediaryName: intermediaryName,
      currency: currency,
      goodsRatePerUsd: currency.defaultRatePerUsd,
      logisticsRatePerUsd: Currency.usd.defaultRatePerUsd,
      agencyFeePercent: agencyFeePercent,
      vatPercent: vatPercent,
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
  final Currency currency;
  final double goodsCost;

  /// Units of [currency] per 1 USD on the signing date.
  final double goodsRatePerUsd;

  // Logistics
  final double transportCost;
  final double freightCost;
  final double portFees;
  final Currency logisticsCurrency;

  /// Units of [logisticsCurrency] per 1 USD on the signing date.
  final double logisticsRatePerUsd;

  // Fees & taxes
  final double agencyFeePercent;
  final bool vatEnabled;
  final double vatPercent;

  // Remarks / Notes
  final String notes;

  double get logisticsTotal => transportCost + freightCost + portFees;

  double get effectiveVatPercent => vatEnabled ? vatPercent : 0;

  TradeContract copyWith({
    String? number,
    DateTime? date,
    String? counterpartyName,
    String? intermediaryName,
    Currency? currency,
    double? goodsCost,
    double? goodsRatePerUsd,
    double? transportCost,
    double? freightCost,
    double? portFees,
    Currency? logisticsCurrency,
    double? logisticsRatePerUsd,
    double? agencyFeePercent,
    bool? vatEnabled,
    double? vatPercent,
    String? notes,
  }) {
    return TradeContract(
      side: side,
      number: number ?? this.number,
      date: date ?? this.date,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      intermediaryName: intermediaryName ?? this.intermediaryName,
      currency: currency ?? this.currency,
      goodsCost: goodsCost ?? this.goodsCost,
      goodsRatePerUsd: goodsRatePerUsd ?? this.goodsRatePerUsd,
      transportCost: transportCost ?? this.transportCost,
      freightCost: freightCost ?? this.freightCost,
      portFees: portFees ?? this.portFees,
      logisticsCurrency: logisticsCurrency ?? this.logisticsCurrency,
      logisticsRatePerUsd: logisticsRatePerUsd ?? this.logisticsRatePerUsd,
      agencyFeePercent: agencyFeePercent ?? this.agencyFeePercent,
      vatEnabled: vatEnabled ?? this.vatEnabled,
      vatPercent: vatPercent ?? this.vatPercent,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'side': side.name,
    'number': number,
    'date': date.toIso8601String(),
    'counterpartyName': counterpartyName,
    'intermediaryName': intermediaryName,
    'currency': currency.code,
    'goodsCost': goodsCost,
    'goodsRatePerUsd': goodsRatePerUsd,
    'transportCost': transportCost,
    'freightCost': freightCost,
    'portFees': portFees,
    'logisticsCurrency': logisticsCurrency.code,
    'logisticsRatePerUsd': logisticsRatePerUsd,
    'agencyFeePercent': agencyFeePercent,
    'vatEnabled': vatEnabled,
    'vatPercent': vatPercent,
    'notes': notes,
  };

  factory TradeContract.fromJson(Map<dynamic, dynamic> json) {
    double d(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    final currency = Currency.fromCode(json['currency'] as String?);
    final logCurrency = Currency.fromCode(json['logisticsCurrency'] as String?);
    return TradeContract(
      side: ContractSide.values.firstWhere(
        (s) => s.name == json['side'],
        orElse: () => ContractSide.buyer,
      ),
      number: json['number'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      counterpartyName: json['counterpartyName'] as String? ?? '',
      intermediaryName: json['intermediaryName'] as String? ?? '',
      currency: currency,
      goodsCost: d('goodsCost', 0),
      goodsRatePerUsd: d('goodsRatePerUsd', currency.defaultRatePerUsd),
      transportCost: d('transportCost', 0),
      freightCost: d('freightCost', 0),
      portFees: d('portFees', 0),
      logisticsCurrency: logCurrency,
      logisticsRatePerUsd: d(
        'logisticsRatePerUsd',
        logCurrency.defaultRatePerUsd,
      ),
      agencyFeePercent: d('agencyFeePercent', 9),
      vatEnabled: json['vatEnabled'] as bool? ?? true,
      vatPercent: d('vatPercent', 9),
      notes: json['notes'] as String? ?? '',
    );
  }
}
