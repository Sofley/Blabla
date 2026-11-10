import '../data/models/price_quote.dart';

/// Step-by-step selling price for a [PriceQuote] (values in quote currency).
///
///   1. goods/unit       = EXW price
///   2. quantity
///   3. logistics/unit   = value, or batch value / quantity
///   4. agent/unit       = goods × agent%
///   5. VAT/unit         = (goods + logistics + agent) × VAT%
///      cost/unit        = 1 + 3 + 4 + 5
///   6. my profit/unit   = amount, or cost × commission%
///   sale price/unit     = cost + my profit
///   VAT refund/unit     = goods × refund%          (paid back to us)
///   total profit        = (my profit + VAT refund) × quantity
class PriceBreakdown {
  const PriceBreakdown(this.q);

  final PriceQuote q;

  double get logisticsPerUnit {
    if (!q.logisticsIsTotal) return q.logisticsValue;
    return q.quantity > 0 ? q.logisticsValue / q.quantity : 0;
  }

  double get agentPerUnit => q.exwPrice * q.agentPercent / 100;

  double get vatBasePerUnit => q.exwPrice + logisticsPerUnit + agentPerUnit;

  double get vatPerUnit =>
      q.vatEnabled ? vatBasePerUnit * q.vatPercent / 100 : 0;

  /// Everything we pay per unit before our own profit.
  double get costPerUnit => vatBasePerUnit + vatPerUnit;

  double get profitPerUnit =>
      q.profitIsPercent ? costPerUnit * q.profitValue / 100 : q.profitValue;

  double get salePricePerUnit => costPerUnit + profitPerUnit;

  double get vatRefundPerUnit =>
      q.vatRefundEnabled ? q.exwPrice * q.vatRefundPercent / 100 : 0;

  double get totalProfitPerUnit => profitPerUnit + vatRefundPerUnit;

  // Batch totals
  double get saleTotal => salePricePerUnit * q.quantity;
  double get purchaseTotal => q.exwPrice * q.quantity;
  double get logisticsTotal =>
      q.logisticsIsTotal ? q.logisticsValue : q.logisticsValue * q.quantity;
  double get agentTotal => agentPerUnit * q.quantity;
  double get vatTotal => vatPerUnit * q.quantity;
  double get costTotal => costPerUnit * q.quantity;
  double get markupTotal => profitPerUnit * q.quantity;
  double get vatRefundTotal => vatRefundPerUnit * q.quantity;
  double get totalProfit => totalProfitPerUnit * q.quantity;

  double get marginPercent =>
      salePricePerUnit > 0 ? totalProfitPerUnit / salePricePerUnit * 100 : 0;

  /// Share of each component in the selling price, 0..1.
  double share(double perUnit) =>
      salePricePerUnit > 0 ? perUnit / salePricePerUnit : 0;

  double toUsd(double v) => q.ratePerUsd > 0 ? v / q.ratePerUsd : 0;
}
