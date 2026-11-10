import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/contract_stage.dart';
import '../../common/widgets.dart';

/// Vertical timeline of deal stages. Tapping a stage moves the deal to it.
class StatusTracker extends StatelessWidget {
  const StatusTracker({
    super.key,
    required this.stage,
    required this.stageDates,
    this.onStageSelected,
  });

  final ContractStage stage;
  final Map<ContractStage, DateTime> stageDates;
  final ValueChanged<ContractStage>? onStageSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final stages = ContractStage.values;

    return Column(
      children: [
        for (var i = 0; i < stages.length; i++)
          _StageRow(
            title: context.s.stage(stages[i]),
            subtitle:
                stageDates[stages[i]] != null && stages[i].index <= stage.index
                ? fmt.date(stageDates[stages[i]]!)
                : null,
            icon: StageBadge.iconFor(stages[i]),
            reached: stages[i].index <= stage.index,
            current: stages[i] == stage,
            isFirst: i == 0,
            isLast: i == stages.length - 1,
            lineReached: stages[i].index < stage.index,
            color: StageBadge.colorFor(context, stage),
            mutedColor: theme.colorScheme.outlineVariant,
            onTap: onStageSelected == null
                ? null
                : () => onStageSelected!(stages[i]),
          ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.reached,
    required this.current,
    required this.isFirst,
    required this.isLast,
    required this.lineReached,
    required this.color,
    required this.mutedColor,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool reached;
  final bool current;
  final bool isFirst;
  final bool isLast;
  final bool lineReached;
  final Color color;
  final Color mutedColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isFirst
                          ? Colors.transparent
                          : (reached ? color : mutedColor),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached ? color : Colors.transparent,
                      border: Border.all(
                        color: reached ? color : mutedColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      reached && !current ? Icons.check : icon,
                      size: 15,
                      color: reached
                          ? theme.colorScheme.surface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast
                          ? Colors.transparent
                          : (lineReached ? color : mutedColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                        color: reached
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact segmented progress bar for list items.
class StageProgressBar extends StatelessWidget {
  const StageProgressBar({super.key, required this.stage});

  final ContractStage stage;

  @override
  Widget build(BuildContext context) {
    final color = StageBadge.colorFor(context, stage);
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      children: [
        for (final s in ContractStage.values) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: s.index <= stage.index ? color : muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (s != ContractStage.values.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
