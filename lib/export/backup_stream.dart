import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/security/aes_gcm.dart';
import 'backup_service.dart';

/// Streaming encrypted backup (format "nexustrade-backup", version 5).
///
/// ```text
/// {"format":"nexustrade-backup","version":5,"kdf":{…,"salt":…},
///  "cipher":"AES-256-GCM","chunked":true,"createdAt":"…"}\n
/// [u32 length][nonce | ciphertext | tag]   record 0: data (JSON)
/// [u32 length][…]                           record 1…: file start / chunk / end
/// [u32 length][…]                           last record: end of backup
/// ```
/// Every record is encrypted on its own with AAD = header line + record
/// number, so records can be neither changed, reordered nor cut off.
/// Documents are written and read in 1 MB pieces: the whole backup is never
/// held in memory, however many documents there are.
class BackupStream {
  BackupStream._();

  static const version = 5;
  static const chunkSize = 1 << 20;

  static const _data = 0, _fileStart = 1, _chunk = 2, _fileEnd = 3, _end = 9;

  static Uint8List _aad(String header, int index) {
    final h = utf8.encode(header);
    final out = Uint8List(h.length + 4)..setAll(0, h);
    ByteData.sublistView(out).setUint32(h.length, index);
    return out;
  }

  /// Writes [data] (deals, settings… without file bytes) and every file of
  /// [fileIds] to [out].
  static Future<void> write({
    required File out,
    required BackupKey key,
    required Map<String, dynamic> data,
    required List<String> fileIds,
    required Future<Uint8List?> Function(String id) readFile,
  }) async {
    final header = jsonEncode({
      'format': BackupService.format,
      'version': version,
      'kdf': {...key.params.toJson(), 'salt': base64Url.encode(key.salt)},
      'cipher': 'AES-256-GCM',
      'chunked': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final sink = out.openWrite();
    var index = 0;
    Future<void> record(int type, List<int> payload) async {
      final plain = Uint8List(payload.length + 1)
        ..[0] = type
        ..setAll(1, payload);
      final sealed = await AesGcmBox.seal(
        plain,
        key.key,
        aad: _aad(header, index++),
      );
      final len = ByteData(4)..setUint32(0, sealed.length);
      sink
        ..add(len.buffer.asUint8List())
        ..add(sealed);
    }

    try {
      sink.add(utf8.encode('$header\n'));
      await record(_data, utf8.encode(jsonEncode({...data, 'files': fileIds})));
      for (final id in fileIds) {
        final bytes = await readFile(id);
        if (bytes == null) continue;
        await record(_fileStart, utf8.encode(id));
        for (var o = 0; o < bytes.length; o += chunkSize) {
          final end = o + chunkSize < bytes.length
              ? o + chunkSize
              : bytes.length;
          await record(_chunk, Uint8List.sublistView(bytes, o, end));
        }
        await record(_fileEnd, const []);
        await sink.flush();
      }
      await record(_end, const []);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// Header of a v5 file, or null when [file] is another format.
  static Future<Map<String, dynamic>?> readHeader(File file) async {
    final raf = await file.open();
    try {
      final head = await raf.read(64 * 1024);
      final nl = head.indexOf(10);
      if (nl <= 0) return null;
      final j = jsonDecode(utf8.decode(head.sublist(0, nl)));
      if (j is Map<String, dynamic> &&
          j['format'] == BackupService.format &&
          j['chunked'] == true) {
        return j;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      await raf.close();
    }
  }

  /// Decrypts [file]. Returns the data JSON; every file is passed to
  /// [onFile] as soon as it is complete (when given). Throws
  /// SecretBoxAuthenticationError for a wrong password or a changed file
  /// and FormatException for a damaged / cut-off file.
  static Future<Map<String, dynamic>> read(
    File file,
    BackupKey Function(KdfParams params, Uint8List salt)? knownKey,
    Future<BackupKey> Function(KdfParams params, Uint8List salt) derive, {
    Future<void> Function(String id, Uint8List bytes)? onFile,
    bool dataOnly = false,
  }) async {
    final raf = await file.open();
    try {
      // Header line.
      final head = await raf.read(64 * 1024);
      final nl = head.indexOf(10);
      if (nl <= 0) throw const FormatException('Not a NexusTrade backup');
      final headerLine = utf8.decode(head.sublist(0, nl));
      final header = jsonDecode(headerLine) as Map;
      final kdf = header['kdf'] as Map;
      final params = KdfParams.fromJson(kdf);
      final salt = base64Url.decode(kdf['salt'] as String);
      final key = knownKey?.call(params, salt) ?? await derive(params, salt);
      await raf.setPosition(nl + 1);

      var index = 0;
      Future<(int, Uint8List)?> next() async {
        final lenBytes = await raf.read(4);
        if (lenBytes.isEmpty) return null;
        if (lenBytes.length < 4) throw const FormatException('Cut off');
        final len = ByteData.sublistView(lenBytes).getUint32(0);
        final sealed = await raf.read(len);
        if (sealed.length < len) throw const FormatException('Cut off');
        final plain = await AesGcmBox.open(
          sealed,
          key.key,
          aad: _aad(headerLine, index++),
        );
        return (plain[0], Uint8List.sublistView(plain, 1));
      }

      final first = await next();
      if (first == null || first.$1 != _data) {
        throw const FormatException('No data record');
      }
      final data = jsonDecode(utf8.decode(first.$2)) as Map<String, dynamic>;
      if (dataOnly) return data;

      String? currentId;
      final buffer = BytesBuilder(copy: false);
      var ended = false;
      while (true) {
        final r = await next();
        if (r == null) break;
        switch (r.$1) {
          case _fileStart:
            currentId = utf8.decode(r.$2);
            buffer.clear();
          case _chunk:
            if (currentId == null) throw const FormatException('Chunk');
            buffer.add(r.$2);
          case _fileEnd:
            if (currentId == null) throw const FormatException('File end');
            final bytes = buffer.takeBytes();
            if (onFile != null) await onFile(currentId, bytes);
            currentId = null;
          case _end:
            ended = true;
        }
        if (ended) break;
      }
      // A file without the end record was cut off (e.g. an interrupted
      // upload): refuse it instead of restoring half of the documents.
      if (!ended) throw const FormatException('Cut off');
      return data;
    } finally {
      await raf.close();
    }
  }
}
