import 'package:b2b_contracts/data/models/deal_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DealDocument.fromLegacyAttachment', () {
    test('turns a 2.x attachment into a document with one version', () {
      final d = DealDocument.fromLegacyAttachment({
        'id': 'f1',
        'name': 'invoice.pdf',
        'size': 80000,
        'addedAt': '2026-10-01T09:00:00.000',
        'addedBy': 'u1',
      })!;
      expect(d.id, 'f1');
      expect(d.category, DocCategory.other);
      expect(d.title, 'invoice.pdf');
      expect(d.versions, hasLength(1));
      final v = d.versions.single;
      expect(v.fileId, 'f1');
      expect(v.fileName, 'invoice.pdf');
      expect(v.size, 80000);
      expect(v.uploadedAt, DateTime(2026, 10, 1, 9));
      expect(v.uploadedBy, 'u1');
      expect(d.createdAt, DateTime(2026, 10, 1, 9));
    });

    test('keeps the file even when the name and size are missing', () {
      final d = DealDocument.fromLegacyAttachment({'id': 'f2'})!;
      expect(d.title, 'f2');
      expect(d.versions.single.fileId, 'f2');
      expect(d.versions.single.size, 0);
    });

    test('skips a record without a file id', () {
      expect(DealDocument.fromLegacyAttachment({'name': 'x.pdf'}), isNull);
    });
  });
}
