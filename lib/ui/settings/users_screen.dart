import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/app_user.dart';
import '../../state/auth_controller.dart';
import '../../state/clients_controller.dart';

/// Local user profiles (administrator, manager, partner, client).
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const UsersScreen()));

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final auth = context.watch<AuthController>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.users)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showUserEditor(context),
        icon: const Icon(Icons.person_add_alt),
        label: Text(s.addUser),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(s.usersHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(s.roleName(UserRole.owner)),
              subtitle: Text(s.roleHint(UserRole.owner)),
            ),
          ),
          if (auth.users.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(s.noUsers)),
            ),
          for (final u in auth.users)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(u.name),
                subtitle: Text('${s.roleName(u.role)} · ${s.roleHint(u.role)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showUserEditor(context, user: u),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showUserEditor(BuildContext context, {AppUser? user}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UserEditor(user: user),
    );

class _UserEditor extends StatefulWidget {
  const _UserEditor({this.user});

  final AppUser? user;

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  final _pin = TextEditingController();
  late UserRole _role = widget.user?.role ?? UserRole.manager;
  late String? _clientId = widget.user?.clientId;

  static const _roles = [
    UserRole.admin,
    UserRole.manager,
    UserRole.partner,
    UserRole.client,
  ];

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    final u = widget.user;
    if (u == null) {
      await auth.addUser(
        name: _name.text,
        role: _role,
        pin: _pin.text,
        clientId: _clientId,
      );
    } else {
      await auth.updateUser(
        u,
        name: _name.text,
        role: _role,
        clientId: _clientId,
        newPin: _pin.text,
      );
    }
    navigator.pop();
  }

  Future<void> _delete() async {
    final s = context.s;
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteUserQuestion),
        content: Text(widget.user!.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await auth.deleteUser(widget.user!.id);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final clients = context.watch<ClientsController>().clients;
    final isNew = widget.user == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              isNew ? s.addUser : widget.user!.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s.userName),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? s.nameRequired : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.roleField),
              items: [
                for (final r in _roles)
                  DropdownMenuItem(value: r, child: Text(s.roleName(r))),
              ],
              onChanged: (r) => setState(() => _role = r ?? _role),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                s.roleHint(_role),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_role == UserRole.client) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: clients.any((c) => c.id == _clientId)
                    ? _clientId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.clientLink),
                items: [
                  for (final c in clients)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _clientId = v),
                validator: (v) => v == null ? s.selectClient : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              decoration: InputDecoration(
                labelText: isNew ? s.profilePin : s.newPinOptional,
              ),
              validator: (v) {
                final pin = v ?? '';
                if (!isNew && pin.isEmpty) return null;
                return pin.length < 4 || pin.length > 6 ? s.pinInvalid : null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isNew)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(s.delete),
                  ),
                const Spacer(),
                FilledButton(onPressed: _save, child: Text(s.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
