import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../state/auth_controller.dart';
import '../../state/deals_controller.dart';
import '../../state/settings_controller.dart';
import '../auth/quick_unlock_setup_screen.dart';
import '../common/export_sheet.dart';
import '../common/widgets.dart';
import '../../core/l10n/app_lang.dart';
import '../common/language_picker.dart';
import 'appearance_card.dart';
import 'backup_screen.dart';
import 'reminders_card.dart';
import 'users_screen.dart';
import 'trash_screen.dart';
import 'transport_types_screen.dart';
import '../clients/clients_screen.dart';

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

  late final _agentVat = TextEditingController(
    text: Fmt.editableOpt(_settings.defaultAgentVat),
  );
  late final _share = TextEditingController(
    text: Fmt.editableOpt(_settings.defaultVatShare),
  );
  late final _profit = TextEditingController(
    text: Fmt.editable(_settings.defaultProfitPerUnit),
  );

  @override
  void dispose() {
    for (final c in [
      _company,
      _agency,
      _vat,
      _refund,
      _unit,
      _agentVat,
      _share,
      _profit,
    ]) {
      c.dispose();
    }
    super.dispose();
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
    final policy = auth.policy;
    final observer = !policy.isOwner;
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
          if (account != null && observer) ...[
            SectionCard(
              title: s.users,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(auth.currentUserName),
                    subtitle: Text(
                      '${s.roleName(auth.role)} · ${s.roleHint(auth.role)}',
                    ),
                  ),
                  action(Icons.switch_account_outlined, s.switchUser, () {
                    Navigator.of(context).pop();
                    auth.switchUser();
                  }),
                ],
              ),
            ),
            gap,
          ],
          if (account != null && !observer) ...[
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
                  action(Icons.switch_account_outlined, s.switchUser, () {
                    Navigator.of(context).pop();
                    auth.switchUser();
                  }),
                ],
              ),
            ),
            gap,
          ],
          if (policy.canManageUsers ||
              policy.canEditDeals ||
              policy.canSeeClients ||
              policy.canDeleteDeals) ...[
            SectionCard(
              title: s.workSection,
              child: Column(
                children: [
                  if (policy.canManageUsers)
                    action(
                      Icons.group_outlined,
                      s.users,
                      () => UsersScreen.open(context),
                      subtitle: s.usersHint,
                    ),
                  if (policy.canSeeClients)
                    action(
                      Icons.business_outlined,
                      s.clients,
                      () => ClientsScreen.open(context),
                    ),
                  if (policy.canEditDeals)
                    action(
                      Icons.local_shipping_outlined,
                      s.transportTypes,
                      () => TransportTypesScreen.open(context),
                    ),
                  if (policy.canDeleteDeals)
                    action(
                      Icons.delete_outline,
                      s.trash,
                      () => TrashScreen.open(context),
                      subtitle: s.trashHint,
                    ),
                ],
              ),
            ),
            gap,
          ],
          const RemindersCard(),
          gap,
          const AppearanceCard(),
          gap,
          SectionCard(
            title: s.language,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language),
              title: Text(settings.lang?.nativeName ?? s.languageAuto),
              subtitle: Text(
                AppLang.values.map((l) => l.nativeName).join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLanguagePicker(context),
            ),
          ),
          gap,
          if (!observer)
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
                  OptionalNumberField(
                    controller: _agentVat,
                    label: s.defaultAgentVat,
                    suffix: '%',
                    helper: s.agentVatHint,
                    onChanged: settings.setDefaultAgentVat,
                  ),
                  gap,
                  NumberField(
                    controller: _profit,
                    label: s.defaultProfitPerUnit,
                    suffix: 'USD',
                    onChanged: settings.setDefaultProfitPerUnit,
                  ),
                  gap,
                  NumberField(
                    controller: _share,
                    label: s.defaultVatShare,
                    suffix: '%',
                    helper: s.vatShareHint,
                    onChanged: settings.setDefaultVatShare,
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
          if (!observer) ...[
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
                    Icons.cloud_upload_outlined,
                    s.backups,
                    () => BackupScreen.open(context),
                    subtitle: s.backupEncryptedHint,
                  ),
                ],
              ),
            ),
          ],
          gap,
          SectionCard(
            title: s.about,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.aboutText, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                if (account != null && !observer)
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
