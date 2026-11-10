import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/currency.dart';
import '../../../data/models/trade_contract.dart';
import '../../../domain/finance_calculator.dart';
import '../../common/widgets.dart';

Color accentFor(BuildContext context, ContractSide side) {
  final f = FinanceColors.of(context);
  return side == ContractSide.buyer ? f.buyerAccent : f.sellerAccent;
}

/// Live breakdown of one contract (goods, logistics, agency, VAT, total).
class ContractCalculationCard extends StatelessWidget {
  const ContractCalculationCard({super.key, required this.contract});

  final TradeContract contract;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final f = ContractFinancials.of(contract);
    final theme = Theme.of(context);

    return SectionCard(
      title: s.calculator,
      accent: accentFor(context, contract.side),
      trailing: Text(
        kReportingCurrency.code,
        style: theme.textTheme.labelSmall,
      ),
      child: Column(
        children: [
          AmountRow(label: s.goods, value: fmt.money(f.goodsUsd)),
          AmountRow(label: s.logistics, value: fmt.money(f.logisticsUsd)),
          AmountRow(
            label: '${s.agency} · ${fmt.percent(contract.agencyFeePercent)}',
            value: fmt.money(f.agencyFeeUsd),
          ),
          const Divider(height: 16),
          AmountRow(label: s.netAmount, value: fmt.money(f.netUsd)),
          AmountRow(
            label: '${s.vat} · ${fmt.percent(contract.effectiveVatPercent)}',
            value: fmt.money(f.vatUsd),
          ),
          const Divider(height: 16),
          AmountRow(
            label: s.contractTotal,
            value: fmt.money(f.totalUsd),
            emphasize: true,
          ),
          if (contract.currency != kReportingCurrency)
            AmountRow(
              label: s.inContractCurrency,
              value: fmt.money(f.totalInContractCurrency, contract.currency),
            ),
          if (f.quantity > 0 && f.quantity != 1)
            AmountRow(
              label: s.perUnitTotal,
              value: fmt.price(f.totalPerUnitUsd, kReportingCurrency),
            ),
          if (f.vatRefundUsd > 0) ...[
            const Divider(height: 16),
            AmountRow(
              label:
                  '${s.vatRefund} · ${fmt.percent(contract.vatRefundPercent)}',
              value: '+ ${fmt.money(f.vatRefundUsd)}',
              valueColor: FinanceColors.of(context).refund,
            ),
          ],
        ],
      ),
    );
  }
}

/// Net profit of the deal: Contract #1 vs Contract #2.
class ProfitCard extends StatelessWidget {
  const ProfitCard({super.key, required this.profit, this.showFormula = true});

  final DealProfit profit;
  final bool showFormula;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final colors = FinanceColors.of(context);
    final theme = Theme.of(context);
    final p = profit;

    return SectionCard(
      title: s.profitCalculator,
      accent: colors.signed(p.netProfitUsd),
      trailing: Text(
        kReportingCurrency.code,
        style: theme.textTheme.labelSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.netProfit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fmt.money(p.netProfitUsd),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colors.signed(p.netProfitUsd),
                          fontWeight: FontWeight.w700,
                          fontFeatures: AppTheme.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.margin,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    fmt.percent(p.marginPercent),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.signed(p.marginPercent),
                      fontFeatures: AppTheme.tabularFigures,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          AmountRow(label: s.revenue, value: fmt.money(p.turnoverUsd)),
          AmountRow(
            label: s.outputVat,
            value: '− ${fmt.money(p.outputVatUsd)}',
          ),
          AmountRow(label: s.expenses, value: '− ${fmt.money(p.expensesUsd)}'),
          if (p.vatRefundUsd > 0)
            AmountRow(
              label: s.vatRefund,
              value: '+ ${fmt.money(p.vatRefundUsd)}',
              valueColor: colors.refund,
            ),
          const Divider(height: 16),
          AmountRow(
            label: s.netProfit,
            value: fmt.money(p.netProfitUsd),
            valueColor: colors.signed(p.netProfitUsd),
            emphasize: true,
          ),
          if (showFormula) ...[
            const SizedBox(height: 8),
            Text(
              s.profitFormula,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
