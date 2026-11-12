import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/trade_contract.dart';
import '../../domain/finance_calculator.dart';
import '../../state/deals_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../state/chat_controller.dart';
import '../../state/auth_controller.dart';
import '../../state/widget_sync.dart';
import '../../data/models/deal.dart';
import '../assistant/assistant_screen.dart';
import '../chat/chat_screens.dart';
import 'widgets/deal_kind_widgets.dart';
import '../common/export_sheet.dart';
import '../common/widgets.dart';
import 'deal_editor_screen.dart';
import 'widgets/finance_cards.dart';
import 'widgets/status_tracker.dart';
import 'widgets/deal_sections.dart';
import 'widgets/dossier.dart';

class DealDetailScreen extends StatelessWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  static Future<void> open(BuildContext context, String dealId) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: dealId)));

  Future<void> _moveToTrash(BuildContext context) async {
    final s = context.s;
    final controller = context.read<DealsController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.moveToTrashQuestion),
        content: Text(s.moveToTrashHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.moveToTrash),
          ),
        ],
      ),
    );
    if (ok != true) return;
    navigator.pop();
    await controller.delete(dealId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(s.movedToTrash),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () => controller.restore(dealId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final controller = context.watch<DealsController>();
    final policy = context.watch<AuthController>().policy;
    final deal = controller.byId(dealId);
    if (deal == null) {
      return Scaffold(appBar: AppBar());
    }
    final next = deal.stage.next;
    final inTrash = deal.isDeleted;
    final canStage = policy.canChangeStages && !inTrash;
    final chatCount = context.watch<ChatController>().messages(deal.id).length;
    final finance = policy.seesFinance;

    return Scaffold(
      appBar: AppBar(
        title: Text(deal.displayTitle),
        actions: [
          if (policy.seesContractSums)
            IconButton(
              tooltip: s.exportTitle,
              icon: const Icon(Icons.ios_share),
              // Non-owners can export only the buyer document; the
              // internal report never leaves the owner's session.
              onPressed: () => finance
                  ? showExportSheet(
                      context,
                      build: (b) => b.deal(deal),
                      variants: [
                        (
                          s.docForBuyer,
                          Icons.person_outline,
                          (b) => b.buyerContract(deal),
                        ),
                        (
                          s.docInternal,
                          Icons.lock_outline,
                          (b) => b.deal(deal),
                        ),
                      ],
                    )
                  : showExportSheet(
                      context,
                      build: (b) => b.buyerContract(deal),
                    ),
            ),
          if (!inTrash)
            Builder(
              builder: (context) {
                final w = context.watch<WidgetSync>();
                final pinned = w.selectedDealId == deal.id;
                return IconButton(
                  tooltip: pinned ? s.shownInWidget : s.showInWidget,
                  icon: Icon(pinned ? Icons.widgets : Icons.widgets_outlined),
                  onPressed: () {
                    w.select(pinned ? null : deal.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          pinned ? s.widgetDealAuto : s.shownInWidget,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          if (finance && !inTrash)
            IconButton(
              tooltip: s.assistantAsk,
              icon: const Icon(Icons.auto_awesome),
              onPressed: () => AssistantScreen.open(context, dealId: deal.id),
            ),
          if (policy.canUseChat && !inTrash)
            IconButton(
              tooltip: s.chatTitle,
              icon: Badge(
                isLabelVisible: chatCount > 0,
                label: Text('$chatCount'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              onPressed: () => ChatScreen.open(context, deal.id),
            ),
          if (policy.canEditDeals && !inTrash)
            IconButton(
              tooltip: s.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => DealEditorScreen.open(context, dealId: deal.id),
            ),
          if (policy.canDeleteDeals && !inTrash)
            IconButton(
              tooltip: s.moveToTrash,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _moveToTrash(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (inTrash) ...[TrashBanner(deal: deal), const SizedBox(height: 12)],
          PartiesStrip(
            threeParty: deal.isThreeParty,
            twoParty: deal.isTwoParty,
          ),
          if (deal.isThreeParty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(roleIcon(deal.role), size: 16),
                label: Text('${s.companyStatus}: ${s.roleTitle(deal.role)}'),
                onDeleted: () => showRoleInfo(context, deal.role),
                deleteIcon: const Icon(Icons.info_outline, size: 16),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (finance) ...[
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
                  onChanged: inTrash
                      ? null
                      : (v) => controller.setVatRefundReceived(deal.id, v),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: s.statusTracker,
            trailing: StageBadge(stage: deal.stage),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusTracker(
                  stage: deal.stage,
                  stageDates: deal.stageDates,
                  onStageSelected: canStage
                      ? (st) => controller.setStage(deal.id, st)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  canStage ? s.tapStageHint : s.paymentStageHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (next != null && canStage) ...[
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
          const SizedBox(height: 12),
          DeliveryInfoCard(deal: deal, editable: canStage),
          if (policy.canSeeClients || policy.canManageUsers) ...[
            const SizedBox(height: 12),
            DealAccessCard(deal: deal, editable: !inTrash),
          ],
          // Team roles manage the dossier; clients and partners see only
          // documents marked "visible to client" (read only).
          if (policy.canManageDocuments || deal.documents.isNotEmpty) ...[
            const SizedBox(height: 12),
            OfficialContractCard(
              deal: deal,
              editable: policy.canManageDocuments && !inTrash,
            ),
            const SizedBox(height: 12),
            DossierCard(
              deal: deal,
              editable: policy.canManageDocuments && !inTrash,
            ),
          ],
          if (finance && deal.snapshots.isNotEmpty) ...[
            const SizedBox(height: 12),
            SnapshotsCard(deal: deal),
          ],
          if (deal.stageHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            StageHistoryCard(deal: deal),
          ],
          const SizedBox(height: 20),
          if (finance) ...[
            _ContractOverview(
              contract: deal.buyerContract,
              kind: deal.kind,
              sellerName: deal.sellerContract.counterpartyName,
            ),
            const SizedBox(height: 20),
            _ContractOverview(contract: deal.sellerContract, kind: deal.kind),
          ] else
            ContractSummaryCard(deal: deal, policy: policy),
        ],
      ),
    );
  }
}

/// Read-only block for one contract: requisites, parties, calculation, notes.
class _ContractOverview extends StatelessWidget {
  const _ContractOverview({
    required this.contract,
    required this.kind,
    this.sellerName = '',
  });

  final TradeContract contract;
  final DealKind kind;

  /// Seller of a two-party contract (stored on the internal side).
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final accent = accentFor(context, contract.side);
    String orDash(String v) => v.trim().isEmpty ? '—' : v;
    // Empty optional amounts read «Не задано»; a confirmed zero reads 0.
    String opt(double? v) => v == null ? s.notSetValue : Fmt.editableOpt(v);

    final parties = kind == DealKind.twoParty
        ? [
            AmountRow(
              label: s.counterpartyLabel(ContractSide.buyer),
              value: orDash(contract.counterpartyName),
            ),
            if (contract.side == ContractSide.buyer)
              AmountRow(
                label: s.counterpartyLabel(ContractSide.seller),
                value: orDash(sellerName),
              ),
          ]
        : contract.side == ContractSide.buyer
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
                kind != DealKind.backToBack
                    ? (contract.side == ContractSide.buyer
                          ? (kind == DealKind.twoParty
                                ? s.twoPartyContract
                                : s.singleContract)
                          : s.internalCalc)
                    : s.contractTitle(contract.side),
                style: theme.textTheme.titleMedium?.copyWith(color: accent),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  kind != DealKind.backToBack
                      ? (contract.side == ContractSide.buyer
                            ? (kind == DealKind.twoParty
                                  ? s.twoPartiesShort
                                  : s.threePartiesShort)
                            : s.internalOnlyShort)
                      : s.contractParties(contract.side),
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
              if (contract.side == ContractSide.seller ||
                  contract.logisticsEntered)
                AmountRow(
                  label: s.logistics,
                  value: contract.logisticsEntered
                      ? fmt.money(
                          contract.logisticsTotal,
                          contract.logisticsCurrency,
                        )
                      : s.notSetValue,
                  caption: contract.logisticsMethod == LogisticsMethod.manual
                      ? [
                          '${s.transport} ${opt(contract.transportCost)}',
                          '${s.freight} ${opt(contract.freightCost)}',
                          '${s.portFees} ${opt(contract.portFees)}',
                        ].join(' · ')
                      : [
                          '${contract.logisticsMethod == LogisticsMethod.perTonne ? s.ratePerTonne : s.ratePerTransportUnit} ${opt(contract.logisticsRate)}',
                          if (contract.logisticsMethod ==
                              LogisticsMethod.perTransportUnit)
                            '× ${contract.transportUnits ?? s.notSetValue}'
                          else
                            '× ${contract.tonnes == null ? s.notSetValue : '${Fmt.editable(contract.tonnes!)} t'}',
                          '${s.portFees} ${opt(contract.portFees)}',
                        ].join(' · '),
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
