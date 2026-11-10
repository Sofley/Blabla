import 'dart:io';

import 'package:b2b_contracts/app.dart';
import 'package:b2b_contracts/data/repositories/deal_repository.dart';
import 'package:b2b_contracts/data/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late DealRepository deals;
  late SettingsRepository settings;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('b2b_test');
    Hive.init(dir.path);
    deals = await DealRepository.open();
    settings = await SettingsRepository.open();
    await settings.setLanguageCode('en');
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets('app starts on the dashboard and opens the deal editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      B2BLedgerApp(dealRepository: deals, settingsRepository: settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly analytics'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Contract #1'), findsWidgets);
    expect(find.text('Buyer ↔ Intermediary'), findsOneWidget);

    final notes = find.text('Remarks / Notes'.toUpperCase());
    await tester.scrollUntilVisible(
      notes,
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('contract-buyer')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(notes, findsOneWidget);

    // Contract #2 lives on its own tab.
    await tester.tap(find.text('Contract #2'));
    await tester.pumpAndSettle();
    expect(find.text('Intermediary ↔ Seller'), findsOneWidget);
  });
}
