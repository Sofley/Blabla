import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/security/aes_gcm.dart';

import 'package:path/path.dart' as p;

/// Storage of deal documents. Files are kept encrypted (AES-256-GCM) in the
/// app's private folder; the key lives in the platform keystore.
abstract class AttachmentStore {
  Future<void> write(String id, List<int> bytes);
  Future<Uint8List?> read(String id);
  Future<void> delete(String id);
  Future<void> deleteAll();
}

class FileAttachmentStore implements AttachmentStore {
  FileAttachmentStore._(this._dir, this._key);

  static const _keyName = 'nexustrade_files_key';

  final Directory _dir;
  final List<int> _key;

  static Future<FileAttachmentStore> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'attachments'));
    await dir.create(recursive: true);
    const storage = FlutterSecureStorage();
    var raw = await storage.read(key: _keyName);
    if (raw == null) {
      raw = base64Url.encode(AesGcmBox.randomBytes(32));
      await storage.write(key: _keyName, value: raw);
    }
    return FileAttachmentStore._(dir, base64Url.decode(raw));
  }

  File _file(String id) {
    // ids are UUIDs; never allow path separators.
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return File(p.join(_dir.path, '$safe.bin'));
  }

  @override
  Future<void> write(String id, List<int> bytes) async {
    final sealed = await AesGcmBox.seal(bytes, _key, aad: utf8.encode(id));
    await _file(id).writeAsBytes(sealed, flush: true);
  }

  @override
  Future<Uint8List?> read(String id) async {
    final f = _file(id);
    if (!await f.exists()) return null;
    return AesGcmBox.open(await f.readAsBytes(), _key, aad: utf8.encode(id));
  }

  @override
  Future<void> delete(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> deleteAll() async {
    if (await _dir.exists()) {
      await for (final e in _dir.list()) {
        await e.delete();
      }
    }
  }
}

/// In-memory store for tests.
class MemoryAttachmentStore implements AttachmentStore {
  final files = <String, Uint8List>{};

  @override
  Future<void> write(String id, List<int> bytes) async =>
      files[id] = Uint8List.fromList(bytes);

  @override
  Future<Uint8List?> read(String id) async => files[id];

  @override
  Future<void> delete(String id) async => files.remove(id);

  @override
  Future<void> deleteAll() async => files.clear();
}
