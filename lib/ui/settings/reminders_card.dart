import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../state/reminders_controller.dart';
import '../common/widgets.dart';

/// Reminder frequency (off / daily / every 3 days / weekly) and time for
/// the signed-in user.
class RemindersCard extends StatelessWidget {
  const RemindersCard({super.key});

  Future<void> _save(BuildContext context, ReminderSettings value) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<RemindersController>().update(
      value,
      title: 'NexusTrade',
      body: s.reminderBody,
    );
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(s.notificationsDenied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final current = context.watch<RemindersController>().current;
    return SectionCard(
      title: s.reminders,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in ReminderSettings.choices)
                ChoiceChip(
                  label: Text(s.reminderFrequency(d)),
                  selected: current.everyDays == d,
                  onSelected: (_) =>
                      _save(context, current.copyWith(everyDays: d)),
                ),
            ],
          ),
          if (current.enabled)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(s.reminderTime),
              trailing: Text(
                current.time.format(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: current.time,
                );
                if (t != null && context.mounted) {
                  await _save(context, current.copyWith(time: t));
                }
              },
            ),
        ],
      ),
    );
  }
}
