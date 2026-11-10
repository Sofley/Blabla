import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/account.dart';
import '../../state/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/pattern_lock.dart';
import 'widgets/pin_pad.dart';

/// Unlock with PIN / pattern, or with login + password.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late bool _usePassword =
      context.read<AuthController>().quickUnlock == QuickUnlock.none;
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _error = false;
  bool _busy = false;
  bool _obscure = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _login.text = context.read<AuthController>().account?.login ?? '';
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.read<AuthController>().lockedUntil != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handle(Future<AuthResult> attempt) async {
    setState(() => _busy = true);
    final result = await attempt;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result != AuthResult.ok;
    });
  }

  Future<void> _forgot() async {
    final s = context.s;
    final auth = context.read<AuthController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(s.forgotPassword),
        content: Text(s.forgotPasswordText),
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
            child: Text(s.resetApp),
          ),
        ],
      ),
    );
    if (ok == true) await auth.deleteAccountAndData();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final account = auth.account!;
    final lockedUntil = auth.lockedUntil;
    final quick = auth.quickUnlock;

    String? message;
    if (lockedUntil != null) {
      final secs = lockedUntil.difference(DateTime.now()).inSeconds + 1;
      message = s.tooManyAttempts(secs);
    } else if (_error) {
      message =
          '${s.wrongCredentials} · ${s.attemptsLeft(auth.remainingAttempts)}';
    }
    final name = account.displayName.isNotEmpty
        ? account.displayName
        : account.login;

    final Widget input;
    if (_usePassword || quick == QuickUnlock.none) {
      input = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _login,
            keyboardType: account.loginType == LoginType.email
                ? TextInputType.emailAddress
                : TextInputType.phone,
            decoration: InputDecoration(
              labelText: account.loginType == LoginType.email
                  ? s.email
                  : s.phone,
              prefixIcon: const Icon(Icons.person_outline, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('lock-password'),
            controller: _password,
            obscureText: _obscure,
            onSubmitted: (_) => _submitPassword(auth),
            decoration: InputDecoration(
              labelText: s.password,
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
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _busy || lockedUntil != null
                ? null
                : () => _submitPassword(auth),
            child: Text(s.signIn),
          ),
          if (quick != QuickUnlock.none)
            TextButton(
              onPressed: () => setState(() {
                _usePassword = false;
                _error = false;
              }),
              child: Text(quick.isPin ? s.usePin : s.usePattern),
            ),
        ],
      );
    } else if (quick.isPin) {
      input = PinPad(
        length: quick.pinLength,
        error: _error,
        enabled: !_busy && lockedUntil == null,
        onCompleted: (pin) => _handle(auth.unlockWithQuick(pin)),
      );
    } else {
      input = PatternLock(
        error: _error,
        onCompleted: (p) {
          if (_busy || lockedUntil != null) return;
          _handle(auth.unlockWithQuick(encodePattern(p)));
        },
      );
    }

    return AuthScaffold(
      centered: true,
      title: s.welcomeBack(name),
      subtitle: _usePassword || quick == QuickUnlock.none
          ? s.enterPassword
          : (quick.isPin ? s.enterPin : s.drawPattern),
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child: message == null
                ? null
                : Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          input,
          const SizedBox(height: 12),
          if (!_usePassword && quick != QuickUnlock.none)
            TextButton(
              onPressed: () => setState(() {
                _usePassword = true;
                _error = false;
              }),
              child: Text(s.signInWithPassword),
            ),
          TextButton(
            onPressed: _forgot,
            child: Text(
              s.forgotPassword,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _submitPassword(AuthController auth) {
    FocusScope.of(context).unfocus();
    _handle(auth.unlockWithPassword(_login.text, _password.text));
  }
}
