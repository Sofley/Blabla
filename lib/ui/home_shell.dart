import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../state/auth_controller.dart';
import '../state/backup_controller.dart';
import '../state/reminders_controller.dart';
import 'settings/backup_screen.dart';
import 'chat/chat_screens.dart';
import 'dashboard/dashboard_screen.dart';
import 'deals/deal_editor_screen.dart';
import 'deals/deals_list_screen.dart';
import 'prices/quote_editor_screen.dart';
import 'prices/quotes_list_screen.dart';
import 'rates/rates_screen.dart';
import 'settings/settings_screen.dart';

/// Gear button opening Settings (themes, account, data) from any tab.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.s.navSettings,
    icon: const Icon(Icons.tune),
    onPressed: () =>
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum _Tab { home, deals, price, rates, chat }

class _HomeShellState extends State<HomeShell> {
  _Tab _tab = _Tab.home;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterUnlock());
  }

  /// Runs once per session: plans reminders and makes the weekly backup.
  Future<void> _afterUnlock() async {
    if (!mounted) return;
    final s = context.s;
    await context.read<RemindersController>().reschedule(
      title: 'NexusTrade',
      body: s.reminderBody,
    );
    if (!mounted) return;
    final backup = context.read<BackupController>();
    try {
      final file = await backup.runWeeklyIfDue();
      if (file != null && mounted) await showWeeklyBackupPrompt(context, file);
    } catch (e) {
      debugPrint('weekly backup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final policy = context.watch<AuthController>().policy;
    // Tabs available to the role: the price calculator is internal
    // finance (owner only); the chat is for the team.
    final tabs = [
      _Tab.home,
      _Tab.deals,
      if (policy.seesFinance) _Tab.price,
      if (policy.canUseChat) _Tab.rates,
      if (policy.canUseChat) _Tab.chat,
    ];
    final tab = tabs.contains(_tab) ? _tab : _Tab.home;
    final index = tabs.indexOf(tab);
    final Widget? fab = !policy.canEditDeals
        ? null
        : switch (tab) {
            _Tab.home || _Tab.deals => FloatingActionButton.extended(
              heroTag: 'fab-deal',
              onPressed: () => DealEditorScreen.open(context),
              icon: const Icon(Icons.add),
              label: Text(s.newDeal),
            ),
            _Tab.price => FloatingActionButton.extended(
              heroTag: 'fab-quote',
              onPressed: () => QuoteEditorScreen.open(context),
              icon: const Icon(Icons.calculate_outlined),
              label: Text(s.newQuote),
            ),
            _ => null,
          };
    Widget page(_Tab t) => switch (t) {
      _Tab.home => const DashboardScreen(),
      _Tab.deals => const DealsListScreen(),
      _Tab.price => const QuotesListScreen(),
      _Tab.rates => const RatesScreen(actions: [SettingsButton()]),
      _Tab.chat => const ChatListScreen(actions: [SettingsButton()]),
    };
    NavigationDestination dest(_Tab t) => switch (t) {
      _Tab.home => NavigationDestination(
        icon: const Icon(Icons.insights_outlined),
        selectedIcon: const Icon(Icons.insights),
        label: s.navHome,
      ),
      _Tab.deals => NavigationDestination(
        icon: const Icon(Icons.folder_copy_outlined),
        selectedIcon: const Icon(Icons.folder_copy),
        label: s.navDeals,
      ),
      _Tab.price => NavigationDestination(
        icon: const Icon(Icons.calculate_outlined),
        selectedIcon: const Icon(Icons.calculate),
        label: s.navPrice,
      ),
      _Tab.rates => NavigationDestination(
        icon: const Icon(Icons.currency_exchange_outlined),
        selectedIcon: const Icon(Icons.currency_exchange),
        label: s.navRates,
      ),
      _Tab.chat => NavigationDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        selectedIcon: const Icon(Icons.chat_bubble),
        label: s.navChat,
      ),
    };
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) page(t)],
      ),
      floatingActionButton: fab,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!policy.isOwner) const SessionBanner(),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _tab = tabs[i]),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [for (final t in tabs) dest(t)],
          ),
        ],
      ),
    );
  }
}

/// Strip shown while a non-owner profile is signed in: who and which role,
/// with a button to switch the user.
class SessionBanner extends StatelessWidget {
  const SessionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final auth = context.watch<AuthController>();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
        child: Row(
          children: [
            Icon(
              Icons.badge_outlined,
              size: 16,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.signedInAs(auth.currentUserName, s.roleName(auth.role)),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: auth.switchUser,
              icon: const Icon(Icons.switch_account_outlined, size: 16),
              label: Text(s.switchUser),
            ),
          ],
        ),
      ),
    );
  }
}
