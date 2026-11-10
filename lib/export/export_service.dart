import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'renderers/docx_renderer.dart';
import 'renderers/pdf_renderer.dart';
import 'renderers/xlsx_renderer.dart';
import 'report.dart';

/// Renders reports and hands files to the OS: share sheet or "Save as".
class ExportService {
  const ExportService();

  Future<Uint8List> render(Report report, ExportFormat format) async {
    switch (format) {
      case ExportFormat.pdf:
        final renderer = PdfRenderer(
          regular: await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
          bold: await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
        );
        return renderer.render(report);
      case ExportFormat.xlsx:
        return const XlsxRenderer().render(report);
      case ExportFormat.docx:
        return const DocxRenderer().render(report);
    }
  }

  /// Opens the system share sheet (mail, messengers, Drive…).
  Future<void> share({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    Rect? origin,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: subject,
        title: subject,
        // Required on iPad, where the share sheet is a popover.
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Shows the system "Save as" dialog. Returns false if cancelled.
  Future<bool> save({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    return uri != null;
  }

  /// Lets the user pick a backup file and returns its decoded JSON.
  Future<Map<String, dynamic>?> pickJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final bytes = await file.xFile.readAsBytes();
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
