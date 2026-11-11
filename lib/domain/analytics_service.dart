import '../data/models/contract_stage.dart';
import '../data/models/deal.dart';
import 'finance_calculator.dart';

/// Aggregated figures for one calendar month.
class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.contractCount,
    required this.turnoverUsd,
    required this.revenueExVatUsd,
    required this.netProfitUsd,
    required this.vatRefundUsd,
    required this.vatRefundPendingUsd,
    required this.stageCounts,
  });

  /// First day of the month.
  final DateTime month;
  final int contractCount;
  final double turnoverUsd;
  final double revenueExVatUsd;
  final double netProfitUsd;

  /// Our share of VAT refunds (VAT bonus), counted in profit or not.
  final double vatRefundUsd;

  /// Part of [vatRefundUsd] not yet received.
  final double vatRefundPendingUsd;
  final Map<ContractStage, int> stageCounts;

  double get marginPercent {
    if (revenueExVatUsd <= 0) return 0;
    return netProfitUsd / revenueExVatUsd * 100;
  }
}

class AnalyticsService {
  const AnalyticsService();

  static DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

  List<Deal> dealsInMonth(List<Deal> deals, DateTime month) {
    final m = monthOf(month);
    return deals.where((d) => monthOf(d.reportingDate) == m).toList();
  }

  MonthlySummary summarize(List<Deal> deals, DateTime month) {
    final inMonth = dealsInMonth(deals, month);
    var turnover = 0.0;
    var revenueExVat = 0.0;
    var profit = 0.0;
    var refund = 0.0;
    var pending = 0.0;
    final stages = {for (final s in ContractStage.values) s: 0};
    for (final d in inMonth) {
      final p = DealProfit.of(d);
      turnover += p.turnoverUsd;
      revenueExVat += p.revenueExVatUsd;
      profit += p.netProfitUsd;
      refund += p.vatBonusUsd;
      if (!d.vatRefundReceived) pending += p.vatBonusUsd;
      stages[d.stage] = stages[d.stage]! + 1;
    }
    return MonthlySummary(
      month: monthOf(month),
      contractCount: inMonth.length,
      turnoverUsd: turnover,
      revenueExVatUsd: revenueExVat,
      netProfitUsd: profit,
      vatRefundUsd: refund,
      vatRefundPendingUsd: pending,
      stageCounts: stages,
    );
  }

  /// Summaries for [count] months ending with [lastMonth] (oldest first).
  List<MonthlySummary> trailing(
    List<Deal> deals,
    DateTime lastMonth,
    int count,
  ) {
    final end = monthOf(lastMonth);
    return [
      for (var i = count - 1; i >= 0; i--)
        summarize(deals, DateTime(end.year, end.month - i)),
    ];
  }
}
