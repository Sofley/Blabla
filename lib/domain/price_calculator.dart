import '../data/models/price_quote.dart';

/// Step-by-step selling price for a [PriceQuote] (values in quote currency).
///
///   1. goods/unit       = EXW price (÷ 1000 when entered per tonne)
///   2. quantity
///   3. logistics/unit   = value, or batch value / quantity
///   4. agent/unit       = goods × agent%            (hidden from the buyer)
///   5. VAT/unit         = (goods + logistics + agent) × VAT%
///      cost/unit        = 1 + 3 + 4 + 5
///   6. my profit/unit   = amount | cost × commission% | buyer price − cost
///   sale price/unit     = cost + my profit
///
///   VAT refund/unit     = goods × refund%
///   VAT bonus/unit      = VAT refund × my share%
///   total profit        = (my profit + VAT bonus if "add to profit") × qty
class PriceBreakdown {
  const PriceBreakdown(this.q);

  final PriceQuote q;

  double get goodsPerUnit => q.exwPerThousand ? q.exwPrice / 1000 : q.exwPrice;

  double get logisticsPerUnit {
    if (!q.logisticsIsTotal) return q.logisticsValue;
    return q.quantity > 0 ? q.logisticsValue / q.quantity : 0;
  }

  double get agentPerUnit => goodsPerUnit * q.agentPercent / 100;

  double get vatBasePerUnit => goodsPerUnit + logisticsPerUnit + agentPerUnit;

  double get vatPerUnit =>
      q.vatEnabled ? vatBasePerUnit * q.vatPercent / 100 : 0;

  /// Everything we pay per unit before our own profit.
  double get costPerUnit => vatBasePerUnit + vatPerUnit;

  double get profitPerUnit => switch (q.profitMode) {
    ProfitMode.amount => q.profitValue,
    ProfitMode.percent => costPerUnit * q.profitValue / 100,
    ProfitMode.salePrice => q.profitValue - costPerUnit,
  };

  double get salePricePerUnit => costPerUnit + profitPerUnit;

  double get vatRefundPerUnit =>
      q.vatRefundEnabled ? goodsPerUnit * q.vatRefundPercent / 100 : 0;

  /// Our share of the refund (always calculated, for reference).
  double get vatBonusPerUnit => vatRefundPerUnit * q.vatBonusShare / 100;

  /// Part of the bonus that counts as profit (0 when the switch is off).
  double get vatBonusInProfitPerUnit =>
      q.vatBonusInProfit ? vatBonusPerUnit : 0;

  double get totalProfitPerUnit => profitPerUnit + vatBonusInProfitPerUnit;

  // Batch totals
  double get saleTotal => salePricePerUnit * q.quantity;
  double get purchaseTotal => goodsPerUnit * q.quantity;
  double get logisticsTotal =>
      q.logisticsIsTotal ? q.logisticsValue : q.logisticsValue * q.quantity;
  double get agentTotal => agentPerUnit * q.quantity;
  double get vatTotal => vatPerUnit * q.quantity;
  double get costTotal => costPerUnit * q.quantity;
  double get markupTotal => profitPerUnit * q.quantity;
  double get vatRefundTotal => vatRefundPerUnit * q.quantity;
  double get vatBonusTotal => vatBonusPerUnit * q.quantity;
  double get vatBonusInProfitTotal => vatBonusInProfitPerUnit * q.quantity;
  double get totalProfit => totalProfitPerUnit * q.quantity;

  double get marginPercent =>
      salePricePerUnit > 0 ? totalProfitPerUnit / salePricePerUnit * 100 : 0;

  /// Selling price that gives exactly [profitPerUnit] of markup.
  double priceForProfit(double profitPerUnit) => costPerUnit + profitPerUnit;

  /// Share of each component in the selling price, 0..1.
  double share(double perUnit) =>
      salePricePerUnit > 0 ? perUnit / salePricePerUnit : 0;

  double toUsd(double v) => q.ratePerUsd > 0 ? v / q.ratePerUsd : 0;
}
