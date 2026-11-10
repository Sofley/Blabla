import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/contract_stage.dart';
import '../../domain/analytics_service.dart';
import '../../state/deals_controller.dart';
import '../common/export_sheet.dart';
import '../common/widgets.dart';
import '../deals/deals_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _analytics = AnalyticsService();
  DateTime _month = AnalyticsService.monthOf(DateTime.now());

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final deals = context.watch<DealsController>().deals;

    final summary = _analytics.summarize(deals, _month);
    final trend = _analytics.trailing(deals, _month, 6);
    final monthDeals = _analytics.dealsInMonth(deals, _month);
    final isCurrentMonth = _month == AnalyticsService.monthOf(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(s.monthlyAnalytics),
        actions: [
          IconButton(
            tooltip: s.exportMonth,
            icon: const Icon(Icons.ios_share),
            onPressed: () => showExportSheet(
              context,
              build: (b) => b.registry(monthDeals, fmt.month(_month)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          // Month switcher
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Text(
                  fmt.month(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrentMonth ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // KPI tiles
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  icon: Icons.description_outlined,
                  label: s.contractsCount,
                  value: '${summary.contractCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  icon: Icons.percent,
                  label: s.margin,
                  value: fmt.percent(summary.marginPercent),
                  valueColor: colors.signed(summary.marginPercent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MetricTile(
            icon: Icons.swap_horiz,
            label: s.turnover,
            value: fmt.money(summary.turnoverUsd),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MetricTile(
                  icon: Icons.trending_up,
                  label: s.netProfit,
                  value: fmt.money(summary.netProfitUsd),
                  valueColor: colors.signed(summary.netProfitUsd),
                  footnote: s.markupPlusRefund,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  icon: Icons.replay_circle_filled_outlined,
                  label: s.vatRefund,
                  value: fmt.money(summary.vatRefundUsd),
                  valueColor: colors.refund,
                  footnote: summary.vatRefundPendingUsd > 0
                      ? '${s.pending}: ${fmt.money(summary.vatRefundPendingUsd)}'
                      : s.allReceived,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              s.allValuesInUsd,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: s.last6Months,
            child: _ProfitBars(data: trend, selected: _month),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: s.stagesBreakdown,
            child: Column(
              children: [
                for (final st in ContractStage.values)
                  _StageRow(
                    stage: st,
                    count: summary.stageCounts[st] ?? 0,
                    total: summary.contractCount,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              s.recentDeals.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (monthDeals.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  s.noDealsThisMonth,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final d in monthDeals) ...[
              DealCard(deal: d),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// Minimal bar chart of monthly net profit (supports negative values).
class _ProfitBars extends StatelessWidget {
  const _ProfitBars({required this.data, required this.selected});

  final List<MonthlySummary> data;
  final DateTime selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final fmt = Fmt.of(context);
    final maxAbs = data
        .map((m) => m.netProfitUsd.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    const chartHeight = 120.0;

    return Column(
      children: [
        SizedBox(
          height: chartHeight + 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in data)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FittedBox(
                        child: Text(
                          m.netProfitUsd == 0
                              ? ''
                              : fmt.moneyCompact(m.netProfitUsd),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.signed(m.netProfitUsd),
                            fontFeatures: AppTheme.tabularFigures,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        height: maxAbs == 0
                            ? 2
                            : (m.netProfitUsd.abs() / maxAbs * chartHeight)
                                  .clamp(2, chartHeight),
                        decoration: BoxDecoration(
                          color: m.netProfitUsd < 0
                              ? colors.negative
                              : (m.month == selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.primary.withValues(
                                        alpha: 0.35,
                                      )),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final m in data)
              Expanded(
                child: Text(
                  fmt.monthShort(m.month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: m.month == selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.count,
    required this.total,
  });

  final ContractStage stage;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = StageBadge.colorFor(context, stage);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(StageBadge.iconFor(stage), size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              context.s.stage(stage),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                minHeight: 6,
                color: color,
                backgroundColor: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
