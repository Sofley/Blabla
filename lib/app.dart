import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_strings.dart';
import 'core/security/password_hasher.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/deal_repository.dart';
import 'data/repositories/quote_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/storage/local_store.dart';
import 'state/auth_controller.dart';
import 'state/deals_controller.dart';
import 'state/quotes_controller.dart';
import 'state/settings_controller.dart';
import 'ui/auth/lock_screen.dart';
import 'ui/auth/quick_unlock_setup_screen.dart';
import 'ui/auth/register_screen.dart';
import 'ui/home_shell.dart';

class B2BLedgerApp extends StatefulWidget {
  const B2BLedgerApp({
    super.key,
    required this.store,
    this.hasher = const PasswordHasher(),
  });

  final LocalStore store;
  final PasswordHasher hasher;

  @override
  State<B2BLedgerApp> createState() => _B2BLedgerAppState();
}

class _B2BLedgerAppState extends State<B2BLedgerApp>
    with WidgetsBindingObserver {
  late final settings = SettingsController(
    SettingsRepository(widget.store.settings),
  );
  late final deals = DealsController(DealRepository(widget.store.deals));
  late final quotes = QuotesController(QuoteRepository(widget.store.quotes));
  late final auth = AuthController(
    AuthRepository(widget.store.auth),
    hasher: widget.hasher,
    onWipe: () async {
      await widget.store.wipe();
      deals.reload();
      quotes.reload();
      settings.reload();
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        auth.onBackground();
      case AppLifecycleState.resumed:
        auth.onForeground();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: deals),
        ChangeNotifierProvider.value(value: quotes),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'B2B Ledger',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (device, supported) {
            for (final l in supported) {
              if (l.languageCode == device?.languageCode) return l;
            }
            return const Locale('en');
          },
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

/// Shows registration, lock screen or the app depending on auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final Widget child = switch (auth.status) {
      AuthStatus.needsRegistration => const RegisterScreen(),
      AuthStatus.locked => const LockScreen(),
      AuthStatus.unlocked when auth.needsQuickSetup =>
        const QuickUnlockSetupScreen(onboarding: true),
      AuthStatus.unlocked => const HomeShell(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey('${auth.status}-${auth.needsQuickSetup}'),
        child: child,
      ),
    );
  }
}
