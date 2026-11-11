import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/contract_stage.dart';
import '../../data/models/deal.dart';
import '../../domain/finance_calculator.dart';
import '../../state/deals_controller.dart';
import '../common/export_sheet.dart';
import '../home_shell.dart';
import '../common/widgets.dart';
import 'deal_detail_screen.dart';
import 'widgets/status_tracker.dart';

class DealsListScreen extends StatefulWidget {
  const DealsListScreen({super.key});

  @override
  State<DealsListScreen> createState() => _DealsListScreenState();
}

class _DealsListScreenState extends State<DealsListScreen> {
  String _query = '';
  ContractStage? _stage;

  bool _matches(Deal d) {
    if (_stage != null && d.stage != _stage) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [
      d.buyerContract.number,
      d.sellerContract.number,
      d.buyerContract.counterpartyName,
      d.sellerContract.counterpartyName,
      d.buyerContract.intermediaryName,
      d.sellerContract.intermediaryName,
    ].any((v) => v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final all = context.watch<DealsController>().deals;
    final deals = all.where(_matches).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navDeals),
        actions: [
          const SettingsButton(),
          IconButton(
            tooltip: s.exportRegistry,
            icon: const Icon(Icons.ios_share),
            onPressed: deals.isEmpty
                ? null
                : () => showExportSheet(
                    context,
                    build: (b) => b.registry(
                      deals,
                      _stage == null ? s.allDeals : s.stage(_stage!),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: s.search,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ChoiceChip(
                  label: Text(s.all),
                  selected: _stage == null,
                  onSelected: (_) => setState(() => _stage = null),
                ),
                for (final st in ContractStage.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(s.stage(st)),
                    selected: _stage == st,
                    onSelected: (_) =>
                        setState(() => _stage = _stage == st ? null : st),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: deals.isEmpty
                ? _EmptyState(
                    title: all.isEmpty ? s.noDeals : s.noDealsForFilter,
                    hint: all.isEmpty ? s.noDealsHint : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: deals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => DealCard(deal: deals[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final p = DealProfit.of(deal);
    String orDash(String v) => v.trim().isEmpty ? '—' : v;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => DealDetailScreen.open(context, deal.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deal.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (deal.isThreeParty) ...[
                    Icon(
                      Icons.hub_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  StageBadge(stage: deal.stage),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${orDash(deal.buyerContract.counterpartyName)}  ⟵  '
                '${orDash(deal.buyerContract.intermediaryName)}  ⟵  '
                '${orDash(deal.sellerContract.counterpartyName)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              StageProgressBar(stage: deal.stage),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    fmt.date(deal.reportingDate),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  _Figure(label: s.turnover, value: fmt.money(p.turnoverUsd)),
                  const SizedBox(width: 16),
                  _Figure(
                    label: s.netProfit,
                    value: fmt.money(p.netProfitUsd),
                    color: colors.signed(p.netProfitUsd),
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

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
