import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/deal.dart';
import '../../../data/models/trade_contract.dart';
import '../../../domain/access_policy.dart';
import '../../../domain/finance_calculator.dart';
import '../../../state/auth_controller.dart';
import '../../../state/clients_controller.dart';
import '../../../state/deals_controller.dart';
import '../../common/widgets.dart';

/// Shown on a deal that is in the trash: restore or delete for good.
class TrashBanner extends StatelessWidget {
  const TrashBanner({super.key, required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final policy = context.watch<AuthController>().policy;
    final left = deal.purgeAt!.difference(DateTime.now()).inDays + 1;
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${s.dealInTrash} · ${s.daysLeft(left.clamp(0, Deal.trashDays))}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(s.restoreDeal),
                  onPressed: () =>
                      context.read<DealsController>().restore(deal.id),
                ),
                if (policy.canPurge)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: Text(s.deleteForever),
                    onPressed: () => confirmPurge(context, deal.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks and deletes a deal from the trash for good.
Future<bool> confirmPurge(
  BuildContext context,
  String dealId, {
  bool pop = true,
}) async {
  final s = context.s;
  final controller = context.read<DealsController>();
  final navigator = Navigator.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.deleteForeverQuestion),
      content: Text(s.deleteForeverHint),
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
          child: Text(s.deleteForever),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  if (pop && navigator.canPop()) navigator.pop();
  await controller.purge(dealId);
  return true;
}

/// Delivery terms and dates — the part of logistics a client may see.
class DeliveryInfoCard extends StatelessWidget {
  const DeliveryInfoCard({
    super.key,
    required this.deal,
    required this.editable,
  });

  final Deal deal;
  final bool editable;

  Future<void> _edit(BuildContext context) async {
    final s = context.s;
    final controller = TextEditingController(text: deal.deliveryInfo);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deliveryInfo),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 8,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: s.deliveryInfoHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(s.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && context.mounted) {
      await context.read<DealsController>().setDeliveryInfo(deal.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return SectionCard(
      title: s.deliveryInfo,
      trailing: editable
          ? IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _edit(context),
            )
          : null,
      child: Text(
        deal.deliveryInfo.trim().isEmpty ? '—' : deal.deliveryInfo,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

/// Client of the deal and the users who may see it.
class DealAccessCard extends StatelessWidget {
  const DealAccessCard({super.key, required this.deal, required this.editable});

  final Deal deal;
  final bool editable;

  Future<void> _pickClient(BuildContext context) async {
    final s = context.s;
    final clients = context.read<ClientsController>().clients;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.link_off),
              title: Text(s.noClient),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final c in clients)
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: Text(c.name),
                selected: c.id == deal.clientId,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && context.mounted) {
      await context.read<DealsController>().setClient(
        deal.id,
        picked.isEmpty ? null : picked,
      );
    }
  }

  Future<void> _pickUsers(BuildContext context) async {
    final s = context.s;
    final users = [
      for (final u in context.read<AuthController>().users)
        if (u.role == UserRole.manager || u.role == UserRole.partner) u,
    ];
    final selected = {...deal.assignedUserIds};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(s.assignedTo),
          content: SizedBox(
            width: double.maxFinite,
            child: users.isEmpty
                ? Text(s.noUsers)
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final u in users)
                        CheckboxListTile(
                          value: selected.contains(u.id),
                          title: Text(u.name),
                          subtitle: Text(s.roleName(u.role)),
                          onChanged: (v) => setState(() {
                            v == true
                                ? selected.add(u.id)
                                : selected.remove(u.id);
                          }),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
    if (result != null && context.mounted) {
      await context.read<DealsController>().setAssignees(
        deal.id,
        result.toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final policy = context.watch<AuthController>().policy;
    final auth = context.watch<AuthController>();
    final client = context.watch<ClientsController>().byId(deal.clientId);
    final assigned = [
      for (final id in deal.assignedUserIds)
        if (auth.userById(id) != null) auth.userById(id)!.name,
    ];
    return SectionCard(
      title: s.assignedTo,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.business_outlined),
            title: Text(s.client),
            subtitle: Text(client?.name ?? s.noClient),
            trailing: editable && policy.canEditClients
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: editable && policy.canEditClients
                ? () => _pickClient(context)
                : null,
          ),
          if (policy.canManageUsers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.group_outlined),
              title: Text(s.users),
              subtitle: Text(
                assigned.isEmpty ? s.assignHint : assigned.join(', '),
              ),
              trailing: editable ? const Icon(Icons.chevron_right) : null,
              onTap: editable ? () => _pickUsers(context) : null,
            ),
        ],
      ),
    );
  }
}

/// Full stage history, including stage names recorded before v3.0.
class StageHistoryCard extends StatelessWidget {
  const StageHistoryCard({super.key, required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    return SectionCard(
      title: s.stageHistory,
      child: Column(
        children: [
          for (final e in deal.stageHistory.reversed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                StageBadge.iconFor(e.stage),
                size: 20,
                color: StageBadge.colorFor(context, e.stage),
              ),
              title: Text(
                e.legacyName != null
                    ? '${s.legacyStage(e.legacyName!)} → ${s.stage(e.stage)}'
                    : s.stage(e.stage),
              ),
              subtitle: Text(
                [
                  fmt.dateTime(e.at),
                  if (e.by.isNotEmpty) s.changedBy(e.by),
                  if (e.legacyName != null) s.oldStageName,
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// What a non-owner sees of the contracts: parties, goods, quantity,
/// the contract amount (except partners), dates. Built from the redacted
/// deal — internal amounts are not even present in it.
class ContractSummaryCard extends StatelessWidget {
  const ContractSummaryCard({
    super.key,
    required this.deal,
    required this.policy,
  });

  final Deal deal;
  final AccessPolicy policy;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final c = deal.buyerContract;
    String orDash(String v) => v.trim().isEmpty ? '—' : v;
    final factory = deal.sellerContract;
    final showFactory =
        factory.counterpartyName.trim().isNotEmpty &&
        (deal.isSingleContract || policy.role != UserRole.client);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: deal.isTwoParty
              ? s.twoPartyContract
              : deal.isThreeParty
              ? s.singleContract
              : s.contractTitle(ContractSide.buyer),
          child: Column(
            children: [
              AmountRow(label: s.contractNumber, value: orDash(c.number)),
              AmountRow(label: s.contractDate, value: fmt.date(c.date)),
              const Divider(height: 16),
              AmountRow(label: s.buyerShort, value: orDash(c.counterpartyName)),
              if (!deal.isTwoParty)
                AmountRow(
                  label: deal.isThreeParty ? s.payerTrader : s.intermediary,
                  value: orDash(c.intermediaryName),
                ),
              if (deal.isSingleContract)
                AmountRow(
                  label: s.sellerShort,
                  value: orDash(factory.counterpartyName),
                ),
              const Divider(height: 16),
              AmountRow(label: s.productName, value: orDash(c.productName)),
              AmountRow(
                label: s.quantity,
                value: '${fmt.number(c.quantity)} ${c.unit}'.trim(),
              ),
              if (policy.seesContractSums) ...[
                AmountRow(
                  label: s.unitPrice,
                  value: fmt.price(c.unitPrice, c.currency),
                ),
                AmountRow(
                  label: s.contractPriceForBuyer,
                  value: fmt.money(c.goodsCost, c.currency),
                  emphasize: true,
                ),
              ],
            ],
          ),
        ),
        if (showFactory && !deal.isSingleContract) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: s.contractTitle(ContractSide.seller),
            child: Column(
              children: [
                AmountRow(
                  label: s.contractNumber,
                  value: orDash(factory.number),
                ),
                AmountRow(label: s.contractDate, value: fmt.date(factory.date)),
                AmountRow(
                  label: s.counterpartyLabel(ContractSide.seller),
                  value: orDash(factory.counterpartyName),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(s.financeOwnerOnly, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Calculation frozen at signing and at closing, next to the current one
/// (owner only — the snapshots are not even present for other roles).
class SnapshotsCard extends StatelessWidget {
  const SnapshotsCard({super.key, required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final now = snapshotOf(deal, 'now');
    final columns = [
      for (final x in deal.snapshots)
        ('${s.snapshotEvent(x.event)}\n${fmt.date(x.at)}', x.values),
      (s.currentCalc, now.values),
    ];
    final rows = [
      (s.revenueFromBuyer, 'revenue'),
      (s.paymentToFactory, 'goods'),
      (s.logistics, 'logistics'),
      (s.agentFeeInternal, 'agency'),
      (s.agentVat, 'agentVat'),
      (s.netProfit, 'profit'),
    ];
    TextStyle? head = theme.textTheme.labelSmall;
    return SectionCard(
      title: s.calcSnapshots,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: one column per snapshot (signing, closing, now).
          Row(
            children: [
              const Spacer(flex: 3),
              for (final c in columns)
                Expanded(
                  flex: 2,
                  child: Text(c.$1, textAlign: TextAlign.right, style: head),
                ),
            ],
          ),
          const Divider(height: 12),
          for (final (label, key) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(label, style: theme.textTheme.bodySmall),
                  ),
                  for (final c in columns)
                    Expanded(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          fmt.money(c.$2[key] ?? 0),
                          style: key == 'profit'
                              ? theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                )
                              : theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            s.snapshotsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
