import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../report.dart';

/// Renders a [Report] to an .xlsx workbook (numbers stay numeric).
class XlsxRenderer {
  const XlsxRenderer();

  Uint8List render(Report report) {
    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet() ?? 'Sheet1';
    const name = 'Report';
    excel.rename(defaultName, name);
    final sheet = excel[name];

    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final headStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E3E6EA'),
    );
    final boldStyle = CellStyle(bold: true);
    final moneyStyle = CellStyle(numberFormat: NumFormat.standard_4);
    final moneyBoldStyle = CellStyle(
      bold: true,
      numberFormat: NumFormat.standard_4,
    );

    var row = 0;
    var maxCols = 2;

    void put(int col, CellValue value, [CellStyle? style]) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.value = value;
      if (style != null) cell.cellStyle = style;
    }

    void putCell(int col, ReportCell c) {
      if (c.number != null) {
        put(
          col,
          DoubleCellValue(c.number!),
          c.bold ? moneyBoldStyle : moneyStyle,
        );
      } else {
        put(col, TextCellValue(c.text), c.bold ? boldStyle : null);
      }
    }

    put(0, TextCellValue(report.title), titleStyle);
    row++;
    if (report.subtitle.isNotEmpty) {
      put(0, TextCellValue(report.subtitle));
      row++;
    }
    row++;

    for (final block in report.blocks) {
      switch (block) {
        case ReportHeading(:final text):
          row++;
          put(0, TextCellValue(text), boldStyle);
          row++;
        case ReportParagraph(:final text):
          put(0, TextCellValue(text));
          row++;
        case ReportKeyValues(:final rows):
          for (final (label, value) in rows) {
            put(0, TextCellValue(label), value.bold ? boldStyle : null);
            putCell(1, value);
            row++;
          }
        case ReportTable(:final headers, :final rows):
          if (headers.length > maxCols) maxCols = headers.length;
          for (var c = 0; c < headers.length; c++) {
            put(c, TextCellValue(headers[c]), headStyle);
          }
          row++;
          for (final r in rows) {
            for (var c = 0; c < r.length; c++) {
              putCell(c, r[c]);
            }
            row++;
          }
      }
    }

    sheet.setColumnWidth(0, 42);
    for (var c = 1; c < maxCols; c++) {
      sheet.setColumnWidth(c, 18);
    }
    return Uint8List.fromList(excel.encode()!);
  }
}
