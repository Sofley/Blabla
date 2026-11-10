import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import 'dashboard/dashboard_screen.dart';
import 'deals/deal_editor_screen.dart';
import 'deals/deals_list_screen.dart';
import 'prices/quote_editor_screen.dart';
import 'prices/quotes_list_screen.dart';
import 'settings/settings_screen.dart';

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
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final Widget? fab = switch (_index) {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: s.navDashboard,
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
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune),
            label: s.navSettings,
          ),
        ],
      ),
    );
  }
}
