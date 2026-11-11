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
import 'data/models/chat_message.dart';
import 'state/auth_controller.dart';
import 'state/chat_controller.dart';
import 'state/rates_controller.dart';
import 'state/routes_controller.dart';
import 'state/deals_controller.dart';
import 'state/quotes_controller.dart';
import 'state/settings_controller.dart';
import 'ui/auth/lock_screen.dart';
import 'ui/auth/quick_unlock_setup_screen.dart';
import 'ui/auth/register_screen.dart';
import 'ui/common/app_background.dart';
import 'ui/home_shell.dart';

class NexusTradeApp extends StatefulWidget {
  const NexusTradeApp({
    super.key,
    required this.store,
    this.hasher = const PasswordHasher(),
  });

  final LocalStore store;
  final PasswordHasher hasher;

  @override
  State<NexusTradeApp> createState() => _NexusTradeAppState();
}

class _NexusTradeAppState extends State<NexusTradeApp>
    with WidgetsBindingObserver {
  late final settings = SettingsController(
    SettingsRepository(widget.store.settings),
  );
  late final chat = ChatController(widget.store.chat);
  late final routes = RoutesController(
    widget.store.routes,
    flags: widget.store.settings,
  );
  late final rates = RatesController(widget.store.settings);
  late final deals = DealsController(
    DealRepository(widget.store.deals),
    onEvent: (dealId, code) => code == 'deleted'
        ? chat.deleteDealChat(dealId)
        : chat.post(dealId, ChatAuthor.system, code),
  );
  late final quotes = QuotesController(QuoteRepository(widget.store.quotes));
  late final auth = AuthController(
    AuthRepository(widget.store.auth),
    hasher: widget.hasher,
    onWipe: () async {
      await widget.store.wipe();
      deals.reload();
      quotes.reload();
      settings.reload();
      chat.reload();
      routes.reload();
      rates.reload();
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
        ChangeNotifierProvider.value(value: chat),
        ChangeNotifierProvider.value(value: routes),
        ChangeNotifierProvider.value(value: rates),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'NexusTrade',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(
            accent: settings.accent,
            glass: settings.backgroundPath != null,
          ),
          darkTheme: AppTheme.dark(
            accent: settings.accent,
            glass: settings.backgroundPath != null,
          ),
          builder: (context, child) => AppBackground(
            path: settings.backgroundPath,
            opacity: settings.backgroundOpacity,
            blur: settings.backgroundBlur,
            child: child!,
          ),
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
