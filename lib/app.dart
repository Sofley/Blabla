import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/deal_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'state/deals_controller.dart';
import 'state/settings_controller.dart';
import 'ui/home_shell.dart';

class B2BLedgerApp extends StatelessWidget {
  const B2BLedgerApp({
    super.key,
    required this.dealRepository,
    required this.settingsRepository,
  });

  final DealRepository dealRepository;
  final SettingsRepository settingsRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsController(settingsRepository),
        ),
        ChangeNotifierProvider(create: (_) => DealsController(dealRepository)),
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
          home: const HomeShell(),
        ),
      ),
    );
  }
}
