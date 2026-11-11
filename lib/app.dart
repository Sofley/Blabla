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
import 'data/models/app_user.dart';
import 'data/models/chat_message.dart';
import 'data/storage/attachment_store.dart';
import 'export/backup_service.dart';
import 'state/backup_controller.dart';
import 'state/clients_controller.dart';
import 'state/reminders_controller.dart';
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
import 'ui/splash/splash_screen.dart';
import 'core/l10n/app_lang.dart';

class NexusTradeApp extends StatefulWidget {
  const NexusTradeApp({
    super.key,
    required this.store,
    this.hasher = const PasswordHasher(),
    this.splashDuration = SplashScreen.total,
    this.attachments,
    this.backupVault,
    this.reminderScheduler,
    this.kdf = const KdfParams(),
  });

  final LocalStore store;
  final PasswordHasher hasher;

  /// Encrypted document storage (in-memory when null, e.g. in tests).
  final AttachmentStore? attachments;
  final BackupKeyVault? backupVault;
  final ReminderScheduler? reminderScheduler;
  final KdfParams kdf;

  /// How long the brand splash is shown on launch.
  final Duration splashDuration;

  @override
  State<NexusTradeApp> createState() => _NexusTradeAppState();
}

class _NexusTradeAppState extends State<NexusTradeApp>
    with WidgetsBindingObserver {
  late final settings = SettingsController(
    SettingsRepository(widget.store.settings),
  );
  late final chat = ChatController(widget.store.chat);
  late final routes = RoutesController(widget.store.routes);
  late final rates = RatesController(widget.store.settings);
  late final DealsController deals = DealsController(
    DealRepository(widget.store.deals),
    policy: () => auth.policy,
    actor: () => auth.currentUserName,
    attachments: widget.attachments,
    onEvent: (dealId, code) => code == 'deleted'
        ? chat.deleteDealChat(dealId)
        : chat.post(dealId, ChatAuthor.system, code),
  );
  late final ClientsController clients = ClientsController(
    widget.store.clients,
    policy: () => auth.policy,
  );
  late final BackupController backup = BackupController(
    settingsBox: widget.store.settings,
    auth: auth,
    deals: deals,
    quotes: quotes,
    settings: settings,
    rates: rates,
    routes: routes,
    chat: chat,
    clients: clients,
    vault: widget.backupVault ?? const SecureBackupKeyVault(),
    kdf: widget.kdf,
  );
  late final reminders = RemindersController(
    widget.store.settings,
    userId: () => auth.currentUser?.id ?? AppUser.ownerId,
    scheduler: widget.reminderScheduler,
  );
  late final quotes = QuotesController(QuoteRepository(widget.store.quotes));
  late final AuthController auth = AuthController(
    AuthRepository(widget.store.auth),
    hasher: widget.hasher,
    onPasswordEntered: (password, isNew) =>
        backup.rememberPassword(password, force: isNew),
    onWipe: () async {
      await widget.store.wipe();
      await widget.attachments?.deleteAll();
      await backup.forgetKey();
      clients.reload();
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
    auth.addListener(_onSession);
    // Retention rule of the trash: 15 days, then deleted for good.
    deals.purgeExpired();
  }

  /// The access policy follows the signed-in user.
  void _onSession() {
    deals.onSessionChanged();
    clients.onSessionChanged();
  }

  @override
  void dispose() {
    auth.removeListener(_onSession);
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
        ChangeNotifierProvider.value(value: clients),
        ChangeNotifierProvider.value(value: backup),
        ChangeNotifierProvider.value(value: reminders),
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
          localeResolutionCallback: (device, supported) =>
              AppLang.fromLocale(device ?? const Locale('en')).locale,
          home: _AuthGate(splashDuration: widget.splashDuration),
        ),
      ),
    );
  }
}

/// Shows the splash, then registration, lock screen or the app.
class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.splashDuration});

  final Duration splashDuration;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late bool _splash = widget.splashDuration > Duration.zero;

  @override
  void initState() {
    super.initState();
    if (_splash) {
      Future.delayed(widget.splashDuration, () {
        if (mounted) setState(() => _splash = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final Widget child = _splash
        ? SplashScreen(onSkip: () => setState(() => _splash = false))
        : switch (auth.status) {
            AuthStatus.needsRegistration => const RegisterScreen(),
            AuthStatus.locked => const LockScreen(),
            AuthStatus.unlocked when auth.needsQuickSetup =>
              const QuickUnlockSetupScreen(onboarding: true),
            AuthStatus.unlocked => const HomeShell(),
          };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: KeyedSubtree(
        // The splash keeps one key while it is shown, so it is never
        // rebuilt from scratch (that used to restart the slogan).
        key: ValueKey(
          _splash
              ? 'splash'
              : '${auth.status}-${auth.needsQuickSetup}-${auth.currentUser?.id}',
        ),
        child: child,
      ),
    );
  }
}
