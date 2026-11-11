import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../state/deals_controller.dart';
import '../../state/widget_sync.dart';
import '../common/widgets.dart';

/// Home-screen widget: which deal it shows and whether amounts are hidden.
class WidgetCard extends StatelessWidget {
  const WidgetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final w = context.watch<WidgetSync>();
    final deal = w.selectedDealId == null
        ? null
        : context.watch<DealsController>().byId(w.selectedDealId!);
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return SectionCard(
      title: s.widgetSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.widgets_outlined),
            title: Text(deal?.displayTitle ?? s.widgetDealAuto),
            trailing: deal == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => w.select(null),
                  ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(s.widgetHideAmounts),
            subtitle: Text(s.widgetHideHint),
            value: w.hideAmounts,
            onChanged: w.setHideAmounts,
          ),
          Text(s.widgetHowToAdd, style: muted),
        ],
      ),
    );
  }
}
