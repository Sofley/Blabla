import 'package:b2b_contracts/core/utils/file_names.dart';
import 'package:b2b_contracts/data/models/deal_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safeFileName', () {
    test('keeps an ordinary name', () {
      expect(
        safeFileName('Договор_DOG-2026-15.pdf'),
        'Договор_DOG-2026-15.pdf',
      );
      expect(safeFileName('合同 2026.docx'), '合同 2026.docx');
    });

    test('drops folders from a name taken from a backup', () {
      expect(safeFileName('../../shared_prefs/x.xml'), 'x.xml');
      expect(safeFileName('/data/data/app/files/a.pdf'), 'a.pdf');
      expect(safeFileName(r'C:\Users\a\invoice.pdf'), 'invoice.pdf');
      expect(safeFileName(r'..\..\evil.bin'), 'evil.bin');
    });

    test('a company name with a slash stays one file', () {
      expect(safeFileName('ООО A/B report.pdf'), 'B report.pdf');
    });

    test('replaces characters file systems reject', () {
      expect(safeFileName('a:b*c?.pdf'), 'a_b_c_.pdf');
      expect(safeFileName('tab\there.pdf'), 'tab_here.pdf');
    });

    test('never returns an empty name or a dot folder', () {
      expect(safeFileName(''), 'file');
      expect(safeFileName('   '), 'file');
      expect(safeFileName('..'), 'file');
      expect(safeFileName('a/..'), 'file');
      expect(safeFileName('dir/'), 'dir');
      expect(safeFileName('', fallback: 'restore.ntb'), 'restore.ntb');
    });
  });

  group('fileFormat', () {
    test('lower-case extension without the dot', () {
      expect(fileFormat('Invoice.PDF'), 'pdf');
      expect(fileFormat('archive.tar.gz'), 'gz');
      expect(fileFormat('photo'), '');
      expect(fileFormat('.hidden'), '');
      expect(fileFormat('folder.v2/readme'), '');
    });

    test('DocVersion.format uses it', () {
      final v = DocVersion(
        fileId: 'f',
        fileName: 'Contract.DOCX',
        size: 1,
        uploadedAt: DateTime(2026),
      );
      expect(v.format, 'docx');
    });
  });
}
