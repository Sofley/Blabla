import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/account.dart';
import '../../state/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// First launch: create a local account with e-mail or phone + password.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  LoginType _type = LoginType.email;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _login.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await context.read<AuthController>().register(
      type: _type,
      login: _login.text,
      password: _password.text,
      displayName: _name.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    const gap = SizedBox(height: 12);

    return AuthScaffold(
      title: s.registerTitle,
      subtitle: s.registerSubtitle,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<LoginType>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: LoginType.email,
                  icon: const Icon(Icons.alternate_email, size: 18),
                  label: Text(s.byEmail),
                ),
                ButtonSegment(
                  value: LoginType.phone,
                  icon: const Icon(Icons.phone_iphone, size: 18),
                  label: Text(s.byPhone),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() {
                _type = v.first;
                _login.clear();
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('reg-login'),
              controller: _login,
              keyboardType: _type == LoginType.email
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              autofillHints: [
                _type == LoginType.email
                    ? AutofillHints.email
                    : AutofillHints.telephoneNumber,
              ],
              decoration: InputDecoration(
                labelText: _type == LoginType.email ? s.email : s.phone,
                hintText: _type == LoginType.email
                    ? 'name@company.com'
                    : '+998 90 123 45 67',
                prefixIcon: Icon(
                  _type == LoginType.email
                      ? Icons.alternate_email
                      : Icons.phone_iphone,
                  size: 18,
                ),
              ),
              validator: (v) =>
                  AuthController.normalizeLogin(_type, v ?? '') == null
                  ? (_type == LoginType.email ? s.invalidEmail : s.invalidPhone)
                  : null,
            ),
            gap,
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: s.yourName,
                prefixIcon: const Icon(Icons.person_outline, size: 18),
              ),
            ),
            gap,
            TextFormField(
              key: const ValueKey('reg-password'),
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: s.password,
                helperText: s.passwordRules,
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => AuthController.isStrongEnough(v ?? '')
                  ? null
                  : s.passwordRules,
            ),
            gap,
            TextFormField(
              key: const ValueKey('reg-confirm'),
              controller: _confirm,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: s.confirmPassword,
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
              ),
              validator: (v) =>
                  v == _password.text ? null : s.passwordsDontMatch,
            ),
            gap,
            // The password also derives the backup key.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.key_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.registrationBackupWarning,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.createAccount),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.localAccountNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
