import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../export/export_service.dart';
import '../../export/report.dart';
import '../../export/report_builders.dart';

/// Bottom sheet: pick PDF / Excel / Word, then Share or Save.
/// [variants] (optional) offers several documents for the same object,
/// e.g. "for the buyer" (contract price only) and "internal" (full).
Future<void> showExportSheet(
  BuildContext context, {
  required Report Function(ReportBuilders b) build,
  List<(String, IconData, Report Function(ReportBuilders b))> variants =
      const [],
}) {
  final builders = ReportBuilders(context.s, Fmt.of(context));
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ExportSheet(
      reports: [
        if (variants.isEmpty) ('', Icons.description_outlined, build(builders)),
        for (final (label, icon, b) in variants) (label, icon, b(builders)),
      ],
    ),
  );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.reports});

  final List<(String, IconData, Report)> reports;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  int _variant = 0;
  Report get _report => widget.reports[_variant].$3;

  ExportFormat _format = ExportFormat.pdf;
  bool _busy = false;
  static const _service = ExportService();

  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _run({required bool share}) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await _service.render(_report, _format);
      final name = '${_report.fileBaseName}.${_format.extension}';
      if (share) {
        await _service.share(
          bytes: bytes,
          fileName: name,
          mimeType: _format.mimeType,
          subject: _report.title,
          origin: _origin(),
        );
        navigator.pop();
      } else {
        final saved = await _service.save(
          bytes: bytes,
          fileName: name,
          mimeType: _format.mimeType,
        );
        navigator.pop();
        if (saved) {
          messenger.showSnackBar(SnackBar(content: Text(s.fileSaved(name))));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('${s.exportFailed}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.exportTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _report.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.reports.length > 1) ...[
              const SizedBox(height: 12),
              for (var i = 0; i < widget.reports.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: i == _variant
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: i == _variant ? 2 : 1,
                      ),
                    ),
                    leading: Icon(widget.reports[i].$2),
                    title: Text(widget.reports[i].$1),
                    trailing: i == _variant
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => setState(() => _variant = i),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                for (final f in ExportFormat.values) ...[
                  Expanded(
                    child: _FormatTile(
                      format: f,
                      selected: _format == f,
                      onTap: () => setState(() => _format = f),
                    ),
                  ),
                  if (f != ExportFormat.values.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (_busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _run(share: false),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(s.saveToFile),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _run(share: true),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(s.shareAction),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final ExportFormat format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (format) {
      ExportFormat.pdf => const Color(0xFFC0392B),
      ExportFormat.xlsx => const Color(0xFF1E7F4F),
      ExportFormat.docx => const Color(0xFF2B5797),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? scheme.primary.withValues(alpha: .06) : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                format.extension.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              format.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
