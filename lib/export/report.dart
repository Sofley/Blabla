/// Format-neutral report: built once, rendered to PDF, Excel or Word.
class Report {
  const Report({
    required this.title,
    required this.fileBaseName,
    this.subtitle = '',
    required this.blocks,
  });

  final String title;
  final String subtitle;

  /// File name without extension (only safe characters).
  final String fileBaseName;
  final List<ReportBlock> blocks;
}

/// A cell keeps the human text and, for numbers, the raw value
/// (so Excel gets real numbers that can be summed).
class ReportCell {
  const ReportCell(this.text, {this.number, this.bold = false});

  final String text;
  final double? number;
  final bool bold;
}

sealed class ReportBlock {
  const ReportBlock();
}

class ReportHeading extends ReportBlock {
  const ReportHeading(this.text);
  final String text;
}

class ReportParagraph extends ReportBlock {
  const ReportParagraph(this.text);
  final String text;
}

/// Two-column "label — value" list.
class ReportKeyValues extends ReportBlock {
  const ReportKeyValues(this.rows);
  final List<(String, ReportCell)> rows;
}

class ReportTable extends ReportBlock {
  const ReportTable({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<ReportCell>> rows;
}

enum ExportFormat {
  pdf('pdf', 'application/pdf', 'PDF'),
  xlsx(
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'Excel',
  ),
  docx(
    'docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'Word',
  );

  const ExportFormat(this.extension, this.mimeType, this.label);

  final String extension;
  final String mimeType;
  final String label;
}
