import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../export/backup_service.dart';
import '../../export/export_service.dart';
import '../../state/auth_controller.dart';
import '../../state/deals_controller.dart';
import '../../state/quotes_controller.dart';
import '../../state/settings_controller.dart';
import '../auth/quick_unlock_setup_screen.dart';
import '../common/export_sheet.dart';
import '../common/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _settings = context.read<SettingsController>();
  late final _company = TextEditingController(text: _settings.companyName);
  late final _agency = TextEditingController(
    text: Fmt.editable(_settings.defaultAgencyFee),
  );
  late final _vat = TextEditingController(
    text: Fmt.editable(_settings.defaultVat),
  );
  late final _refund = TextEditingController(
    text: Fmt.editable(_settings.defaultVatRefund),
  );
  late final _unit = TextEditingController(text: _settings.defaultUnit);

  static const _backup = BackupService();
  static const _export = ExportService();

  @override
  void dispose() {
    for (final c in [_company, _agency, _vat, _refund, _unit]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------- Data ----------------

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final size = box.size;
    return Rect.fromLTWH(0, size.height / 2, size.width, 1);
  }

  Future<void> _makeBackup({required bool share}) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final bytes = _backup.encode(
      deals: context.read<DealsController>().deals,
      quotes: context.read<QuotesController>().quotes,
      settings: _settings.toBackup(),
    );
    final d = DateTime.now();
    final name =
        'b2b_ledger_backup_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
    try {
      if (share) {
        await _export.share(
          bytes: bytes,
          fileName: name,
          mimeType: 'application/json',
          subject: name,
          origin: _shareOrigin(),
        );
      } else if (await _export.save(
        bytes: bytes,
        fileName: name,
        mimeType: 'application/json',
      )) {
        messenger.showSnackBar(SnackBar(content: Text(s.fileSaved(name))));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${s.exportFailed}: $e')));
    }
  }

  Future<void> _restore() async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final deals = context.read<DealsController>();
    final quotes = context.read<QuotesController>();
    try {
      final json = await _export.pickJson();
      if (json == null || !mounted) return;
      final content = _backup.decode(json);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.restoreQuestion),
          content: Text(
            s.restoreText(content.deals.length, content.quotes.length),
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
      await deals.replaceAll(content.deals);
      await quotes.replaceAll(content.quotes);
      await _settings.restoreBackup(content.settings);
      _company.text = _settings.companyName;
      _agency.text = Fmt.editable(_settings.defaultAgencyFee);
      _vat.text = Fmt.editable(_settings.defaultVat);
      _refund.text = Fmt.editable(_settings.defaultVatRefund);
      _unit.text = _settings.defaultUnit;
      messenger.showSnackBar(SnackBar(content: Text(s.restoreDone)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.invalidBackup)));
    }
  }

  // ---------------- Account ----------------

  Future<void> _changePassword() async {
    final s = context.s;
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    final current = TextEditingController();
    final next = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.changePassword),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: InputDecoration(labelText: s.currentPassword),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: s.newPassword,
                  helperText: s.passwordRules,
                  helperMaxLines: 2,
                ),
                validator: (v) => AuthController.isStrongEnough(v ?? '')
                    ? null
                    : s.passwordRules,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (ok == true) {
      final changed = await auth.changePassword(current.text, next.text);
      messenger.showSnackBar(
        SnackBar(
          content: Text(changed ? s.passwordChanged : s.wrongCurrentPassword),
        ),
      );
    }
    current.dispose();
    next.dispose();
  }

  Future<void> _deleteAccount() async {
    final s = context.s;
    final auth = context.read<AuthController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(s.deleteAccount),
        content: Text(s.deleteAccountText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) await auth.deleteAccountAndData();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = context.watch<SettingsController>();
    final auth = context.watch<AuthController>();
    final account = auth.account;
    final theme = Theme.of(context);
    const gap = SizedBox(height: 12);

    Widget action(
      IconData icon,
      String title,
      VoidCallback onTap, {
      String? subtitle,
      Color? color,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.navSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          if (account != null) ...[
            SectionCard(
              title: s.account,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: Text(
                        (account.displayName.isNotEmpty
                                ? account.displayName
                                : account.login)
                            .replaceAll('+', '')
                            .substring(0, 1)
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(
                      account.displayName.isNotEmpty
                          ? account.displayName
                          : account.login,
                    ),
                    subtitle: Text(
                      '${account.loginType == LoginType.email ? s.email : s.phone}: ${account.login}',
                    ),
                  ),
                  const Divider(),
                  action(
                    Icons.pin_outlined,
                    s.quickUnlockTitle,
                    () => QuickUnlockSetupScreen.open(context),
                    subtitle: s.quickUnlockName(account.quickUnlock),
                  ),
                  action(Icons.password, s.changePassword, _changePassword),
                  action(Icons.lock_outline, s.lockNow, auth.lock),
                ],
              ),
            ),
            gap,
          ],
          SectionCard(
            title: s.appearance,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined, size: 18),
                  label: Text(s.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined, size: 18),
                  label: Text(s.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined, size: 18),
                  label: Text(s.themeDark),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (v) => settings.setThemeMode(v.first),
            ),
          ),
          gap,
          SectionCard(
            title: s.language,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'system', label: Text(s.languageSystem)),
                const ButtonSegment(value: 'ru', label: Text('Русский')),
                const ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {settings.languageCode ?? 'system'},
              onSelectionChanged: (v) => settings.setLanguageCode(
                v.first == 'system' ? null : v.first,
              ),
            ),
          ),
          gap,
          SectionCard(
            title: s.defaults,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.defaultsHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                gap,
                TextField(
                  controller: _company,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: s.myCompany,
                    prefixIcon: const Icon(Icons.business_outlined, size: 18),
                  ),
                  onChanged: settings.setCompanyName,
                ),
                gap,
                Row(
                  children: [
                    Expanded(
                      child: NumberField(
                        controller: _agency,
                        label: s.agentPercentShort,
                        suffix: '%',
                        onChanged: settings.setDefaultAgencyFee,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NumberField(
                        controller: _vat,
                        label: s.vatPercent,
                        suffix: '%',
                        onChanged: settings.setDefaultVat,
                      ),
                    ),
                  ],
                ),
                gap,
                Row(
                  children: [
                    Expanded(
                      child: NumberField(
                        controller: _refund,
                        label: s.vatRefundRate,
                        suffix: '%',
                        onChanged: settings.setDefaultVatRefund,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _unit,
                        decoration: InputDecoration(
                          labelText: s.unitLabel,
                          hintText: s.unitHint,
                        ),
                        onChanged: settings.setDefaultUnit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          gap,
          SectionCard(
            title: s.dataSection,
            child: Column(
              children: [
                action(
                  Icons.table_view_outlined,
                  s.exportAllDeals,
                  () => showExportSheet(
                    context,
                    build: (b) => b.registry(
                      context.read<DealsController>().deals,
                      s.allDeals,
                    ),
                  ),
                  subtitle: 'Excel · PDF · Word',
                ),
                action(
                  Icons.backup_outlined,
                  s.backupSave,
                  () => _makeBackup(share: false),
                  subtitle: s.backupHint,
                ),
                action(
                  Icons.share_outlined,
                  s.backupShare,
                  () => _makeBackup(share: true),
                ),
                action(
                  Icons.settings_backup_restore,
                  s.restore,
                  _restore,
                  subtitle: s.restoreHint,
                ),
              ],
            ),
          ),
          gap,
          SectionCard(
            title: s.about,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.aboutText, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                if (account != null)
                  action(
                    Icons.delete_forever_outlined,
                    s.deleteAccount,
                    _deleteAccount,
                    color: theme.colorScheme.error,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
