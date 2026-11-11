import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/settings_controller.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/deal.dart';
import '../../../domain/finance_calculator.dart';
import '../../common/widgets.dart';

/// Header of the single three-party contract / its internal calculation.
class ThreePartyHeader extends StatelessWidget {
  const ThreePartyHeader({super.key, required this.internal});

  /// True for the internal calculation tab (never shown to the buyer).
  final bool internal;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final color = internal
        ? FinanceColors.of(context).sellerAccent
        : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(
            internal ? Icons.lock_outline : Icons.hub_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  internal ? s.internalCalc : s.singleContract,
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
                Text(
                  internal ? s.internalCalcHint : s.singleContractHint,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Factory name and our company's legal role, inside the parties card of a
/// three-party contract.
class ThreePartyExtras extends StatefulWidget {
  const ThreePartyExtras({
    super.key,
    required this.deal,
    required this.onChanged,
  });

  final Deal deal;
  final ValueChanged<Deal> onChanged;

  @override
  State<ThreePartyExtras> createState() => _ThreePartyExtrasState();
}

class _ThreePartyExtrasState extends State<ThreePartyExtras> {
  late final _factory = TextEditingController(
    text: widget.deal.sellerContract.counterpartyName,
  );

  @override
  void dispose() {
    _factory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final d = widget.deal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _factory,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: s.counterpartyLabel(d.sellerContract.side),
            prefixIcon: const Icon(Icons.factory_outlined, size: 18),
          ),
          onChanged: (v) => widget.onChanged(
            d.copyWith(
              sellerContract: d.sellerContract.copyWith(
                counterpartyName: v.trim(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(s.companyStatus, style: theme.textTheme.titleSmall),
            ),
            IconButton(
              tooltip: s.companyStatusInfo,
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => showRoleInfo(context, d.role),
            ),
          ],
        ),
        for (final r in CompanyRole.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _RoleTile(
              role: r,
              selected: d.role == r,
              onTap: () => widget.onChanged(d.copyWith(role: r)),
            ),
          ),
      ],
    );
  }
}

IconData roleIcon(CompanyRole r) => switch (r) {
  CompanyRole.buyerImporter => Icons.inventory_outlined,
  CompanyRole.payer => Icons.payments_outlined,
  CompanyRole.principalAgent => Icons.handshake_outlined,
};

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final CompanyRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Tooltip(
      message: s.roleShortHint(role),
      triggerMode: TooltipTriggerMode.longPress,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected ? color.withValues(alpha: .06) : null,
          ),
          child: Row(
            children: [
              Icon(roleIcon(role), color: selected ? color : null, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.roleTitle(role),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      s.roleShortHint(role),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.help_outline, size: 18),
                onPressed: () => showRoleInfo(context, role),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Info sheet explaining the three legal roles (reference only).
Future<void> showRoleInfo(BuildContext context, CompanyRole focus) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final s = ctx.s;
      final theme = Theme.of(ctx);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(s.companyStatus, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final r in CompanyRole.values) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: r == focus
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: r == focus ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(roleIcon(r), color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.roleTitle(r),
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(s.roleDetails(r), style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              s.legalDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// How the buyer's contract price is set: by hand, or from our margin
/// (% of the factory amount or a fixed sum). The margin is internal: the
/// buyer only sees the final contract price.
class PricingControl extends StatefulWidget {
  const PricingControl({
    super.key,
    required this.deal,
    required this.onChanged,
  });

  final Deal deal;
  final ValueChanged<Deal> onChanged;

  @override
  State<PricingControl> createState() => _PricingControlState();
}

class _PricingControlState extends State<PricingControl> {
  late final _margin = TextEditingController(
    text: Fmt.editable(widget.deal.marginValue),
  );

  @override
  void dispose() {
    _margin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final d = widget.deal;
    final f = ContractFinancials.of(d.sellerContract);
    final p = DealProfit.of(d);

    return SectionCard(
      title: s.contractPriceTitle,
      accent: theme.colorScheme.primary,
      trailing: Icon(
        Icons.visibility_off_outlined,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<PricingMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: PricingMode.manual,
                label: Text(s.pricingManual),
              ),
              ButtonSegment(
                value: PricingMode.marginPercent,
                label: Text(s.pricingMarginPercent),
              ),
              ButtonSegment(
                value: PricingMode.marginAmount,
                label: Text(s.pricingMarginAmount),
              ),
              ButtonSegment(
                value: PricingMode.profitPerUnit,
                label: Text(s.pricingProfitPerUnit),
              ),
            ],
            selected: {d.pricingMode},
            onSelectionChanged: (v) {
              final mode = v.first;
              // Switching to "profit per unit" starts from the default
              // profit (0.33); other modes keep the entered value.
              var value = d.marginValue;
              if (mode == PricingMode.profitPerUnit &&
                  d.pricingMode != PricingMode.profitPerUnit) {
                value = context.read<SettingsController>().defaultProfitPerUnit;
                _margin.text = Fmt.editable(value);
              }
              widget.onChanged(
                d.copyWith(pricingMode: mode, marginValue: value),
              );
            },
          ),
          if (d.pricingMode != PricingMode.manual) ...[
            const SizedBox(height: 10),
            NumberField(
              controller: _margin,
              label: switch (d.pricingMode) {
                PricingMode.marginPercent => s.marginPercentOfFactory,
                PricingMode.profitPerUnit => s.profitPerUnitMode,
                _ => s.marginSumUsd,
              },
              helper: d.pricingMode == PricingMode.profitPerUnit
                  ? s.profitPerUnitHint
                  : null,
              suffix: switch (d.pricingMode) {
                PricingMode.marginPercent => '%',
                PricingMode.profitPerUnit =>
                  d.buyerContract.unit.trim().isEmpty
                      ? 'USD'
                      : 'USD/${d.buyerContract.unit.trim()}',
                _ => 'USD',
              },
              onChanged: (v) => widget.onChanged(d.copyWith(marginValue: v)),
            ),
            const SizedBox(height: 8),
            AmountRow(
              label: s.paymentToFactoryTotal,
              value: fmt.money(f.totalUsd),
              caption: s.paymentToFactoryHint,
            ),
            AmountRow(
              label: s.contractPriceForBuyer,
              value: fmt.money(p.turnoverUsd),
              emphasize: true,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            s.marginHiddenHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
