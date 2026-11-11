import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/deal.dart';
import '../../state/auth_controller.dart';
import '../../state/deals_controller.dart';
import '../deals/deal_detail_screen.dart';
import '../deals/widgets/deal_sections.dart';

/// Deleted deals, kept for 15 days.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TrashScreen()));

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final deals = context.watch<DealsController>();
    final policy = context.watch<AuthController>().policy;
    final items = [...deals.trash]
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return Scaffold(
      appBar: AppBar(title: Text(s.trash)),
      body: items.isEmpty
          ? Center(child: Text(s.trashEmpty))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Text(s.trashHint, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final d in items)
                  Card(
                    child: ListTile(
                      title: Text(d.displayTitle),
                      subtitle: Text(
                        '${d.buyerContract.counterpartyName} · '
                        '${fmt.date(d.deletedAt!)} · '
                        '${s.daysLeft((d.purgeAt!.difference(DateTime.now()).inDays + 1).clamp(0, Deal.trashDays))}',
                      ),
                      onTap: () => DealDetailScreen.open(context, d.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.restoreDeal,
                            icon: const Icon(Icons.restore),
                            onPressed: () => deals.restore(d.id),
                          ),
                          if (policy.canPurge)
                            IconButton(
                              tooltip: s.deleteForever,
                              icon: const Icon(Icons.delete_forever),
                              onPressed: () =>
                                  confirmPurge(context, d.id, pop: false),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
