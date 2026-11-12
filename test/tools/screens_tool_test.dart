// Manual tool (skipped in normal runs): renders real app screens with the
// real fonts and saves PNG screenshots.
//   NT_SCREENS=/out/dir flutter test test/tools/screens_tool_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:b2b_contracts/app.dart';
import 'package:b2b_contracts/core/l10n/app_strings.dart';
import 'package:b2b_contracts/data/models/account.dart';
import 'package:b2b_contracts/data/models/app_user.dart';
import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/deal.dart';
import 'package:b2b_contracts/data/models/trade_contract.dart';
import 'package:b2b_contracts/data/storage/local_store.dart';
import 'package:b2b_contracts/export/backup_service.dart';
import 'package:b2b_contracts/state/auth_controller.dart';
import 'package:b2b_contracts/state/backup_controller.dart';
import 'package:b2b_contracts/state/deals_controller.dart';
import 'package:b2b_contracts/state/reminders_controller.dart';
import 'package:b2b_contracts/state/widget_sync.dart';
import 'package:b2b_contracts/ui/deals/deal_detail_screen.dart';
import 'package:b2b_contracts/ui/settings/settings_screen.dart';
import 'package:b2b_contracts/ui/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../test_helpers.dart';

final out = Platform.environment['NT_SCREENS'];

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await family('Roboto', [
    'assets/fonts/Roboto-Regular.ttf',
    'assets/fonts/Roboto-Bold.ttf',
  ]);
  await family('MaterialIcons', [
    '/opt/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> settle(WidgetTester t) => t.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 20),
);

Future<void> shot(WidgetTester t, String name) async {
  // ignore: avoid_print
  print('SHOT $name');
  await t.runAsync(() async {
    final layer = t.binding.renderViews.first.debugLayer! as OffsetLayer;
    // The root layer is in physical pixels: capture all of it, scaled down.
    final ui.Image img = await layer.toImage(
      Offset.zero & t.view.physicalSize,
      pixelRatio: 0.6,
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final skip = out == null;
  late LocalStore store;

  setUpAll(() async {
    if (skip) return;
    Directory(out!).createSync(recursive: true);
    await loadFonts();
    await initializeDateFormatting();
    final dir = await Directory.systemTemp.createTemp('screens');
    Hive.init(dir.path);
    store = await LocalStore.open(encrypt: false);
    await store.settings.put('languageCode', 'ru');
    await store.settings.put('themeMode', 'light');
  });

  testWidgets('splash at 2.6 s', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.625;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(),
      ),
    );
    // Let the logo images decode for real.
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    for (var i = 0; i < 26; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await shot(t, '01_splash_2.6s');
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await shot(t, '02_splash_4.6s');
  }, skip: skip);

  testWidgets('owner and manager screens', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.625;
    await t.pumpWidget(
      NexusTradeApp(
        store: store,
        hasher: const FastHasher(),
        splashDuration: Duration.zero,
        backupVault: MemoryBackupKeyVault(),
        reminderScheduler: FakeReminderScheduler(),
        widgetBridge: FakeWidgetBridge(),
        kdf: const KdfParams(memoryKiB: 256, iterations: 1),
      ),
    );
    // ignore: avoid_print
    print('pumped app');
    await settle(t);
    await shot(t, '03_register');

    BuildContext ctx() => t.element(find.byType(Navigator).first);
    await t.runAsync(() async {
      final auth = ctx().read<AuthController>();
      await auth.register(
        type: LoginType.email,
        login: 'owner@nexustrade.uz',
        password: 'Test2026x',
        displayName: 'Владелец',
      );
      auth.skipQuickSetup();
    });
    // ignore: avoid_print
    print('registered');
    await settle(t);

    // Control deal with a dossier.
    await t.runAsync(() async {
      final deals = ctx().read<DealsController>();
      final now = DateTime.now();
      await deals.upsert(
        Deal(
          id: 'ctl',
          buyerContract: TradeContract(
            side: ContractSide.buyer,
            number: 'S-15',
            date: now,
            counterpartyName: 'ООО «Тест Импорт»',
            intermediaryName: 'Nexus Trade LLC',
            productName: 'Полипропилен',
            currency: Currency.usd,
            unitPrice: 2.30,
            quantity: 22000,
            unit: 'кг',
            goodsRatePerUsd: 1,
            agencyFeePercent: 0,
            vatEnabled: false,
          ),
          sellerContract: TradeContract(
            side: ContractSide.seller,
            number: 'P-15',
            date: now,
            counterpartyName: 'Qingdao Plastics Co.',
            intermediaryName: 'Nexus Trade LLC',
            productName: 'Полипропилен',
            currency: Currency.usd,
            unitPrice: 1600,
            quantity: 22,
            unit: 'т',
            goodsRatePerUsd: 1,
            freightCost: 5400,
            logisticsRatePerUsd: 1,
            agencyFeePercent: 8,
            vatEnabled: false,
            vatRefundEnabled: true,
            vatRefundPercent: 9,
            vatBonusShare: 0,
          ),
          deliveryInfo: 'Циндао → Ташкент, фура 22 т, ориентировочно 25 дней',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final main = await deals.addDocument(
        'ctl',
        category: DocCategory.mainContract,
        fileName: 'Договор_DOG-2026-15.pdf',
        bytes: List.filled(250000, 1),
        number: 'DOG-2026/15',
        date: now,
        visibleToClient: true,
      );
      await deals.addVersion(
        'ctl',
        main.id,
        fileName: 'Договор_DOG-2026-15_подписан.pdf',
        bytes: List.filled(260000, 2),
      );
      final inv = await deals.addDocument(
        'ctl',
        category: DocCategory.invoice,
        fileName: 'Invoice_INV-77.pdf',
        bytes: List.filled(80000, 3),
        number: 'INV-77',
        relatedId: main.id,
      );
      await deals.addDocument(
        'ctl',
        category: DocCategory.correction,
        fileName: 'Invoice_INV-77_исправленный.pdf',
        bytes: List.filled(81000, 4),
        number: 'INV-77/1',
        replacesId: inv.id,
      );
      await deals.addDocument(
        'ctl',
        category: DocCategory.supplement,
        fileName: 'Доп_соглашение_1.docx',
        bytes: List.filled(40000, 5),
        number: 'ДС-1',
        relatedId: main.id,
      );
    });
    await settle(t);
    await shot(t, '04_dashboard');

    Navigator.of(ctx()).push(
      MaterialPageRoute(builder: (_) => const DealDetailScreen(dealId: 'ctl')),
    );
    await settle(t);
    await shot(t, '05_deal_top');
    await t.scrollUntilVisible(
      find.text('ОФИЦИАЛЬНЫЙ КОНТРАКТ'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await t.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await settle(t);
    await shot(t, '06_official_contract');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(t);
    await shot(t, '07_dossier');
    await t.scrollUntilVisible(
      find.text('СНИМКИ РАСЧЁТА'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('СНИМКИ РАСЧЁТА'));
    await settle(t);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await settle(t);
    await shot(t, '07b_snapshots');
    await t.scrollUntilVisible(
      find.text('Invoice_INV-77.pdf'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(t);
    await t.tap(find.text('Invoice_INV-77.pdf'));
    await settle(t);
    await shot(t, '08_document_sheet');
    Navigator.of(ctx()).pop();
    await settle(t);
    Navigator.of(ctx()).pop();
    await settle(t);

    Navigator.of(ctx())
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await settle(t);
    await shot(t, '09_settings');
    Navigator.of(ctx()).pop();
    await settle(t);

    // Manager profile: no internal finance anywhere.
    await t.runAsync(() async {
      final auth = ctx().read<AuthController>();
      final m = await auth.addUser(
        name: 'Менеджер Али',
        role: UserRole.manager,
        pin: '4321',
      );
      await ctx().read<DealsController>().setAssignees('ctl', [m.id]);
      auth.switchUser();
      await auth.unlockAsUser(m.id, '4321');
    });
    await settle(t);
    await shot(t, '10_manager_home');
    Navigator.of(ctx()).push(
      MaterialPageRoute(builder: (_) => const DealDetailScreen(dealId: 'ctl')),
    );
    await settle(t);
    await shot(t, '11_manager_deal');
  }, skip: skip);
}
