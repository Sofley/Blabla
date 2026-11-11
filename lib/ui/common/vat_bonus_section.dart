import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'widgets.dart';

/// VAT refund (China) and the user's "VAT bonus":
///   refund = base × refund %;  bonus = refund × my share %;
///   the bonus is added to net profit only when [inProfit] is on.
/// Placed at the very bottom of the calculations.
class VatBonusSection extends StatelessWidget {
  const VatBonusSection({
    super.key,
    required this.enabled,
    required this.refundController,
    required this.share,
    required this.inProfit,
    required this.refundText,
    required this.bonusText,
    required this.baseHint,
    required this.onEnabled,
    required this.onRefundPercent,
    required this.onShare,
    required this.onInProfit,
    this.baseSelector,
    this.readOnly = false,
  });

  final bool enabled;
  final TextEditingController refundController;

  /// 0–100.
  final double share;
  final bool inProfit;

  /// Formatted refund and bonus amounts.
  final String refundText;
  final String bonusText;

  /// E.g. "of the factory amount (FOB)".
  final String baseHint;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<double> onRefundPercent;
  final ValueChanged<double> onShare;
  final ValueChanged<bool> onInProfit;
  final Widget? baseSelector;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final color = FinanceColors.of(context).refund;

    return SectionCard(
      title: s.vatBonusTitle,
      accent: color,
      child: IgnorePointer(
        ignoring: readOnly,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(s.vatRefundCalc),
              subtitle: Text(s.vatRefundCalcHint),
              value: enabled,
              onChanged: onEnabled,
            ),
            if (enabled) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: NumberField(
                      controller: refundController,
                      label: s.vatRefundRate,
                      suffix: '%',
                      helper: baseHint,
                      onChanged: onRefundPercent,
                    ),
                  ),
                  if (baseSelector != null) ...[
                    const SizedBox(width: 10),
                    Expanded(child: baseSelector!),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              AmountRow(label: s.vatRefundAmount, value: refundText),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.myVatShare,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${share.round()}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontFeatures: AppTheme.tabularFigures,
                    ),
                  ),
                ],
              ),
              Slider(
                value: share.clamp(0, 100),
                min: 0,
                max: 100,
                divisions: 20,
                label: '${share.round()}%',
                activeColor: color,
                onChanged: onShare,
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final v in const [0, 40, 50, 100])
                    ChoiceChip(
                      label: Text('$v%'),
                      selected: share.round() == v,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => onShare(v.toDouble()),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              AmountRow(
                label: s.vatBonus,
                value: bonusText,
                valueColor: color,
                emphasize: true,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(s.addVatBonusToProfit),
                subtitle: Text(
                  inProfit ? s.vatBonusInProfitHint : s.vatBonusReferenceHint,
                ),
                value: inProfit,
                onChanged: onInProfit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
