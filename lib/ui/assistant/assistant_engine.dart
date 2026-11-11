import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/contract_stage.dart';
import '../../data/models/currency.dart';
import '../../data/models/deal.dart';
import '../../data/models/price_quote.dart';
import '../../domain/analytics_service.dart';
import '../../domain/finance_calculator.dart';
import '../../domain/price_calculator.dart';
import '../../state/rates_controller.dart';

enum InsightLevel { good, info, warning, danger }

class Insight {
  const Insight(this.level, this.text);

  final InsightLevel level;
  final String text;
}

/// Offline, rule-based business assistant. Everything is computed on the
/// phone from the user's own calculations — no internet, no AI service.
class AssistantEngine {
  AssistantEngine(this.s, this.fmt, this.rates, {DateTime? now})
    : now = now ?? DateTime.now();

  final AppStrings s;
  final Fmt fmt;
  final RatesController? rates;
  final DateTime now;

  static const lowMargin = 5.0;
  static const highMargin = 30.0;
  static const logisticsWarnShare = .25;
  static const agentWarn = 10.0;
  static const staleDays = 3;

  // ---------------- Price calculation ----------------

  List<Insight> quote(PriceQuote q) {
    final b = PriceBreakdown(q);
    final c = q.currency;
    final out = <Insight>[
      Insight(
        InsightLevel.info,
        s.aiQuoteHeadline(
          q.productName.isEmpty ? '—' : q.productName,
          fmt.price(b.salePricePerUnit, c),
          fmt.money(b.totalProfit, c),
          fmt.percent(_r1(b.marginPercent)),
        ),
      ),
      ..._margin(b.marginPercent, b.totalProfit, (v) => fmt.money(v, c)),
    ];
    if (b.salePricePerUnit > 0) {
      final share = b.logisticsPerUnit / b.salePricePerUnit;
      if (share > logisticsWarnShare) {
        out.add(
          Insight(
            InsightLevel.warning,
            s.aiLogisticsShare(fmt.percent(_r1(share * 100))),
          ),
        );
      }
    }
    out.addAll(_agent(q.agentPercent));
    out.add(
      Insight(InsightLevel.info, s.aiBreakEven(fmt.price(b.costPerUnit, c))),
    );
    if (b.marginPercent < 10 && b.costPerUnit > 0) {
      // price p with (p − cost + bonus) / p = 10 %
      final bonus = b.vatBonusInProfitPerUnit;
      final p = (b.costPerUnit - bonus) / .9;
      out.add(
        Insight(
          InsightLevel.info,
          s.aiPriceForMargin(fmt.percent(10), fmt.price(p, c)),
        ),
      );
    }
    // Rounding: 2.3035 → 2.31
    final cents = b.salePricePerUnit * 100;
    if (q.profitMode != ProfitMode.salePrice &&
        (cents - cents.roundToDouble()).abs() > 1e-6 &&
        q.quantity > 0) {
      final rounded = cents.ceilToDouble() / 100;
      final gain = (rounded - b.salePricePerUnit) * q.quantity;
      out.add(
        Insight(
          InsightLevel.info,
          s.aiRoundPrice(fmt.price(rounded, c), fmt.money(gain, c)),
        ),
      );
    }
    out.addAll(
      _bonus(
        enabled: q.vatRefundEnabled,
        bonus: b.vatBonusTotal,
        inProfit: q.vatBonusInProfit,
        profitWithBonus: b.markupTotal + b.vatBonusTotal,
        money: (v) => fmt.money(v, c),
      ),
    );
    out.addAll(_stale(q.updatedAt));
    if (c != Currency.usd) out.addAll(ratesStatus());
    return out;
  }

  // ---------------- Deal ----------------

  List<Insight> deal(Deal d) {
    final p = DealProfit.of(d);
    final out = <Insight>[
      Insight(
        InsightLevel.info,
        s.aiDealHeadline(
          d.displayTitle,
          fmt.money(p.netProfitUsd),
          fmt.percent(_r1(p.marginPercent)),
        ),
      ),
      ..._margin(p.marginPercent, p.netProfitUsd, fmt.money),
    ];
    if (p.revenueExVatUsd > 0) {
      final share = p.purchase.logisticsUsd / p.revenueExVatUsd;
      if (share > logisticsWarnShare) {
        out.add(
          Insight(
            InsightLevel.warning,
            s.aiLogisticsShare(fmt.percent(_r1(share * 100))),
          ),
        );
      }
    }
    out.addAll(_agent(d.sellerContract.agencyFeePercent));
    if (d.buyerContract.quantity > 0) {
      final unit = d.buyerContract.unit.isEmpty
          ? ''
          : ' / ${d.buyerContract.unit}';
      final breakEven =
          (p.expensesUsd - p.vatBonusInProfitUsd) / d.buyerContract.quantity;
      out.add(
        Insight(
          InsightLevel.info,
          '${s.aiBreakEven(fmt.price(breakEven, kReportingCurrency))}$unit',
        ),
      );
    }
    final b = d.buyerContract;
    if (b.logisticsTotal > 0 || b.agencyFeePercent > 0) {
      out.add(Insight(InsightLevel.warning, s.aiBuyerHasInternal));
    }
    if (b.number.trim().isEmpty || d.sellerContract.number.trim().isEmpty) {
      out.add(Insight(InsightLevel.warning, s.aiMissingNumbers));
    }
    out.addAll(
      _bonus(
        enabled: d.sellerContract.vatRefundEnabled || b.vatRefundEnabled,
        bonus: p.vatBonusUsd,
        inProfit: p.vatBonusInProfitUsd > 0,
        profitWithBonus: p.markupUsd + p.vatBonusUsd,
        money: fmt.money,
      ),
    );
    if (d.stage == ContractStage.closed &&
        p.vatBonusUsd > 0 &&
        !d.vatRefundReceived) {
      out.add(Insight(InsightLevel.warning, s.aiRefundPending));
    }
    if (d.isThreeParty && d.role == CompanyRole.payer) {
      out.add(Insight(InsightLevel.info, s.aiPayerTerms));
    }
    // FX drift of the factory contract.
    final sc = d.sellerContract;
    final live = rates?.ratePerUsd(sc.currency);
    if (sc.currency != Currency.usd && live != null && sc.goodsRatePerUsd > 0) {
      final drift = (live - sc.goodsRatePerUsd).abs() / sc.goodsRatePerUsd;
      if (drift > .02) {
        out.add(
          Insight(
            InsightLevel.warning,
            s.aiFxDiff(
              Fmt.editable(sc.goodsRatePerUsd),
              Fmt.editable(_r4(live)),
            ),
          ),
        );
      }
    }
    if (d.stage != ContractStage.closed) out.addAll(_stale(d.updatedAt));
    return out;
  }

  // ---------------- Month ----------------

  List<Insight> month(List<Deal> deals) {
    const a = AnalyticsService();
    final cur = a.summarize(deals, now);
    final prev = a.summarize(deals, DateTime(now.year, now.month - 1));
    final out = <Insight>[
      Insight(
        InsightLevel.info,
        s.aiMonthSummary(
          cur.contractCount,
          fmt.money(cur.netProfitUsd),
          fmt.percent(_r1(cur.marginPercent)),
        ),
      ),
    ];
    final low = a
        .dealsInMonth(deals, now)
        .where((d) => DealProfit.of(d).marginPercent < lowMargin)
        .length;
    if (low > 0) out.add(Insight(InsightLevel.warning, s.aiMonthLow(low)));
    if (cur.vatRefundPendingUsd > 0) {
      out.add(
        Insight(
          InsightLevel.info,
          s.aiMonthPending(fmt.money(cur.vatRefundPendingUsd)),
        ),
      );
    }
    if (prev.contractCount > 0) {
      final delta = cur.netProfitUsd - prev.netProfitUsd;
      out.add(
        Insight(
          delta >= 0 ? InsightLevel.good : InsightLevel.warning,
          s.aiMonthTrend('${delta >= 0 ? '+' : '−'}${fmt.money(delta.abs())}'),
        ),
      );
    }
    return out;
  }

  // ---------------- Rates ----------------

  List<Insight> ratesStatus() {
    final r = rates;
    if (r == null) return const [];
    final at = r.fetchedAt;
    if (at == null) return [Insight(InsightLevel.warning, s.aiRatesNever)];
    final days = now.difference(at).inDays;
    if (days >= staleDays) {
      return [Insight(InsightLevel.warning, s.aiRatesStale(days))];
    }
    final cny = r.ratePerUsd(Currency.cny);
    return [
      Insight(
        InsightLevel.good,
        s.aiRatesFresh(cny == null ? '—' : Fmt.editable(_r4(cny))),
      ),
    ];
  }

  // ---------------- Shared rules ----------------

  List<Insight> _margin(
    double margin,
    double profit,
    String Function(double) money,
  ) {
    if (profit < 0) {
      return [Insight(InsightLevel.danger, s.aiLoss(money(profit.abs())))];
    }
    final m = fmt.percent(_r1(margin));
    if (margin < lowMargin) {
      return [Insight(InsightLevel.warning, s.aiLowMargin(m))];
    }
    if (margin > highMargin) {
      return [Insight(InsightLevel.info, s.aiHighMargin(m))];
    }
    return [Insight(InsightLevel.good, s.aiGoodMargin(m))];
  }

  List<Insight> _agent(double percent) => [
    if (percent > agentWarn)
      Insight(InsightLevel.warning, s.aiAgentHigh(fmt.percent(percent))),
    Insight(InsightLevel.good, s.aiAgentHidden),
  ];

  List<Insight> _bonus({
    required bool enabled,
    required double bonus,
    required bool inProfit,
    required double profitWithBonus,
    required String Function(double) money,
  }) {
    if (!enabled) return [Insight(InsightLevel.info, s.aiRefundOff)];
    if (bonus <= 0) return const [];
    return [
      inProfit
          ? Insight(InsightLevel.good, s.aiBonusOn(money(bonus)))
          : Insight(
              InsightLevel.info,
              s.aiBonusOff(money(bonus), money(profitWithBonus)),
            ),
    ];
  }

  List<Insight> _stale(DateTime updated) {
    final days = now.difference(updated).inDays;
    return days > staleDays
        ? [Insight(InsightLevel.warning, s.aiStale(days))]
        : const [];
  }

  static double _r1(double v) => double.parse(v.toStringAsFixed(1));
  static double _r4(double v) => double.parse(v.toStringAsFixed(4));
}
