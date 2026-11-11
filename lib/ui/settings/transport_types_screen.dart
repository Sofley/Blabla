import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/transport_type.dart';
import '../../state/transport_types_controller.dart';
import '../common/widgets.dart';

/// Directory of transport / loading types: edit, add your own, delete.
class TransportTypesScreen extends StatelessWidget {
  const TransportTypesScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const TransportTypesScreen()));

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final types = context.watch<TransportTypesController>();
    return Scaffold(
      appBar: AppBar(title: Text(s.transportTypes)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, types.createDraft(), isNew: true),
        icon: const Icon(Icons.add),
        label: Text(s.newTransportType),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final t in types.types)
            Card(
              child: ListTile(
                leading: Icon(
                  t.id.startsWith('cont')
                      ? Icons.inventory_2_outlined
                      : Icons.local_shipping_outlined,
                ),
                title: Text(t.name),
                subtitle: Text(
                  t.capacityTonnes == null
                      ? s.notSetValue
                      : '${fmt.number(t.capacityTonnes!)} t',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _edit(context, t),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    TransportType t, {
    bool isNew = false,
  }) async {
    final s = context.s;
    final controller = context.read<TransportTypesController>();
    final name = TextEditingController(text: t.name);
    final cap = TextEditingController(text: Fmt.editableOpt(t.capacityTonnes));
    double? capacity = t.capacityTonnes;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? s.newTransportType : s.transportType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: isNew,
              decoration: InputDecoration(labelText: s.userName),
            ),
            const SizedBox(height: 12),
            OptionalNumberField(
              controller: cap,
              label: s.capacityTonnes,
              suffix: 't',
              onChanged: (v) => capacity = v,
            ),
          ],
        ),
        actions: [
          if (!isNew)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: Text(s.delete),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(s.save),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    name.dispose();
    cap.dispose();
    if (result == 'delete') {
      await controller.delete(t.id);
    } else if (result == 'save' && n.isNotEmpty) {
      await controller.upsert(t.copyWith(name: n, capacityTonnes: capacity));
    }
  }
}
