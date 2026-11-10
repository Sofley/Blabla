import '../data/models/price_quote.dart';

/// Bottom-up selling price for a [PriceQuote] (all values in quote currency).
///
///   agent/unit      = EXW × agent%
///   sale price/unit = EXW + logistics + agent + profit
///   VAT refund/unit = EXW × refund%           (paid back to the intermediary)
///   total profit    = (profit + VAT refund) × quantity
class PriceBreakdown {
  const PriceBreakdown(this.q);

  final PriceQuote q;

  double get agentPerUnit => q.exwPrice * q.agentPercent / 100;

  double get salePricePerUnit =>
      q.exwPrice + q.logisticsPerUnit + agentPerUnit + q.profitPerUnit;

  double get vatRefundPerUnit =>
      q.vatRefundEnabled ? q.exwPrice * q.vatRefundPercent / 100 : 0;

  double get totalProfitPerUnit => q.profitPerUnit + vatRefundPerUnit;

  // Batch totals
  double get saleTotal => salePricePerUnit * q.quantity;
  double get purchaseTotal => q.exwPrice * q.quantity;
  double get logisticsTotal => q.logisticsPerUnit * q.quantity;
  double get agentTotal => agentPerUnit * q.quantity;
  double get markupTotal => q.profitPerUnit * q.quantity;
  double get vatRefundTotal => vatRefundPerUnit * q.quantity;
  double get totalProfit => totalProfitPerUnit * q.quantity;

  double get marginPercent =>
      salePricePerUnit > 0 ? totalProfitPerUnit / salePricePerUnit * 100 : 0;

  /// Share of each component in the selling price, 0..1.
  double share(double perUnit) =>
      salePricePerUnit > 0 ? perUnit / salePricePerUnit : 0;

  double toUsd(double v) => q.ratePerUsd > 0 ? v / q.ratePerUsd : 0;
}
