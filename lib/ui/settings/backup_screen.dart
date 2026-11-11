import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../export/backup_service.dart';
import '../../export/export_service.dart';
import '../../state/auth_controller.dart';
import '../../state/backup_controller.dart';
import '../common/widgets.dart';

const _export = ExportService();
const _mime = 'application/octet-stream';

/// Offers the weekly backup for Google Drive (variant B: one tap opens the
/// share sheet, the user picks "Drive").
Future<void> showWeeklyBackupPrompt(BuildContext context, File file) async {
  final s = context.s;
  final backup = context.read<BackupController>();
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.cloud_upload_outlined),
      title: Text(s.weeklyBackupReady),
      content: Text('${s.weeklyBackupText}\n\n${s.backupEncryptedHint}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(s.later),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.add_to_drive, size: 18),
          label: Text(s.saveToDrive),
        ),
      ],
    ),
  );
  if (go != true) return;
  final name = file.uri.pathSegments.last;
  if (await _export.share(
    bytes: await file.readAsBytes(),
    fileName: name,
    mimeType: _mime,
    subject: name,
  )) {
    await backup.markExported();
  }
}

/// Asks the account password once so encrypted backups can be made.
Future<bool> ensureBackupKey(BuildContext context) async {
  final backup = context.read<BackupController>();
  if (await backup.hasKey) return true;
  if (!context.mounted) return false;
  final s = context.s;
  final auth = context.read<AuthController>();
  final controller = TextEditingController();
  final password = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.backups),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.backupPasswordNeeded),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: s.password),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(s.save),
        ),
      ],
    ),
  );
  controller.dispose();
  if (password == null || password.isEmpty) return false;
  if (!await auth.checkPassword(password)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.wrongPassword)));
    }
    return false;
  }
  await backup.rememberPassword(password, force: true);
  return true;
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const BackupScreen()));

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  List<File> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await context.read<BackupController>().localFiles();
    if (mounted) setState(() => _files = files);
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.s.exportFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _loadFiles();
    }
  }

  Future<void> _create({required bool drive}) => _run(() async {
    if (!await ensureBackupKey(context)) return;
    if (!mounted) return;
    final s = context.s;
    final backup = context.read<BackupController>();
    final messenger = ScaffoldMessenger.of(context);
    final file = await backup.createFile();
    final bytes = await file.readAsBytes();
    final name = file.uri.pathSegments.last;
    if (drive) {
      if (await _export.share(
        bytes: bytes,
        fileName: name,
        mimeType: _mime,
        subject: name,
      )) {
        await backup.markExported();
      }
    } else if (await _export.save(
      bytes: bytes,
      fileName: name,
      mimeType: _mime,
    )) {
      await backup.markExported();
      messenger.showSnackBar(SnackBar(content: Text(s.fileSaved(name))));
    }
  });

  Future<void> _shareFile(File f) => _run(() async {
    final backup = context.read<BackupController>();
    final name = f.uri.pathSegments.last;
    if (await _export.share(
      bytes: await f.readAsBytes(),
      fileName: name,
      mimeType: _mime,
      subject: name,
    )) {
      await backup.markExported();
    }
  });

  Future<void> _restore() => _run(() async {
    final s = context.s;
    final backup = context.read<BackupController>();
    final messenger = ScaffoldMessenger.of(context);
    final json = await _export.pickJson();
    if (json == null || !mounted) return;
    BackupContent content;
    if (BackupService.isEncrypted(json)) {
      final password = await _askBackupPassword();
      if (password == null) return;
      try {
        content = await backup.open(json, password: password);
      } on SecretBoxAuthenticationError {
        messenger.showSnackBar(SnackBar(content: Text(s.wrongBackupPassword)));
        return;
      }
    } else {
      content = await backup.open(json);
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.restoreReplaceQuestion),
        content: Text(
          '${s.restoreText(content.deals.length, content.quotes.length)}\n\n'
          '${s.restoreSafetyHint}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.restore),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await backup.apply(content);
    messenger.showSnackBar(
      SnackBar(
        content: Text(content.encrypted ? s.restoreDone : s.oldFormatBackup),
      ),
    );
  });

  Future<String?> _askBackupPassword() async {
    final s = context.s;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.backupFilePassword),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: s.password),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(s.restore),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final backup = context.watch<BackupController>();
    String when(DateTime? d) => d == null ? s.never : fmt.dateTime(d);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.backups)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (_busy) const LinearProgressIndicator(),
            SectionCard(
              title: s.backups,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.lastBackup(when(backup.lastBackupAt))),
                  const SizedBox(height: 4),
                  Text(s.lastSavedOutside(when(backup.lastExportedAt))),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _create(drive: true),
                    icon: const Icon(Icons.add_to_drive),
                    label: Text(s.saveToDrive),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _create(drive: false),
                    icon: const Icon(Icons.save_alt),
                    label: Text(s.saveAsFile),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.settings_backup_restore),
                    label: Text(s.restoreFromFile),
                  ),
                  const SizedBox(height: 12),
                  Text(s.backupEncryptedHint, style: muted),
                  const SizedBox(height: 6),
                  Text(s.oldBackupPasswordNote, style: muted),
                  const SizedBox(height: 6),
                  Text(s.driveNote, style: muted),
                ],
              ),
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: s.backupsOnPhone,
                child: Column(
                  children: [
                    for (final f in _files)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_outline),
                        title: Text(
                          f.uri.pathSegments.last,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${(f.lengthSync() / 1024).toStringAsFixed(0)} KB',
                        ),
                        trailing: IconButton(
                          tooltip: s.shareAction,
                          icon: const Icon(Icons.ios_share),
                          onPressed: () => _shareFile(f),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Used by tests to read a backup file written by [BackupController].
Map<String, dynamic> decodeBackupFile(List<int> bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
