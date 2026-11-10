import '../data/models/deal.dart';
import '../data/models/trade_contract.dart';

/// Financial breakdown of a single contract, in the reporting currency (USD),
/// using the exchange rates fixed on the contract signing date.
///
///   goods      = goodsCost / goodsRatePerUsd
///   logistics  = (transport + freight + port fees) / logisticsRatePerUsd
///   agency     = goods × agency%
///   net        = goods + logistics + agency           (amount excl. VAT)
///   vat        = net × VAT%  (0 when VAT is switched off)
///   total      = net + vat                             (contract amount)
class ContractFinancials {
  const ContractFinancials({
    required this.goodsUsd,
    required this.logisticsUsd,
    required this.agencyFeeUsd,
    required this.vatUsd,
    required this.goodsRatePerUsd,
  });

  factory ContractFinancials.of(TradeContract c) {
    final goods = _convert(c.goodsCost, c.goodsRatePerUsd);
    final logistics = _convert(c.logisticsTotal, c.logisticsRatePerUsd);
    final agency = goods * c.agencyFeePercent / 100;
    final vat = (goods + logistics + agency) * c.effectiveVatPercent / 100;
    return ContractFinancials(
      goodsUsd: goods,
      logisticsUsd: logistics,
      agencyFeeUsd: agency,
      vatUsd: vat,
      goodsRatePerUsd: c.goodsRatePerUsd,
    );
  }

  final double goodsUsd;
  final double logisticsUsd;
  final double agencyFeeUsd;
  final double vatUsd;
  final double goodsRatePerUsd;

  double get netUsd => goodsUsd + logisticsUsd + agencyFeeUsd;
  double get totalUsd => netUsd + vatUsd;

  /// Contract total expressed back in the contract currency.
  double get totalInContractCurrency =>
      goodsRatePerUsd > 0 ? totalUsd * goodsRatePerUsd : 0;

  static double _convert(double amount, double ratePerUsd) =>
      ratePerUsd > 0 ? amount / ratePerUsd : 0;
}

/// Net profit of the back-to-back deal (intermediary's perspective).
///
///   revenue (turnover)  = Contract #1 total (what the buyer pays, incl. VAT)
///   revenue excl. VAT   = Contract #1 net   (output VAT goes to the budget)
///   expenses            = Contract #2 total (paid to seller + logistics,
///                         agency and non-recoverable input VAT)
///   net profit          = revenue excl. VAT − expenses
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
  double get netProfitUsd => revenueExVatUsd - expensesUsd;

  /// Margin in percent; 0 when there is no revenue.
  double get marginPercent =>
      revenueExVatUsd > 0 ? netProfitUsd / revenueExVatUsd * 100 : 0;
}
