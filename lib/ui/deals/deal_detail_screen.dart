import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/trade_contract.dart';
import '../../domain/finance_calculator.dart';
import '../../state/deals_controller.dart';
import '../../core/theme/app_theme.dart';
import '../common/export_sheet.dart';
import '../common/widgets.dart';
import 'deal_editor_screen.dart';
import 'widgets/finance_cards.dart';
import 'widgets/status_tracker.dart';

class DealDetailScreen extends StatelessWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  static Future<void> open(BuildContext context, String dealId) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: dealId)));

  Future<void> _delete(BuildContext context) async {
    final s = context.s;
    final controller = context.read<DealsController>();
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteDealQuestion),
        content: Text(s.deleteDealHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      navigator.pop();
      await controller.delete(dealId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final controller = context.watch<DealsController>();
    final deal = controller.byId(dealId);
    if (deal == null) {
      return Scaffold(appBar: AppBar());
    }
    final next = deal.stage.next;

    return Scaffold(
      appBar: AppBar(
        title: Text(deal.displayTitle),
        actions: [
          IconButton(
            tooltip: s.exportTitle,
            icon: const Icon(Icons.ios_share),
            onPressed: () =>
                showExportSheet(context, build: (b) => b.deal(deal)),
          ),
          IconButton(
            tooltip: s.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => DealEditorScreen.open(context, dealId: deal.id),
          ),
          IconButton(
            tooltip: s.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          ProfitCard(profit: DealProfit.of(deal)),
          if (DealProfit.of(deal).vatRefundUsd > 0) ...[
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile.adaptive(
                secondary: Icon(
                  deal.vatRefundReceived
                      ? Icons.check_circle
                      : Icons.hourglass_bottom,
                  color: FinanceColors.of(context).refund,
                ),
                title: Text(s.vatRefundReceived),
                subtitle: Text(
                  deal.vatRefundReceived
                      ? s.refundReceivedHint
                      : s.refundPendingHint,
                ),
                value: deal.vatRefundReceived,
                onChanged: (v) => controller.setVatRefundReceived(deal.id, v),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: s.statusTracker,
            trailing: StageBadge(stage: deal.stage),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusTracker(
                  stage: deal.stage,
                  stageDates: deal.stageDates,
                  onStageSelected: (st) => controller.setStage(deal.id, st),
                ),
                const SizedBox(height: 4),
                Text(
                  s.tapStageHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (next != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => controller.setStage(deal.id, next),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text('${s.moveToNextStage}: ${s.stage(next)}'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ContractOverview(contract: deal.buyerContract),
          const SizedBox(height: 20),
          _ContractOverview(contract: deal.sellerContract),
        ],
      ),
    );
  }
}

/// Read-only block for one contract: requisites, parties, calculation, notes.
class _ContractOverview extends StatelessWidget {
  const _ContractOverview({required this.contract});

  final TradeContract contract;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final accent = accentFor(context, contract.side);
    String orDash(String v) => v.trim().isEmpty ? '—' : v;

    final parties = contract.side == ContractSide.buyer
        ? [
            AmountRow(
              label: s.counterpartyLabel(contract.side),
              value: orDash(contract.counterpartyName),
            ),
            AmountRow(
              label: s.intermediary,
              value: orDash(contract.intermediaryName),
            ),
          ]
        : [
            AmountRow(
              label: s.intermediary,
              value: orDash(contract.intermediaryName),
            ),
            AmountRow(
              label: s.counterpartyLabel(contract.side),
              value: orDash(contract.counterpartyName),
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                s.contractTitle(contract.side),
                style: theme.textTheme.titleMedium?.copyWith(color: accent),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  s.contractParties(contract.side),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: '${s.requisites} · ${s.parties}',
          accent: accent,
          child: Column(
            children: [
              AmountRow(
                label: s.contractNumber,
                value: orDash(contract.number),
              ),
              AmountRow(label: s.contractDate, value: fmt.date(contract.date)),
              const Divider(height: 16),
              ...parties,
              const Divider(height: 16),
              if (contract.productName.trim().isNotEmpty)
                AmountRow(label: s.productName, value: contract.productName),
              AmountRow(
                label: s.unitPrice,
                value: fmt.price(contract.unitPrice, contract.currency),
                caption:
                    '${s.quantity}: ${fmt.number(contract.quantity)} ${contract.unit}'
                        .trim(),
              ),
              AmountRow(
                label: s.goodsCost,
                value: fmt.money(contract.goodsCost, contract.currency),
                caption: contract.currency.code == 'USD'
                    ? null
                    : '1 USD = ${Fmt.editable(contract.goodsRatePerUsd)} ${contract.currency.code}',
              ),
              AmountRow(
                label: s.logistics,
                value: fmt.money(
                  contract.logisticsTotal,
                  contract.logisticsCurrency,
                ),
                caption:
                    '${s.transport} ${Fmt.editable(contract.transportCost).ifEmpty('0')} · '
                    '${s.freight} ${Fmt.editable(contract.freightCost).ifEmpty('0')} · '
                    '${s.portFees} ${Fmt.editable(contract.portFees).ifEmpty('0')}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ContractCalculationCard(contract: contract),
        const SizedBox(height: 12),
        SectionCard(
          title: s.notesSection,
          accent: accent,
          child: Text(
            contract.notes.trim().isEmpty ? '—' : contract.notes,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
