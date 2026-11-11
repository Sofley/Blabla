import 'dart:io';

import 'package:b2b_contracts/app.dart';
import 'package:b2b_contracts/data/storage/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'test_helpers.dart';

void main() {
  late Directory dir;
  late LocalStore store;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('b2b_test');
    Hive.init(dir.path);
    store = await LocalStore.open(encrypt: false);
    await store.settings.put('languageCode', 'en');
  });

  // Hive.close() can wait on writes scheduled inside the fake-async test zone,
  // so only the temp directory is removed here.
  tearDownAll(() => dir.delete(recursive: true));

  testWidgets('register → quick unlock → dashboard → price calculator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      NexusTradeApp(
        store: store,
        hasher: const FastHasher(),
        splashDuration: Duration.zero,
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );

    // Registration
    expect(find.text('Create your account'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reg-login')),
      'owner@company.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reg-password')),
      'secret1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reg-confirm')),
      'secret1',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Create account'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );

    // Quick unlock choice → 4-digit PIN
    expect(find.text('Quick unlock'), findsOneWidget);
    await tester.tap(find.text('4-digit PIN'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    for (final round in [0, 1]) {
      for (final d in ['1', '3', '5', '7']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.runAsync(() async {
        await tester.pump(const Duration(milliseconds: 200));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      if (round == 0) expect(find.text('Repeat the PIN'), findsOneWidget);
    }

    // Dashboard
    expect(find.text('Monthly analytics'), findsOneWidget);

    // Price calculator tab
    await tester.tap(find.text('Price').last);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    expect(find.text('Selling price to buyer'.toUpperCase()), findsOneWidget);

    // Rates & tariffs, chat tabs
    await tester.pageBack();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    await tester.tap(find.text('Rates').last);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    expect(find.text('Rates & tariffs'), findsOneWidget);
    await tester.tap(find.text('Logistics tariffs'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    expect(find.textContaining('Ташкент'), findsOneWidget);
    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    expect(find.text('Contract chat'), findsOneWidget);
  });
}
