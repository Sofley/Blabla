import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../report.dart';

/// Renders a [Report] to a minimal but valid Word (.docx) document.
class DocxRenderer {
  const DocxRenderer();

  Uint8List render(Report report) {
    final body = StringBuffer()
      ..write(_para(report.title, size: 32, bold: true))
      ..write(
        report.subtitle.isEmpty
            ? ''
            : _para(report.subtitle, size: 20, color: '5B6470'),
      );

    for (final block in report.blocks) {
      switch (block) {
        case ReportHeading(:final text):
          body.write(_para(text, size: 26, bold: true, spaceBefore: 240));
        case ReportParagraph(:final text):
          for (final line in text.split('\n')) {
            body.write(_para(line, size: 20));
          }
        case ReportKeyValues(:final rows):
          body.write(
            _table(
              null,
              [
                for (final (label, value) in rows)
                  [ReportCell(label, bold: value.bold), value],
              ],
              widths: const [5600, 3400],
            ),
          );
        case ReportTable(:final headers, :final rows):
          body.write(_table(headers, rows));
      }
    }

    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="567" w:footer="567" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';

    final archive = Archive()
      ..addFile(_file('[Content_Types].xml', _contentTypes))
      ..addFile(_file('_rels/.rels', _rels))
      ..addFile(_file('word/_rels/document.xml.rels', _docRels))
      ..addFile(_file('word/styles.xml', _styles))
      ..addFile(_file('word/document.xml', document));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static ArchiveFile _file(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _run(
    String text, {
    int size = 20,
    bool bold = false,
    String? color,
  }) =>
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>'
      '${bold ? '<w:b/>' : ''}${color != null ? '<w:color w:val="$color"/>' : ''}'
      '<w:sz w:val="$size"/></w:rPr>'
      '<w:t xml:space="preserve">${_esc(text)}</w:t></w:r>';

  static String _para(
    String text, {
    int size = 20,
    bool bold = false,
    String? color,
    int spaceBefore = 0,
    String align = 'left',
  }) =>
      '<w:p><w:pPr><w:spacing w:before="$spaceBefore" w:after="80"/>'
      '<w:jc w:val="$align"/></w:pPr>'
      '${_run(text, size: size, bold: bold, color: color)}</w:p>';

  static String _table(
    List<String>? headers,
    List<List<ReportCell>> rows, {
    List<int>? widths,
  }) {
    final cols = headers?.length ?? (rows.isEmpty ? 2 : rows.first.length);
    final w = widths ?? List.filled(cols, (9600 / cols).floor());
    final b = StringBuffer(
      '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
      '<w:tblBorders>'
      '<w:top w:val="single" w:sz="4" w:color="D0D4D9"/>'
      '<w:bottom w:val="single" w:sz="4" w:color="D0D4D9"/>'
      '<w:insideH w:val="single" w:sz="4" w:color="E3E6EA"/>'
      '<w:insideV w:val="single" w:sz="4" w:color="E3E6EA"/>'
      '</w:tblBorders>'
      '<w:tblCellMar><w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tblCellMar>'
      '</w:tblPr><w:tblGrid>',
    );
    for (final x in w) {
      b.write('<w:gridCol w:w="$x"/>');
    }
    b.write('</w:tblGrid>');

    String cell(
      String text,
      int width, {
      bool bold = false,
      bool head = false,
      bool right = false,
    }) =>
        '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
        '${head ? '<w:shd w:val="clear" w:color="auto" w:fill="E3E6EA"/>' : ''}'
        '</w:tcPr>'
        '${_para(text, size: 18, bold: bold || head, align: right ? 'right' : 'left')}</w:tc>';

    if (headers != null) {
      b.write('<w:tr>');
      for (var i = 0; i < headers.length; i++) {
        b.write(cell(headers[i], w[i], head: true));
      }
      b.write('</w:tr>');
    }
    for (final r in rows) {
      b.write('<w:tr>');
      for (var i = 0; i < r.length && i < w.length; i++) {
        b.write(
          cell(r[i].text, w[i], bold: r[i].bold, right: r[i].number != null),
        );
      }
      b.write('</w:tr>');
    }
    b.write('</w:tbl>');
    return b.toString();
  }

  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '</Types>';

  static const _rels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';

  static const _docRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:docDefaults><w:rPrDefault><w:rPr>'
      '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri" w:eastAsia="Calibri"/>'
      '<w:sz w:val="20"/><w:lang w:val="ru-RU"/></w:rPr></w:rPrDefault></w:docDefaults>'
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>'
      '</w:styles>';
}
