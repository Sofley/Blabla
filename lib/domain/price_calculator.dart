import '../data/models/price_quote.dart';
import '../data/models/trade_contract.dart'
    show AgencyBase, AgencyMode, LogisticsMethod;

/// Step-by-step selling price for a [PriceQuote] (values in quote currency).
///
///   1. goods/unit       = EXW price (÷ 1000 when entered per tonne)
///   2. quantity
///   3. logistics/unit   = value, or batch value / quantity
///   3. logistics        = per unit | for the batch | rate × tonnes |
///                         rate × trucks/containers
///   4. agent/unit       = goods × agent% or fixed sum ÷ quantity; 0 if OFF
///      agent VAT/unit   = agent × agent VAT% when ON (0 while "not set")
///   5. VAT/unit         = (goods + logistics + agent + agent VAT) × VAT%
///      cost/unit        = 1 + 3 + 4 + agent VAT + 5
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

  /// Logistics for the whole batch; null when not entered (or the weight /
  /// number of units needed for the method is missing).
  double? get _logisticsBatch {
    final v = q.logisticsValue;
    if (v == null) return null;
    return switch (q.logisticsMethod) {
      LogisticsMethod.manual => q.logisticsIsTotal ? v : v * q.quantity,
      LogisticsMethod.perTonne => q.tonnes == null ? null : v * q.tonnes!,
      LogisticsMethod.perTransportUnit =>
        q.transportUnits == null ? null : v * q.transportUnits!,
    };
  }

  double get logisticsPerUnit =>
      q.quantity > 0 ? (_logisticsBatch ?? 0) / q.quantity : 0;

  /// Logistics not entered: the result is shown without it.
  bool get logisticsUnset => _logisticsBatch == null;

  /// V per unit = goods + logistics.
  double get vBasePerUnit => goodsPerUnit + logisticsPerUnit;

  /// Agent fee per unit: 0 when OFF; percent of the goods cost; or the
  /// fixed batch sum spread over the quantity.
  double get agentPerUnit {
    if (!q.agentEnabled) return 0;
    if (q.agentMode == AgencyMode.fixed) {
      return q.quantity > 0 ? (q.agentFixed ?? 0) / q.quantity : 0;
    }
    final base = switch (q.agentBase) {
      AgencyBase.goods => goodsPerUnit,
      AgencyBase.goodsAndLogistics => vBasePerUnit,
    };
    return base * q.agentPercent / 100;
  }

  bool get _agentVatOn => q.agentEnabled && q.agentVatEnabled;

  double get agentVatPerUnit =>
      _agentVatOn ? agentPerUnit * (q.agentVatPercent ?? 0) / 100 : 0;

  /// Agent VAT is ON but its rate is not set.
  bool get agentVatUnset =>
      _agentVatOn && q.agentVatPercent == null && agentPerUnit > 0;

  /// Agent fee is ON as a fixed sum that is not entered.
  bool get agentUnset =>
      q.agentEnabled && q.agentMode == AgencyMode.fixed && q.agentFixed == null;

  double get vatBasePerUnit =>
      goodsPerUnit + logisticsPerUnit + agentPerUnit + agentVatPerUnit;

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
  double get logisticsTotal => _logisticsBatch ?? 0;
  double get agentTotal => agentPerUnit * q.quantity;
  double get agentVatTotal => agentVatPerUnit * q.quantity;
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
