import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/price_calculator.dart';
import '../../state/quotes_controller.dart';
import 'quote_editor_screen.dart';

/// "Цена" tab: saved price calculations.
class QuotesListScreen extends StatelessWidget {
  const QuotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final quotes = context.watch<QuotesController>().quotes;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.priceCalculator)),
      body: quotes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      size: 48,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(s.noQuotes, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      s.noQuotesHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: quotes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _QuoteCard(id: quotes[i].id),
            ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final q = context.watch<QuotesController>().byId(id)!;
    final b = PriceBreakdown(q);
    final c = q.currency;

    Widget fig(String label, String value, [Color? color]) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: AppTheme.tabularFigures,
          ),
        ),
      ],
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => QuoteEditorScreen.open(context, quoteId: id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.productName.isEmpty ? '—' : q.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (q.buyerName.isNotEmpty) q.buyerName,
                  '${fmt.number(q.quantity)} ${q.unit}'.trim(),
                  q.incoterms,
                  fmt.date(q.updatedAt),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${fmt.price(b.salePricePerUnit, c)} ${q.unit.isEmpty ? s.perUnitShort : '/ ${q.unit}'}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                  ),
                  fig(s.saleAmount, fmt.money(b.saleTotal, c)),
                  const SizedBox(width: 16),
                  fig(
                    s.totalProfit,
                    fmt.money(b.totalProfit, c),
                    colors.signed(b.totalProfit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
