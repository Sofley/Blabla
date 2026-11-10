import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/account.dart';
import '../../state/auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/pattern_lock.dart';
import 'widgets/pin_pad.dart';

/// Choose and set a quick unlock: PIN 4 / PIN 6 / pattern / password only.
/// Used after registration ([onboarding]) and from Settings.
class QuickUnlockSetupScreen extends StatefulWidget {
  const QuickUnlockSetupScreen({super.key, this.onboarding = false});

  final bool onboarding;

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const QuickUnlockSetupScreen()));

  @override
  State<QuickUnlockSetupScreen> createState() => _QuickUnlockSetupScreenState();
}

class _QuickUnlockSetupScreenState extends State<QuickUnlockSetupScreen> {
  QuickUnlock? _method;
  String? _first;
  bool _mismatch = false;
  bool _tooShort = false;

  Future<void> _finish(QuickUnlock type, [String secret = '']) async {
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    final navigator = Navigator.of(context);
    await auth.setQuickUnlock(type, secret);
    messenger.showSnackBar(SnackBar(content: Text(s.quickUnlockSaved)));
    if (!widget.onboarding && navigator.canPop()) navigator.pop();
  }

  void _onSecret(String value) {
    if (_first == null) {
      setState(() {
        _first = value;
        _mismatch = false;
      });
    } else if (_first == value) {
      _finish(_method!, value);
    } else {
      setState(() {
        _first = null;
        _mismatch = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final method = _method;

    if (method == null) {
      return AuthScaffold(
        appBar: widget.onboarding ? null : AppBar(),
        title: s.quickUnlockTitle,
        subtitle: s.quickUnlockSubtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MethodTile(
              icon: Icons.pin_outlined,
              title: s.pin4,
              subtitle: s.pin4Hint,
              onTap: () => setState(() => _method = QuickUnlock.pin4),
            ),
            _MethodTile(
              icon: Icons.password,
              title: s.pin6,
              subtitle: s.pin6Hint,
              onTap: () => setState(() => _method = QuickUnlock.pin6),
            ),
            _MethodTile(
              icon: Icons.gesture,
              title: s.patternLock,
              subtitle: s.patternHint,
              onTap: () => setState(() => _method = QuickUnlock.pattern),
            ),
            _MethodTile(
              icon: Icons.lock_outline,
              title: s.passwordOnly,
              subtitle: s.passwordOnlyHint,
              onTap: () {
                if (widget.onboarding) {
                  context.read<AuthController>().skipQuickSetup();
                } else {
                  _finish(QuickUnlock.none);
                }
              },
            ),
          ],
        ),
      );
    }

    final confirming = _first != null;
    final String title;
    if (method.isPin) {
      title = confirming ? s.repeatPin : s.enterNewPin(method.pinLength);
    } else {
      title = confirming ? s.repeatPattern : s.drawNewPattern;
    }
    final String? hint = _mismatch
        ? s.codesDontMatch
        : (_tooShort ? s.patternTooShort : null);

    return AuthScaffold(
      centered: true,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => setState(() {
            _method = null;
            _first = null;
            _mismatch = false;
            _tooShort = false;
          }),
        ),
      ),
      title: title,
      subtitle: hint ?? ' ',
      child: method.isPin
          ? PinPad(
              key: ValueKey('pin-$confirming'),
              length: method.pinLength,
              error: _mismatch,
              onCompleted: _onSecret,
            )
          : PatternLock(
              key: ValueKey('pattern-$confirming'),
              error: _mismatch || _tooShort,
              onCompleted: (p) {
                if (p.length < 4) {
                  setState(() => _tooShort = true);
                  return;
                }
                _tooShort = false;
                _onSecret(encodePattern(p));
              },
            ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: .1),
            child: Icon(icon, color: scheme.primary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
