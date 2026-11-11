import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/client.dart';
import '../../domain/analytics_service.dart';
import '../../domain/finance_calculator.dart';
import '../../state/auth_controller.dart';
import '../../state/clients_controller.dart';
import '../../state/deals_controller.dart';
import '../common/widgets.dart';
import '../deals/deals_list_screen.dart';

/// Clients directory: company, contacts, deals and totals.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ClientsScreen()));

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final policy = context.watch<AuthController>().policy;
    final deals = context.watch<DealsController>().deals;
    final q = _query.trim().toLowerCase();
    final clients = [
      for (final c in context.watch<ClientsController>().clients)
        if (q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.contactPerson.toLowerCase().contains(q))
          c,
    ];
    final counts = <String?, int>{};
    for (final d in deals) {
      counts[d.clientId] = (counts[d.clientId] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: Text(s.clients)),
      floatingActionButton: policy.canEditClients
          ? FloatingActionButton.extended(
              onPressed: () => showClientEditor(context),
              icon: const Icon(Icons.add_business_outlined),
              label: Text(s.newClient),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: s.search,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          if (clients.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(s.noClients)),
            ),
          for (final c in clients)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase()),
                ),
                title: Text(c.name),
                subtitle: Text(
                  [
                    if (c.contactPerson.isNotEmpty) c.contactPerson,
                    '${s.dealsCount}: ${counts[c.id] ?? 0}',
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClientDetailScreen(clientId: c.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final colors = FinanceColors.of(context);
    final policy = context.watch<AuthController>().policy;
    final client = context.watch<ClientsController>().byId(clientId);
    if (client == null) return Scaffold(appBar: AppBar());
    final deals = [
      for (final d in context.watch<DealsController>().deals)
        if (d.clientId == clientId) d,
    ];
    final totals = const AnalyticsService().byClient(deals);
    final total = totals.isEmpty ? null : totals.first;
    String orDash(String v) => v.trim().isEmpty ? '—' : v;
    return Scaffold(
      appBar: AppBar(
        title: Text(client.name),
        actions: [
          if (policy.canEditClients)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showClientEditor(context, client: client),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SectionCard(
            title: s.client,
            child: Column(
              children: [
                AmountRow(label: s.companyNameField, value: client.name),
                AmountRow(
                  label: s.contactPerson,
                  value: orDash(client.contactPerson),
                ),
                AmountRow(label: s.phoneField, value: orDash(client.phone)),
                AmountRow(label: s.emailField, value: orDash(client.email)),
                AmountRow(label: s.address, value: orDash(client.address)),
                if (client.notes.trim().isNotEmpty)
                  AmountRow(label: s.notesSection, value: client.notes),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: s.clientDeals,
            child: Column(
              children: [
                AmountRow(label: s.dealsCount, value: '${deals.length}'),
                if (policy.seesContractSums && total != null)
                  AmountRow(
                    label: s.dealsSum,
                    value: fmt.money(total.turnoverUsd),
                  ),
                // Profit is internal finance: owner only.
                if (policy.seesFinance && total != null)
                  AmountRow(
                    label: s.netProfit,
                    value: fmt.money(total.netProfitUsd),
                    valueColor: colors.signed(total.netProfitUsd),
                    emphasize: true,
                  ),
              ],
            ),
          ),
          if (policy.seesFinance && deals.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: s.monthlyReport,
              child: Column(
                children: [
                  for (final m in _months(deals))
                    AmountRow(
                      label: fmt.month(m),
                      value: fmt.money(
                        const AnalyticsService()
                            .dealsInMonth(deals, m)
                            .fold(
                              0.0,
                              (a, d) => a + DealProfit.of(d).netProfitUsd,
                            ),
                      ),
                      caption:
                          '${s.dealsCount}: ${const AnalyticsService().dealsInMonth(deals, m).length}',
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final d in deals) ...[
            DealCard(deal: d),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  static List<DateTime> _months(List deals) {
    final set = <DateTime>{
      for (final d in deals) AnalyticsService.monthOf(d.reportingDate),
    };
    return set.toList()..sort((a, b) => b.compareTo(a));
  }
}

Future<void> showClientEditor(BuildContext context, {Client? client}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ClientEditor(client: client),
    );

class _ClientEditor extends StatefulWidget {
  const _ClientEditor({this.client});

  final Client? client;

  @override
  State<_ClientEditor> createState() => _ClientEditorState();
}

class _ClientEditorState extends State<_ClientEditor> {
  final _form = GlobalKey<FormState>();
  late final Client _c =
      widget.client ?? context.read<ClientsController>().createDraft();
  late final _name = TextEditingController(text: _c.name);
  late final _person = TextEditingController(text: _c.contactPerson);
  late final _phone = TextEditingController(text: _c.phone);
  late final _email = TextEditingController(text: _c.email);
  late final _address = TextEditingController(text: _c.address);
  late final _notes = TextEditingController(text: _c.notes);

  @override
  void dispose() {
    for (final c in [_name, _person, _phone, _email, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    await context.read<ClientsController>().upsert(
      _c.copyWith(
        name: _name.text.trim(),
        contactPerson: _person.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
    navigator.pop();
  }

  Future<void> _delete() async {
    final s = context.s;
    final clients = context.read<ClientsController>();
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteClientQuestion),
        content: Text(s.deleteClientHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await clients.delete(_c.id);
      navigator.pop();
      if (navigator.canPop()) navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    Widget field(
      TextEditingController c,
      String label, {
      TextInputType? type,
      int lines = 1,
      bool required = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v ?? '').trim().isEmpty ? s.nameRequired : null
            : null,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.client == null ? s.newClient : s.editClient,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            field(_name, s.companyNameField, required: true),
            field(_person, s.contactPerson),
            field(_phone, s.phoneField, type: TextInputType.phone),
            field(_email, s.emailField, type: TextInputType.emailAddress),
            field(_address, s.address),
            field(_notes, s.notesSection, lines: 3),
            Row(
              children: [
                if (widget.client != null)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(s.delete),
                  ),
                const Spacer(),
                FilledButton(onPressed: _save, child: Text(s.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
