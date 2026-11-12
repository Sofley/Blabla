import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/deal.dart';
import '../../../export/export_service.dart';
import '../../../state/auth_controller.dart';
import '../../../state/clients_controller.dart';
import '../../../state/deals_controller.dart';
import '../../common/widgets.dart';

const _export = ExportService();

IconData docIcon(DocCategory c) => switch (c) {
  DocCategory.mainContract => Icons.gavel_outlined,
  DocCategory.invoice => Icons.receipt_long_outlined,
  DocCategory.appendix => Icons.list_alt_outlined,
  DocCategory.supplement => Icons.post_add_outlined,
  DocCategory.correction => Icons.published_with_changes_outlined,
  DocCategory.other => Icons.description_outlined,
};

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

Color _statusColor(BuildContext context, DocStatus s) => switch (s) {
  DocStatus.active => FinanceColors.of(context).positive,
  DocStatus.replaced => Theme.of(context).colorScheme.onSurfaceVariant,
  DocStatus.cancelled => Theme.of(context).colorScheme.error,
};

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final DocStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        context.s.docStatus(status),
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// File actions

Future<void> openDocFile(BuildContext context, Deal deal, DocVersion v) async {
  final s = context.s;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await context.read<DealsController>().readFile(
      deal.id,
      v.fileId,
    );
    if (bytes == null || !context.mounted) return;
    if (const {'jpg', 'jpeg', 'png'}.contains(v.format)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: Text(v.fileName)),
            body: InteractiveViewer(
              maxScale: 6,
              child: Center(child: Image.memory(bytes)),
            ),
          ),
        ),
      );
    } else if (!await _export.openWithSystem(bytes, v.fileName)) {
      messenger.showSnackBar(SnackBar(content: Text(s.noViewerApp)));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('${s.exportFailed}: $e')));
  }
}

Future<void> downloadDocFile(
  BuildContext context,
  Deal deal,
  DocVersion v,
) async {
  final s = context.s;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await context.read<DealsController>().readFile(
      deal.id,
      v.fileId,
    );
    if (bytes == null) return;
    if (await _export.save(
      bytes: bytes,
      fileName: v.fileName,
      mimeType: 'application/octet-stream',
    )) {
      messenger.showSnackBar(SnackBar(content: Text(s.fileSaved(v.fileName))));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('${s.exportFailed}: $e')));
  }
}

Future<(String, List<int>)?> _pick(BuildContext context) async {
  try {
    return await _export.pickDocument(extensions: DealDocument.formats);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${context.s.exportFailed}: $e')));
    }
    return null;
  }
}

/// Picks a file and asks for the document details, then adds it.
Future<void> addDocumentFlow(
  BuildContext context,
  Deal deal, {
  DocCategory category = DocCategory.other,
}) async {
  final picked = await _pick(context);
  if (picked == null || !context.mounted) return;
  final details = await showDocumentDetails(
    context,
    deal: deal,
    initial: DealDocument(
      id: '',
      category: category,
      title: picked.$1,
      createdAt: DateTime.now(),
    ),
  );
  if (details == null || !context.mounted) return;
  await context.read<DealsController>().addDocument(
    deal.id,
    category: details.category,
    fileName: picked.$1,
    bytes: picked.$2,
    title: details.title,
    number: details.number,
    date: details.date,
    visibleToClient: details.visibleToClient,
    relatedId: details.relatedId,
    replacesId: details.replacesId,
  );
}

/// New version of a document's file (the earlier one stays in history).
Future<void> replaceDocFile(
  BuildContext context,
  Deal deal,
  DealDocument doc,
) async {
  final picked = await _pick(context);
  if (picked == null || !context.mounted) return;
  await context.read<DealsController>().addVersion(
    deal.id,
    doc.id,
    fileName: picked.$1,
    bytes: picked.$2,
  );
}

// ---------------------------------------------------------------------------
// Official contract block (п. 16)

class OfficialContractCard extends StatelessWidget {
  const OfficialContractCard({
    super.key,
    required this.deal,
    required this.editable,
  });

  final Deal deal;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final client = context.watch<ClientsController>().byId(deal.clientId);
    final contracts = [
      for (final d in deal.documents)
        if (d.category == DocCategory.mainContract) d,
    ]..sort((a, b) => a.status.index.compareTo(b.status.index));
    final main = contracts.isEmpty ? null : contracts.first;
    final attached = main?.current != null;
    String orDash(String v) => v.trim().isEmpty ? '—' : v;

    return SectionCard(
      title: s.officialContract.toUpperCase(),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:
              (attached ? theme.colorScheme.primary : theme.colorScheme.error)
                  .withValues(alpha: .12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          attached ? s.contractAttached : s.contractNotAttached,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: attached
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AmountRow(
            label: s.officialContractNumber,
            value: orDash(main?.number ?? ''),
          ),
          AmountRow(
            label: s.officialContractDate,
            value: main?.date == null ? '—' : fmt.date(main!.date!),
          ),
          AmountRow(label: s.client, value: client?.name ?? s.noClient),
          AmountRow(label: s.dealNumberTitle, value: orDash(deal.dealNumber)),
          const Divider(height: 16),
          for (final c in contracts)
            _DocTile(deal: deal, doc: c, editable: editable),
          if (editable) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => addDocumentFlow(
                    context,
                    deal,
                    category: DocCategory.mainContract,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.addAction),
                ),
                if (main != null)
                  OutlinedButton.icon(
                    onPressed: () => replaceDocFile(context, deal, main),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(s.replaceAction),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dossier: every other document, grouped by category (п. 17)

class DossierCard extends StatelessWidget {
  const DossierCard({super.key, required this.deal, required this.editable});

  final Deal deal;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final groups = {
      for (final c in DocCategory.values)
        if (c != DocCategory.mainContract)
          c: [
            for (final d in deal.documents)
              if (d.category == c) d,
          ],
    };
    final empty = groups.values.every((g) => g.isEmpty);
    return SectionCard(
      title: s.documents,
      trailing: editable
          ? IconButton(
              tooltip: s.addDocument,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.attach_file, size: 20),
              onPressed: () =>
                  addDocumentFlow(context, deal, category: DocCategory.invoice),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (empty) Text(s.noDocuments, style: theme.textTheme.bodyMedium),
          for (final e in groups.entries)
            if (e.value.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Row(
                  children: [
                    Icon(
                      docIcon(e.key),
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.docCategory(e.key)} · ${e.value.length}',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
              for (final d in e.value)
                _DocTile(deal: deal, doc: d, editable: editable),
            ],
          const SizedBox(height: 6),
          Text(
            s.documentsEncryptedHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.deal,
    required this.doc,
    required this.editable,
  });

  final Deal deal;
  final DealDocument doc;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final v = doc.current;
    final meta = [
      if (doc.number.isNotEmpty) '№ ${doc.number}',
      if (doc.date != null) fmt.date(doc.date!),
      if (v != null) v.format.toUpperCase(),
      if (v != null) '${s.uploaded} ${fmt.date(v.uploadedAt)}',
      if (doc.versions.length > 1) s.versionsCount(doc.versions.length),
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(docIcon(doc.category)),
      title: Row(
        children: [
          Flexible(child: Text(doc.title, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          _StatusChip(doc.status),
          if (doc.visibleToClient && editable) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: s.visibleToClient,
              child: const Icon(Icons.visibility_outlined, size: 16),
            ),
          ],
        ],
      ),
      subtitle: Text(meta),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            DocumentSheet(dealId: deal.id, docId: doc.id, editable: editable),
      ),
    );
  }
}

/// Details of one document: actions, metadata and version history.
class DocumentSheet extends StatelessWidget {
  const DocumentSheet({
    super.key,
    required this.dealId,
    required this.docId,
    required this.editable,
  });

  final String dealId;
  final String docId;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final deal = context.watch<DealsController>().byId(dealId);
    DealDocument? doc;
    for (final d in deal?.documents ?? const <DealDocument>[]) {
      if (d.id == docId) doc = d;
    }
    if (deal == null || doc == null) return const SizedBox(height: 120);
    final d = doc;
    final v = d.current;
    DealDocument? byId(String? id) {
      for (final x in deal.documents) {
        if (x.id == id) return x;
      }
      return null;
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              Icon(docIcon(d.category), color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(d.title, style: theme.textTheme.titleLarge)),
              _StatusChip(d.status),
            ],
          ),
          const SizedBox(height: 12),
          AmountRow(
            label: s.docCategoryTitle,
            value: s.docCategory(d.category),
          ),
          AmountRow(
            label: s.docNumber,
            value: d.number.isEmpty ? '—' : d.number,
          ),
          AmountRow(
            label: s.docDate,
            value: d.date == null ? '—' : fmt.date(d.date!),
          ),
          if (v != null) ...[
            AmountRow(label: s.fileName, value: v.fileName),
            AmountRow(
              label: s.uploaded,
              value: '${fmt.dateTime(v.uploadedAt)} · ${_size(v.size)}',
            ),
          ],
          if (byId(d.relatedId) != null)
            AmountRow(
              label: s.relatedContract,
              value: byId(d.relatedId)!.title,
            ),
          if (byId(d.replacesId) != null)
            AmountRow(
              label: s.correctsDocument,
              value: byId(d.replacesId)!.title,
            ),
          if (editable)
            AmountRow(
              label: s.visibleToClient,
              value: d.visibleToClient ? s.yes : s.no,
            ),
          const SizedBox(height: 12),
          if (v != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => openDocFile(context, deal, v),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(s.viewAction),
                ),
                OutlinedButton.icon(
                  onPressed: () => downloadDocFile(context, deal, v),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(s.downloadAction),
                ),
                if (editable)
                  OutlinedButton.icon(
                    onPressed: () => replaceDocFile(context, deal, d),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(s.replaceAction),
                  ),
                if (editable)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final edited = await showDocumentDetails(
                        context,
                        deal: deal,
                        initial: d,
                      );
                      if (edited != null && context.mounted) {
                        await context.read<DealsController>().updateDocument(
                          deal.id,
                          edited,
                        );
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(s.edit),
                  ),
                if (editable)
                  TextButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final controller = context.read<DealsController>();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(s.deleteDocumentQuestion),
                          content: Text(
                            '${d.title}\n\n${s.deleteDocumentHint(d.versions.length)}',
                          ),
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
                        navigator.pop();
                        await controller.removeDocument(deal.id, d.id);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(s.delete),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Text(s.versionHistory, style: theme.textTheme.titleMedium),
          for (var i = d.versions.length - 1; i >= 0; i--)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
              title: Text(
                d.versions[i].fileName,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  fmt.dateTime(d.versions[i].uploadedAt),
                  _size(d.versions[i].size),
                  if (d.versions[i].uploadedBy.isNotEmpty)
                    d.versions[i].uploadedBy,
                  i == d.versions.length - 1
                      ? s.currentVersion
                      : i == 0
                      ? s.originalVersion
                      : s.previousVersion,
                ].join(' · '),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: () => downloadDocFile(context, deal, d.versions[i]),
              ),
              onTap: () => openDocFile(context, deal, d.versions[i]),
            ),
        ],
      ),
    );
  }
}

/// Form for the document details (category, title, number, date, status,
/// link to the main contract, document it corrects, client visibility).
Future<DealDocument?> showDocumentDetails(
  BuildContext context, {
  required Deal deal,
  required DealDocument initial,
}) => showModalBottomSheet<DealDocument>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _DocumentForm(deal: deal, initial: initial),
);

class _DocumentForm extends StatefulWidget {
  const _DocumentForm({required this.deal, required this.initial});

  final Deal deal;
  final DealDocument initial;

  @override
  State<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends State<_DocumentForm> {
  late DealDocument _d = widget.initial;
  late final _title = TextEditingController(text: _d.title);
  late final _number = TextEditingController(text: _d.number);

  @override
  void dispose() {
    _title.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final others = [
      for (final x in widget.deal.documents)
        if (x.id != _d.id) x,
    ];
    final contracts = [
      for (final x in others)
        if (x.category == DocCategory.mainContract) x,
    ];
    final isNew = widget.initial.id.isEmpty;
    final canShowToClient = context
        .read<AuthController>()
        .policy
        .canManageDocuments;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            isNew ? s.addDocument : s.edit,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DocCategory>(
            initialValue: _d.category,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.docCategoryTitle),
            items: [
              for (final c in DocCategory.values)
                DropdownMenuItem(value: c, child: Text(s.docCategory(c))),
            ],
            onChanged: (c) => setState(() => _d = _d.copyWith(category: c)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: s.docTitle),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            decoration: InputDecoration(labelText: s.docNumber),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _d.date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _d = _d.copyWith(date: picked));
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: s.docDate,
                suffixIcon: _d.date == null
                    ? const Icon(Icons.event_outlined)
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _d = _d.copyWith(date: null)),
                      ),
              ),
              child: Text(_d.date == null ? '—' : fmt.date(_d.date!)),
            ),
          ),
          if (!isNew) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<DocStatus>(
              initialValue: _d.status,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.docStatusTitle),
              items: [
                for (final st in DocStatus.values)
                  DropdownMenuItem(value: st, child: Text(s.docStatus(st))),
              ],
              onChanged: (st) => setState(() => _d = _d.copyWith(status: st)),
            ),
          ],
          if (_d.category != DocCategory.mainContract &&
              contracts.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: contracts.any((c) => c.id == _d.relatedId)
                  ? _d.relatedId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.relatedContract),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text('—')),
                for (final c in contracts)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(
                      [
                        c.title,
                        if (c.number.isNotEmpty) '№ ${c.number}',
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) =>
                  setState(() => _d = _d.copyWith(relatedId: id)),
            ),
          ],
          if (_d.category == DocCategory.correction && others.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: others.any((c) => c.id == _d.replacesId)
                  ? _d.replacesId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.correctsDocument),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text('—')),
                for (final c in others)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(
                      '${s.docCategory(c.category)}: ${c.title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) =>
                  setState(() => _d = _d.copyWith(replacesId: id)),
            ),
          ],
          if (canShowToClient)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(s.visibleToClient),
              subtitle: Text(s.visibleToClientHint),
              value: _d.visibleToClient,
              onChanged: (v) =>
                  setState(() => _d = _d.copyWith(visibleToClient: v)),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _d.copyWith(
                  title: _title.text.trim().isEmpty
                      ? widget.initial.title
                      : _title.text.trim(),
                  number: _number.text.trim(),
                ),
              ),
              child: Text(s.save),
            ),
          ),
        ],
      ),
    );
  }
}
