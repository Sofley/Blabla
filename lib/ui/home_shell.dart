import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../state/settings_controller.dart';
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

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    DealsListScreen(),
    QuotesListScreen(),
    RatesScreen(actions: [SettingsButton()]),
    ChatListScreen(actions: [SettingsButton()]),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final observer = context.watch<SettingsController>().observerMode;
    final Widget? fab = observer
        ? null
        : switch (_index) {
            0 || 1 => FloatingActionButton.extended(
              heroTag: 'fab-deal',
              onPressed: () => DealEditorScreen.open(context),
              icon: const Icon(Icons.add),
              label: Text(s.newDeal),
            ),
            2 => FloatingActionButton.extended(
              heroTag: 'fab-quote',
              onPressed: () => QuoteEditorScreen.open(context),
              icon: const Icon(Icons.calculate_outlined),
              label: Text(s.newQuote),
            ),
            _ => null,
          };
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: fab,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (observer) const ObserverBanner(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.insights_outlined),
                selectedIcon: const Icon(Icons.insights),
                label: s.navHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.folder_copy_outlined),
                selectedIcon: const Icon(Icons.folder_copy),
                label: s.navDeals,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calculate_outlined),
                selectedIcon: const Icon(Icons.calculate),
                label: s.navPrice,
              ),
              NavigationDestination(
                icon: const Icon(Icons.currency_exchange_outlined),
                selectedIcon: const Icon(Icons.currency_exchange),
                label: s.navRates,
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline),
                selectedIcon: const Icon(Icons.chat_bubble),
                label: s.navChat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Amber strip shown while Observer (read-only) mode is on.
class ObserverBanner extends StatelessWidget {
  const ObserverBanner({super.key});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFE0A000);
    return Material(
      color: amber,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.visibility, size: 16, color: Colors.black87),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.s.observerBanner,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
