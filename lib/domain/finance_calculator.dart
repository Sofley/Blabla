import '../data/models/deal.dart';
import '../data/models/trade_contract.dart';

/// Financial breakdown of a single contract, in the reporting currency (USD),
/// using the exchange rates fixed on the contract signing date.
///
///   goods      = unitPrice × quantity / goodsRatePerUsd
///   logistics  = (transport + freight + port fees) / logisticsRatePerUsd
///   agency     = goods × agency%
///   net        = goods + logistics + agency           (amount excl. VAT)
///   vat        = net × VAT%  (0 when VAT is switched off)
///   total      = net + vat                             (contract amount)
///   vatRefund  = refund% × (goods | total)
///   vatBonus   = vatRefund × our share%               (income of intermediary)
class ContractFinancials {
  const ContractFinancials({
    required this.goodsUsd,
    required this.logisticsUsd,
    required this.agencyFeeUsd,
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
    final agency = goods * c.agencyFeePercent / 100;
    final vat = (goods + logistics + agency) * c.effectiveVatPercent / 100;
    final refundBase = switch (c.vatRefundBase) {
      VatRefundBase.goods => goods,
      VatRefundBase.contractTotal => goods + logistics + agency + vat,
    };
    return ContractFinancials(
      goodsUsd: goods,
      logisticsUsd: logistics,
      agencyFeeUsd: agency,
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

  double get netUsd => goodsUsd + logisticsUsd + agencyFeeUsd;
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

  /// Margin in percent; 0 when there is no revenue.
  double get marginPercent =>
      revenueExVatUsd > 0 ? netProfitUsd / revenueExVatUsd * 100 : 0;
}

/// Buyer price per unit (in Contract #1 currency) that gives the margin set
/// on the deal: buyer total = Contract #2 total + margin, where the margin is
/// % of the factory goods amount or a fixed USD sum.
/// Returns null for manual pricing or when it cannot be calculated.
double? computedBuyerUnitPrice(Deal deal) {
  if (deal.pricingMode == PricingMode.manual) return null;
  final buyer = deal.buyerContract;
  if (buyer.quantity <= 0 || buyer.goodsRatePerUsd <= 0) return null;
  final factory = ContractFinancials.of(deal.sellerContract);
  final margin = deal.pricingMode == PricingMode.marginPercent
      ? factory.goodsUsd * deal.marginValue / 100
      : deal.marginValue;
  // Contract #1 may carry its own VAT for the buyer; the margin is net of it.
  final netUsd = factory.totalUsd + margin;
  final totalBuyerCurrency = netUsd * buyer.goodsRatePerUsd;
  return totalBuyerCurrency / buyer.quantity;
}
