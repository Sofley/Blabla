import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/currency.dart';
import '../../../domain/price_calculator.dart';
import '../../common/widgets.dart';

class PriceColors {
  static const exw = Color(0xFF8A5A14);
  static const logistics = Color(0xFF3E7C91);
  static const agent = Color(0xFFB07D2A);
  static const vat = Color(0xFF8C6BC8);
  static const profit = Color(0xFF1E7F4F);
}

/// Selling price per unit with a stacked structure bar.
class SalePriceCard extends StatelessWidget {
  const SalePriceCard({super.key, required this.b});

  final PriceBreakdown b;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final q = b.q;
    final c = q.currency;
    final unit = q.unit.isEmpty ? s.perUnitShort : '/ ${q.unit}';

    final parts = [
      (s.exwPrice, b.goodsPerUnit, PriceColors.exw),
      (s.logisticsShort, b.logisticsPerUnit, PriceColors.logistics),
      (s.agentShort, b.agentPerUnit, PriceColors.agent),
      if (q.vatEnabled) (s.vat, b.vatPerUnit, PriceColors.vat),
      (s.myProfitShort, b.profitPerUnit, PriceColors.profit),
    ];

    return SectionCard(
      title: s.salePrice,
      trailing: Text(c.code, style: theme.textTheme.labelSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fmt.price(b.salePricePerUnit, c),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppTheme.tabularFigures,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 14,
              child: b.salePricePerUnit <= 0
                  ? Container(color: theme.colorScheme.outlineVariant)
                  : Row(
                      children: [
                        for (final (_, v, color) in parts)
                          if (v > 0)
                            Expanded(
                              flex: (v / b.salePricePerUnit * 1000)
                                  .round()
                                  .clamp(1, 1000),
                              child: Container(color: color),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final (label, v, color) in parts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$label ${fmt.price(v, c, symbol: false)} (${fmt.percent((b.share(v) * 100).roundToDouble())})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Totals for the whole batch, including VAT refund and final profit.
class BatchTotalsCard extends StatelessWidget {
  const BatchTotalsCard({super.key, required this.b});

  final PriceBreakdown b;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final colors = FinanceColors.of(context);
    final q = b.q;
    final c = q.currency;
    final qty =
        '${Fmt.editable(q.quantity).isEmpty ? '0' : fmt.number(q.quantity)} ${q.unit}'
            .trim();

    return SectionCard(
      title: '${s.forWholeBatch} · $qty',
      trailing: Text(c.code, style: Theme.of(context).textTheme.labelSmall),
      child: Column(
        children: [
          AmountRow(
            label: s.saleAmountContract1,
            value: fmt.money(b.saleTotal, c),
          ),
          AmountRow(
            label: s.purchaseAmountContract2,
            value: '− ${fmt.money(b.purchaseTotal, c)}',
          ),
          AmountRow(
            label: s.logistics,
            value: '− ${fmt.money(b.logisticsTotal, c)}',
          ),
          AmountRow(
            label: '${s.agentFee} · ${fmt.percent(q.agentPercent)}',
            value: '− ${fmt.money(b.agentTotal, c)}',
          ),
          if (q.vatEnabled)
            AmountRow(
              label: '${s.vat} · ${fmt.percent(q.vatPercent)}',
              value: '− ${fmt.money(b.vatTotal, c)}',
            ),
          const Divider(height: 16),
          AmountRow(
            label: q.profitIsPercent
                ? '${s.myProfit} · ${fmt.percent(q.profitValue)}'
                : s.myProfit,
            value: fmt.money(b.markupTotal, c),
            valueColor: colors.signed(b.markupTotal),
          ),
          if (q.vatRefundEnabled && b.vatBonusTotal > 0)
            AmountRow(
              label: q.vatBonusInProfit
                  ? '${s.vatBonus} · ${fmt.percent(q.vatBonusShare)}'
                  : s.vatBonusReferenceShort,
              value: q.vatBonusInProfit
                  ? '+ ${fmt.money(b.vatBonusTotal, c)}'
                  : fmt.money(b.vatBonusTotal, c),
              valueColor: q.vatBonusInProfit
                  ? colors.refund
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          const Divider(height: 16),
          AmountRow(
            label: s.totalProfitIntermediary,
            value: fmt.money(b.totalProfit, c),
            valueColor: colors.signed(b.totalProfit),
            emphasize: true,
          ),
          AmountRow(
            label: s.profitPerUnit,
            value: fmt.price(b.totalProfitPerUnit, c),
          ),
          AmountRow(
            label: s.marginOfSale,
            value: fmt.percent(b.marginPercent),
            valueColor: colors.signed(b.marginPercent),
          ),
          if (c != Currency.usd)
            AmountRow(
              label: '${s.totalProfit}, USD',
              value: fmt.money(b.toUsd(b.totalProfit)),
            ),
        ],
      ),
    );
  }
}
