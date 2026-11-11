import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/contract_stage.dart';

/// Card with an uppercase caption and optional trailing action.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.accent,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (accent != null) ...[
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Label / value row used in breakdowns.
class AmountRow extends StatelessWidget {
  const AmountRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
    this.caption,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = emphasize
        ? theme.textTheme.titleSmall
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    final valueStyle =
        (emphasize ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: valueColor ?? theme.colorScheme.onSurface,
              fontFeatures: AppTheme.tabularFigures,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: valueStyle, textAlign: TextAlign.end),
        ],
      ),
    );
  }
}

/// KPI tile for the dashboard.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.footnote,
    this.icon,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? footnote;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: valueColor,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
            ),
            if (footnote != null) ...[
              const SizedBox(height: 4),
              Text(
                footnote!,
                style: theme.textTheme.bodySmall?.copyWith(
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

/// Decimal input that reports parsed values; accepts "," and ".".
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.suffix,
    this.helper,
    this.enabled = true,
    this.mustBePositive = false,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<double> onChanged;
  final String? suffix;
  final String? helper;
  final bool enabled;
  final bool mustBePositive;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
      ],
      style: const TextStyle(fontFeatures: AppTheme.tabularFigures),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        helperMaxLines: 2,
      ),
      validator: (v) {
        final parsed = Fmt.parse(v ?? '');
        if (parsed == null) return s.invalidNumber;
        if (mustBePositive && parsed <= 0) return s.invalidNumber;
        return null;
      },
      onChanged: (v) {
        final parsed = Fmt.parse(v);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}

/// Small colored pill showing the current stage.
class StageBadge extends StatelessWidget {
  const StageBadge({super.key, required this.stage});

  final ContractStage stage;

  static Color colorFor(BuildContext context, ContractStage stage) {
    final scheme = Theme.of(context).colorScheme;
    final finance = FinanceColors.of(context);
    return switch (stage) {
      ContractStage.signed => scheme.onSurfaceVariant,
      ContractStage.prepayment => finance.buyerAccent,
      ContractStage.factoryPaymentCny => finance.sellerAccent,
      ContractStage.inTransit => scheme.primary,
      ContractStage.closed => finance.positive,
    };
  }

  static IconData iconFor(ContractStage stage) => switch (stage) {
    ContractStage.signed => Icons.draw_outlined,
    ContractStage.prepayment => Icons.account_balance_wallet_outlined,
    ContractStage.factoryPaymentCny => Icons.factory_outlined,
    ContractStage.inTransit => Icons.local_shipping_outlined,
    ContractStage.closed => Icons.task_alt,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(context, stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(stage), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            context.s.stage(stage),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

/// Buyer ⇄ Intermediary ⇄ Seller structure of a back-to-back deal.
class PartiesStrip extends StatelessWidget {
  const PartiesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final f = FinanceColors.of(context);
    Widget node(IconData icon, String label, Color color) => Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: .15),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
          ),
        ],
      ),
    );
    Widget link(String label) => Column(
      children: [
        const Icon(Icons.swap_horiz, size: 20),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            node(Icons.storefront_outlined, s.buyerShort, f.buyerAccent),
            link('№1'),
            node(Icons.business_outlined, s.intermediaryShort, f.refund),
            link('№2'),
            node(Icons.factory_outlined, s.sellerShort, f.sellerAccent),
          ],
        ),
      ),
    );
  }
}
