import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../report.dart';

/// Renders a [Report] to an A4 PDF. Fonts must support Cyrillic, so the
/// bundled Roboto TTF files are passed in.
class PdfRenderer {
  const PdfRenderer({required this.regular, required this.bold});

  final ByteData regular;
  final ByteData bold;

  static const _ink = PdfColor.fromInt(0xFF15191E);
  static const _muted = PdfColor.fromInt(0xFF5B6470);
  static const _line = PdfColor.fromInt(0xFFE3E6EA);
  static const _accent = PdfColor.fromInt(0xFF1F4E5F);

  Future<Uint8List> render(Report report) async {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
    final doc = pw.Document(title: report.title, author: 'B2B Ledger');

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  report.title,
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'B2B Ledger',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Text(
              '${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _accent, width: 2),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  report.title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                if (report.subtitle.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(
                      report.subtitle,
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                  ),
              ],
            ),
          ),
          for (final block in report.blocks) _block(block),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _block(ReportBlock block) => switch (block) {
    ReportHeading(:final text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _accent,
        ),
      ),
    ),
    ReportParagraph(:final text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9.5)),
    ),
    ReportKeyValues(:final rows) => pw.Column(
      children: [
        for (final (label, value) in rows)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _line, width: .5)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      color: value.bold ? _ink : _muted,
                      fontWeight: value.bold ? pw.FontWeight.bold : null,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Flexible(
                  child: pw.Text(
                    value.text,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: value.bold ? pw.FontWeight.bold : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    ReportTable(:final headers, :final rows) => pw.TableHelper.fromTextArray(
      headers: headers,
      data: [
        for (final r in rows) [for (final c in r) c.text],
      ],
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _line),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignments: {
        if (rows.isNotEmpty)
          for (var i = 0; i < rows.first.length; i++)
            i: rows.first[i].number != null
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: .5),
        bottom: pw.BorderSide(color: _line, width: .5),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    ),
  };
}
