import '../data/models/deal.dart';
import '../data/models/trade_contract.dart';

/// Financial breakdown of a single contract, in the reporting currency (USD),
/// using the exchange rates fixed on the contract signing date.
///
///   goods      = unitPrice × quantity / goodsRatePerUsd        (FOB)
///   logistics  = (transport + freight + port fees) / logisticsRatePerUsd
///   V          = goods + logistics
///   agency     = goods × agency%  or a fixed USD sum; 0 when switched OFF
///                (a 3.0 test build also allowed V = goods + logistics)
///   agent VAT  = agency × agent VAT%  when ON (0 while the rate is not set)
///   net        = goods + logistics + agency + agent VAT (amount excl. VAT)
///   vat        = net × VAT%  (0 when VAT is switched off)
///   total      = net + vat                             (contract amount)
///   vatRefund  = refund% × (goods | total)
///   vatBonus   = vatRefund × our share%               (income of intermediary)
class ContractFinancials {
  const ContractFinancials({
    required this.goodsUsd,
    required this.logisticsUsd,
    required this.agencyFeeUsd,
    this.agentVatUsd = 0,
    this.agentVatUnset = false,
    this.agencyUnset = false,
    this.logisticsUnset = false,
    this.fxDifferenceUsd,
    required this.vatUsd,
    required this.vatRefundUsd,
    this.vatBonusShare = 100,
    this.vatBonusInProfit = true,
    required this.goodsRatePerUsd,
    required this.quantity,
  });

  factory ContractFinancials.of(TradeContract c) {
    final goods = _convert(c.goodsCost, c.goodsRatePerUsd);
    final logistics = _convert(c.logisticsTotal, c.logisticsRatePerUsd);
    final agencyBase = switch (c.agencyBase) {
      AgencyBase.goods => goods,
      AgencyBase.goodsAndLogistics => goods + logistics,
    };
    // Agent fee: OFF → 0; percent of the goods cost; or a fixed sum (USD).
    final agency = !c.agencyEnabled
        ? 0.0
        : c.agencyMode == AgencyMode.fixed
        ? (c.agencyFixedUsd ?? 0)
        : agencyBase * c.agencyFeePercent / 100;
    final agentVatOn = c.agencyEnabled && c.agentVatEnabled;
    final agentVat = agentVatOn ? agency * (c.agentVatPercent ?? 0) / 100 : 0.0;
    final net = goods + logistics + agency + agentVat;
    final vat = net * c.effectiveVatPercent / 100;
    final refundBase = switch (c.vatRefundBase) {
      VatRefundBase.goods => goods,
      VatRefundBase.contractTotal => net + vat,
    };
    double? fx;
    final close = c.closingRatePerUsd;
    if (close != null && close > 0 && c.goodsRatePerUsd > 0) {
      fx = c.goodsCost / close - c.goodsCost / c.goodsRatePerUsd;
    }
    return ContractFinancials(
      goodsUsd: goods,
      logisticsUsd: logistics,
      agencyFeeUsd: agency,
      agentVatUsd: agentVat,
      agentVatUnset: agentVatOn && agency > 0 && c.agentVatPercent == null,
      agencyUnset:
          c.agencyEnabled &&
          c.agencyMode == AgencyMode.fixed &&
          c.agencyFixedUsd == null,
      logisticsUnset: !c.logisticsEntered,
      fxDifferenceUsd: fx,
      vatUsd: vat,
      vatRefundUsd: c.vatRefundEnabled
          ? refundBase * c.vatRefundPercent / 100
          : 0,
      vatBonusShare: c.vatBonusShare,
      vatBonusInProfit: c.vatBonusInProfit,
      goodsRatePerUsd: c.goodsRatePerUsd,
      quantity: c.quantity,
    );
  }

  final double goodsUsd;
  final double logisticsUsd;
  final double agencyFeeUsd;

  /// VAT of the agent on its fee (included in the client price).
  final double agentVatUsd;

  /// The agent VAT rate is not set: it is not assumed, so the result is
  /// shown with a "not set" note.
  final bool agentVatUnset;

  /// Agent fee is ON as a fixed sum, but the sum is not entered.
  final bool agencyUnset;

  /// No logistics amount entered (not even a confirmed zero).
  final bool logisticsUnset;

  /// Goods amount at the closing rate minus at the signing rate (USD).
  /// Information only — never part of the profit. null = no closing rate.
  final double? fxDifferenceUsd;

  final double vatUsd;
  final double vatRefundUsd;
  final double vatBonusShare;
  final bool vatBonusInProfit;

  /// Our share of the refund (always calculated, for reference).
  double get vatBonusUsd => vatRefundUsd * vatBonusShare / 100;

  /// Part of the bonus counted in net profit.
  double get vatBonusInProfitUsd => vatBonusInProfit ? vatBonusUsd : 0;
  final double goodsRatePerUsd;
  final double quantity;

  /// V — base of the agent fee for v3.0 deals.
  double get vBaseUsd => goodsUsd + logisticsUsd;

  double get netUsd => goodsUsd + logisticsUsd + agencyFeeUsd + agentVatUsd;
  double get totalUsd => netUsd + vatUsd;

  /// Contract total per unit of goods (USD).
  double get totalPerUnitUsd => quantity > 0 ? totalUsd / quantity : 0;

  /// Contract total expressed back in the contract currency.
  double get totalInContractCurrency =>
      goodsRatePerUsd > 0 ? totalUsd * goodsRatePerUsd : 0;

  static double _convert(double amount, double ratePerUsd) =>
      ratePerUsd > 0 ? amount / ratePerUsd : 0;
}

/// Net profit of the back-to-back deal (intermediary's perspective).
///
///   turnover            = Contract #1 total (what the buyer pays, incl. VAT)
///   revenue excl. VAT   = Contract #1 net   (output VAT goes to the budget)
///   expenses            = Contract #2 total (seller, logistics, agent, VAT)
///   VAT bonus           = our share of the VAT refund
///   net profit          = revenue excl. VAT − expenses
///                         + VAT bonus (only when "add to profit" is on)
///   margin              = net profit / revenue excl. VAT
class DealProfit {
  const DealProfit({required this.sales, required this.purchase});

  factory DealProfit.of(Deal deal) => DealProfit(
    sales: ContractFinancials.of(deal.buyerContract),
    purchase: ContractFinancials.of(deal.sellerContract),
  );

  final ContractFinancials sales;
  final ContractFinancials purchase;

  double get turnoverUsd => sales.totalUsd;
  double get revenueExVatUsd => sales.netUsd;
  double get outputVatUsd => sales.vatUsd;
  double get expensesUsd => purchase.totalUsd;
  double get vatRefundUsd => sales.vatRefundUsd + purchase.vatRefundUsd;
  double get vatBonusUsd => sales.vatBonusUsd + purchase.vatBonusUsd;
  double get vatBonusInProfitUsd =>
      sales.vatBonusInProfitUsd + purchase.vatBonusInProfitUsd;

  /// Bonus calculated but not counted in profit (reference only).
  double get vatBonusReferenceUsd => vatBonusUsd - vatBonusInProfitUsd;

  /// Profit before the VAT refund (pure trading markup).
  double get markupUsd => revenueExVatUsd - expensesUsd;
  double get netProfitUsd => markupUsd + vatBonusInProfitUsd;

  /// Exchange difference at closing, from our side: what the buyer paid
  /// more (+) minus what we paid the factory more (+), in USD.
  /// Information only; null when no closing rate was entered.
  double? get fxDifferenceUsd {
    final a = sales.fxDifferenceUsd;
    final b = purchase.fxDifferenceUsd;
    if (a == null && b == null) return null;
    return (a ?? 0) - (b ?? 0);
  }

  /// Inputs that are "not set" and therefore not part of the result.
  bool get agentVatUnset => purchase.agentVatUnset || sales.agentVatUnset;
  bool get agencyUnset => purchase.agencyUnset;
  bool get logisticsUnset => purchase.logisticsUnset;

  /// Margin in percent; 0 when there is no revenue.
  double get marginPercent =>
      revenueExVatUsd > 0 ? netProfitUsd / revenueExVatUsd * 100 : 0;
}

/// Buyer price per unit (in Contract #1 currency) that gives the margin set
/// on the deal: buyer total = Contract #2 total + margin, where the margin is
/// % of the factory goods amount, a fixed USD sum, or USD per unit of
/// Contract #1 (e.g. 0.33 $/kg).
/// Returns null for manual pricing or when it cannot be calculated.
double? computedBuyerUnitPrice(Deal deal) {
  if (deal.pricingMode == PricingMode.manual) return null;
  final buyer = deal.buyerContract;
  if (buyer.quantity <= 0 || buyer.goodsRatePerUsd <= 0) return null;
  final factory = ContractFinancials.of(deal.sellerContract);
  final margin = switch (deal.pricingMode) {
    PricingMode.marginPercent => factory.goodsUsd * deal.marginValue / 100,
    PricingMode.profitPerUnit => deal.marginValue * buyer.quantity,
    _ => deal.marginValue,
  };
  // Contract #1 may carry its own VAT for the buyer; the margin is net of it.
  final netUsd = factory.totalUsd + margin;
  final totalBuyerCurrency = netUsd * buyer.goodsRatePerUsd;
  return totalBuyerCurrency / buyer.quantity;
}
