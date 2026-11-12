// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/client.dart';
import '../data/models/deal.dart';
import '../export/backup_service.dart';
import '../export/backup_stream.dart';
import 'auth_controller.dart';
import 'chat_controller.dart';
import 'clients_controller.dart';
import 'deals_controller.dart';
import 'quotes_controller.dart';
import 'rates_controller.dart';
import 'routes_controller.dart';
import 'settings_controller.dart';
import 'transport_types_controller.dart';

/// Where the derived backup key is kept (platform keystore in the app,
/// memory in tests).
abstract class BackupKeyVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureBackupKeyVault implements BackupKeyVault {
  const SecureBackupKeyVault();
  static const _name = 'nexustrade_backup_key';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _name);
  @override
  Future<void> write(String value) => _storage.write(key: _name, value: value);
  @override
  Future<void> delete() => _storage.delete(key: _name);
}

class MemoryBackupKeyVault implements BackupKeyVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async => value = v;
  @override
  Future<void> delete() async => value = null;
}

/// Encrypted backups (owner only):
/// * the key is derived from the account password with Argon2id whenever
///   the owner types the password; the password itself is never stored;
/// * a weekly backup is created automatically on this phone and the owner
///   is offered to save it to Google Drive with one tap (variant B);
/// * manual backup and restore, also of plain v2.x backups.
class BackupController extends ChangeNotifier {
  BackupController({
    required Box settingsBox,
    required this.auth,
    required this.deals,
    required this.quotes,
    required this.settings,
    required this.rates,
    required this.routes,
    required this.chat,
    required this.clients,
    this.transportTypes,
    BackupKeyVault vault = const SecureBackupKeyVault(),
    Future<Directory> Function()? directory,
    this.kdf = const KdfParams(),
  }) : _box = settingsBox,
       _vault = vault,
       _directory = directory ?? _defaultDirectory;

  final Box _box;
  final AuthController auth;
  final DealsController deals;
  final QuotesController quotes;
  final SettingsController settings;
  final RatesController rates;
  final RoutesController routes;
  final ChatController chat;
  final ClientsController clients;
  final TransportTypesController? transportTypes;
  final BackupKeyVault _vault;
  final Future<Directory> Function() _directory;
  final KdfParams kdf;

  static const service = BackupService();
  static const weeklyInterval = Duration(days: 7);
  static const keepFiles = 5;

  static Future<Directory> _defaultDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/backups');
    await dir.create(recursive: true);
    return dir;
  }

  BackupKey? _key;
  bool _keyLoaded = false;

  Future<BackupKey?> _loadKey() async {
    if (!_keyLoaded) {
      _key = BackupKey.deserialize(await _vault.read());
      _keyLoaded = true;
    }
    return _key;
  }

  /// Whether encrypted backups can be made without asking the password.
  Future<bool> get hasKey async => await _loadKey() != null;

  /// Derives and stores the key. [force] after registration or a password
  /// change; otherwise only when no key exists yet.
  Future<void> rememberPassword(String password, {bool force = false}) async {
    if (!force && await _loadKey() != null) return;
    final key = await BackupKey.derive(password, params: kdf);
    await _vault.write(key.serialize());
    _key = key;
    _keyLoaded = true;
    notifyListeners();
  }

  Future<void> forgetKey() async {
    await _vault.delete();
    _key = null;
    _keyLoaded = true;
    notifyListeners();
  }

  // ---------- Status ----------

  DateTime? _date(String k) => DateTime.tryParse(_box.get(k) as String? ?? '');

  /// Last backup created (manual or weekly).
  DateTime? get lastBackupAt => _date('backupLastAt');

  /// Last time a backup was saved or shared outside the phone.
  DateTime? get lastExportedAt => _date('backupLastExportedAt');

  Future<void> markExported() async {
    await _box.put('backupLastExportedAt', DateTime.now().toIso8601String());
    notifyListeners();
  }

  // ---------- Create ----------

  BackupContent _collect() => BackupContent(
    deals: deals.rawForBackup(),
    quotes: quotes.quotes,
    settings: {
      ...settings.toBackup(),
      ...rates.toBackup(),
      if (transportTypes != null) 'transportTypes': transportTypes!.toBackup(),
    },
    routes: routes.routes,
    chat: chat.all,
    clients: clients.rawForBackup(),
    users: auth.users,
    hasRoutes: true,
  );

  static String fileName(DateTime d, {String suffix = ''}) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'nexustrade_backup_${d.year}-${two(d.month)}-${two(d.day)}'
        '_${two(d.hour)}${two(d.minute)}$suffix.ntb';
  }

  /// Creates an encrypted backup file on the phone (streaming format v5:
  /// documents are written piece by piece, never all in memory) and
  /// returns it. Throws [StateError] when there is no key yet (ask the
  /// password and call [rememberPassword] first).
  Future<File> createFile({String suffix = ''}) async {
    if (!auth.policy.seesFinance) throw StateError('forbidden');
    final key = await _loadKey();
    if (key == null) throw StateError('no key');
    final now = DateTime.now();
    final dir = await _directory();
    final file = File('${dir.path}/${fileName(now, suffix: suffix)}');
    final part = File('${file.path}.part');
    final content = _collect();
    await BackupStream.write(
      out: part,
      key: key,
      data: service.payload(content),
      fileIds: [for (final d in content.deals) ...d.fileIds],
      readFile: deals.fileForBackup,
    );
    // Only a complete file gets the .ntb name.
    await part.rename(file.path);
    await _box.put('backupLastAt', now.toIso8601String());
    await _prune(dir);
    notifyListeners();
    return file;
  }

  Future<void> _prune(Directory dir) async {
    final files = [
      for (final e in dir.listSync())
        if (e is File && e.path.endsWith('.ntb')) e,
    ]..sort((a, b) => b.path.compareTo(a.path));
    for (final f in files.skip(keepFiles)) {
      await f.delete();
    }
  }

  Future<List<File>> localFiles() async {
    final dir = await _directory();
    return [
      for (final e in dir.listSync())
        if (e is File && e.path.endsWith('.ntb')) e,
    ]..sort((a, b) => b.path.compareTo(a.path));
  }

  /// Weekly backup: when the last one is older than 7 days, creates a new
  /// file and returns it so the UI can offer "Save to Google Drive".
  /// Returns null when nothing is due, the user is not the owner, or the
  /// key is not known yet.
  Future<File?> runWeeklyIfDue({DateTime? now}) async {
    if (!auth.policy.seesFinance) return null;
    if (await _loadKey() == null) return null;
    final t = now ?? DateTime.now();
    final last = lastBackupAt;
    if (last != null && t.difference(last) < weeklyInterval) return null;
    if (deals.rawForBackup().isEmpty && quotes.quotes.isEmpty) return null;
    return createFile(suffix: '_weekly');
  }

  // ---------- Restore ----------

  Future<BackupKey> _keyFor(
    String password,
    KdfParams params,
    Uint8List salt,
  ) async {
    final known = await _loadKey();
    if (known != null && listEquals(known.salt, salt)) return known;
    return BackupKey.derive(password, salt: salt, params: params);
  }

  /// Opens a backup file of any version: v5 (streaming, .ntb), v4 (one
  /// encrypted JSON) or a plain v2.x JSON. For v5 only the data part is
  /// read here (for the confirmation); the documents are read by [apply].
  Future<PendingRestore> openFile(File file, {String? password}) async {
    final header = await BackupStream.readHeader(file);
    if (header != null) {
      final key = await _keyFor(
        password ?? '',
        KdfParams.fromJson(header['kdf'] as Map),
        base64Url.decode((header['kdf'] as Map)['salt'] as String),
      );
      final data = await BackupStream.read(
        file,
        (_, _) => key,
        (_, _) async => key,
        dataOnly: true,
      );
      final c = service.parse(data);
      return PendingRestore._(
        BackupContent(
          deals: c.deals,
          quotes: c.quotes,
          settings: c.settings,
          routes: c.routes,
          chat: c.chat,
          clients: c.clients,
          users: c.users,
          hasRoutes: c.hasRoutes,
          createdAt: DateTime.tryParse(header['createdAt'] as String? ?? ''),
        ),
        file,
        key,
      );
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return PendingRestore._(await open(json, password: password), null, null);
  }

  /// Whether [file] is encrypted (asks for a password).
  static Future<bool> needsPassword(File file) async {
    if (await BackupStream.readHeader(file) != null) return true;
    try {
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic> && BackupService.isEncrypted(json);
    } catch (_) {
      return false;
    }
  }

  /// Opens a v4 / v2.x backup given as JSON.
  Future<BackupContent> open(
    Map<String, dynamic> json, {
    String? password,
  }) async {
    if (BackupService.isEncrypted(json)) {
      return service.decrypt(json, password ?? '', knownKey: await _loadKey());
    }
    return service.decodeLegacy(json);
  }

  /// Restores a backup opened with [openFile]. For a streaming backup the
  /// whole file is verified first; nothing on the phone is touched unless
  /// every record decrypts.
  Future<void> applyPending(PendingRestore p) async {
    if (!auth.policy.seesFinance) throw StateError('forbidden');
    final file = p._file;
    final key = p._key;
    if (file == null || key == null) return apply(p.content);
    await BackupStream.read(file, (_, _) => key, (_, _) async => key);
    await apply(
      p.content,
      files: (write) => BackupStream.read(
        file,
        (_, _) => key,
        (_, _) async => key,
        onFile: write,
      ),
    );
  }

  /// Replaces the data on this phone with [c]. The current data is saved
  /// to a separate local backup first (when the key is known). Document
  /// files come from [c.attachments] or, for a streaming backup, [files].
  Future<void> apply(
    BackupContent c, {
    Future<void> Function(Future<void> Function(String, Uint8List) write)?
    files,
  }) async {
    if (!auth.policy.seesFinance) throw StateError('forbidden');
    if (await _loadKey() != null) {
      await createFile(suffix: '_before_restore');
    }
    // Plain v2.x backups have no clients: link buyers to the directory.
    final clientList = [...c.clients];
    final byKey = {for (final x in clientList) Client.key(x.name): x};
    final dealList = <Deal>[];
    for (final d in c.deals) {
      final name = d.buyerContract.counterpartyName.trim();
      if (d.clientId == null && name.isNotEmpty) {
        final client = byKey.putIfAbsent(Client.key(name), () {
          final x = clients.createDraft().copyWith(name: name);
          clientList.add(x);
          return x;
        });
        dealList.add(d.copyWith(clientId: client.id));
      } else {
        dealList.add(d);
      }
    }
    await deals.clearFilesForRestore();
    if (files != null) {
      await files(deals.restoreFile);
    } else {
      for (final e in c.attachments.entries) {
        await deals.restoreFile(e.key, e.value);
      }
    }
    await deals.replaceAll(dealList);
    await quotes.replaceAll(c.quotes);
    await settings.restoreBackup(c.settings);
    await rates.restoreBackup(c.settings);
    await transportTypes?.restoreBackup(c.settings['transportTypes']);
    await chat.replaceAll(c.chat);
    await clients.replaceAll(clientList);
    if (c.encrypted) await auth.replaceUsers(c.users);
    if (c.hasRoutes) await routes.replaceAll(c.routes);
    await deals.purgeExpired();
  }
}

/// A backup opened for restoring (see [BackupController.openFile]).
class PendingRestore {
  PendingRestore._(this.content, this._file, this._key);

  /// Deals, quotes, settings… of the backup (documents not loaded yet for
  /// a streaming backup).
  final BackupContent content;
  final File? _file;
  final BackupKey? _key;
}
