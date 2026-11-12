// Manual tool (skipped in normal runs): renders the screens used in the
// tutorial video, in Russian, with real fonts.
//   NT_TUTORIAL=/out/dir flutter test test/tools/tutorial_screens_tool_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:b2b_contracts/app.dart';
import 'package:b2b_contracts/data/models/account.dart';
import 'package:b2b_contracts/data/models/app_user.dart';
import 'package:b2b_contracts/data/models/contract_stage.dart';
import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/deal.dart';
import 'package:b2b_contracts/data/models/trade_contract.dart';
import 'package:b2b_contracts/data/storage/local_store.dart';
import 'package:b2b_contracts/export/backup_service.dart';
import 'package:b2b_contracts/state/auth_controller.dart';
import 'package:b2b_contracts/state/backup_controller.dart';
import 'package:b2b_contracts/state/clients_controller.dart';
import 'package:b2b_contracts/state/deals_controller.dart';
import 'package:b2b_contracts/state/quotes_controller.dart';
import 'package:b2b_contracts/state/reminders_controller.dart';
import 'package:b2b_contracts/state/widget_sync.dart';
import 'package:b2b_contracts/ui/clients/clients_screen.dart';
import 'package:b2b_contracts/ui/deals/deal_detail_screen.dart';
import 'package:b2b_contracts/ui/deals/deal_editor_screen.dart';
import 'package:b2b_contracts/ui/prices/quote_editor_screen.dart';
import 'package:b2b_contracts/ui/settings/backup_screen.dart';
import 'package:b2b_contracts/ui/settings/settings_screen.dart';
import 'package:b2b_contracts/ui/settings/trash_screen.dart';
import 'package:b2b_contracts/ui/settings/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../test_helpers.dart';

final out = Platform.environment['NT_TUTORIAL'];

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
    final ui.Image img = await layer.toImage(
      Offset.zero & t.view.physicalSize,
      pixelRatio: 1.0,
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Deal sampleDeal(String id, String number, DateTime now, {String? clientId}) =>
    Deal(
      id: id,
      buyerContract: TradeContract(
        side: ContractSide.buyer,
        number: 'S-$number',
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
        number: 'P-$number',
        date: now,
        counterpartyName: 'Qingdao Plastics Co.',
        intermediaryName: 'Nexus Trade LLC',
        productName: 'Полипропилен',
        currency: Currency.usd,
        unitPrice: 1600,
        quantity: 22,
        unit: 'т',
        goodsRatePerUsd: 1,
        logisticsRatePerUsd: 1,
        logisticsMethod: LogisticsMethod.perTransportUnit,
        logisticsRate: 5400,
        transportTypeId: 'truck22',
        transportUnits: 1,
        agencyFeePercent: 8,
        vatEnabled: false,
        vatRefundEnabled: true,
        vatRefundPercent: 9,
        vatBonusShare: 0,
      ),
      clientId: clientId,
      deliveryInfo: 'Циндао → Ташкент, фура 22 т, ориентировочно 25 дней',
      createdAt: now,
      updatedAt: now,
    );

void main() {
  final skip = out == null;
  late LocalStore store;

  setUpAll(() async {
    if (skip) return;
    Directory(out!).createSync(recursive: true);
    await loadFonts();
    await initializeDateFormatting();
    final dir = await Directory.systemTemp.createTemp('tutorial');
    Hive.init(dir.path);
    store = await LocalStore.open(encrypt: false);
    await store.settings.put('languageCode', 'ru');
    await store.settings.put('themeMode', 'light');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
  });

  testWidgets('tutorial screens', (t) async {
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
    await settle(t);
    BuildContext ctx() => t.element(find.byType(Navigator).first);
    Future<void> push(Widget w) async {
      Navigator.of(ctx()).push(MaterialPageRoute(builder: (_) => w));
      await settle(t);
    }

    Future<void> pop() async {
      Navigator.of(ctx()).pop();
      await settle(t);
    }

    Future<void> scrollTo(String text, {double extra = 0}) async {
      final target = find.textContaining(text).first;
      await t.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await t.ensureVisible(target);
      await settle(t);
      if (extra != 0) {
        await t.drag(find.byType(Scrollable).last, Offset(0, -extra));
        await settle(t);
      }
    }

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
    await settle(t);

    // Data for the walkthrough.
    await t.runAsync(() async {
      final deals = ctx().read<DealsController>();
      final clients = ctx().read<ClientsController>();
      final client = await clients.ensure('ООО «Тест Импорт»');
      await clients.upsert(
        client!.copyWith(
          contactPerson: 'Азиз Каримов',
          phone: '+998 90 123 45 67',
          email: 'info@test-import.uz',
          address: 'Ташкент',
        ),
      );
      final now = DateTime.now();
      await deals.upsert(sampleDeal('ctl', '15', now, clientId: client.id));
      await deals.setStage('ctl', ContractStage.prepayment);
      await deals.setStage('ctl', ContractStage.loading);
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
      // A second deal, deleted → in the trash.
      await deals.upsert(sampleDeal('old', '9', now));
      await deals.delete('old');
      // A price calculation with the control values.
      final quotes = ctx().read<QuotesController>();
      await quotes.upsert(
        quotes
            .createDraft(unit: 'кг')
            .copyWith(
              productName: 'Полипропилен',
              buyerName: 'ООО «Тест Импорт»',
              quantity: 22000,
              exwPrice: 1600,
              exwPerThousand: true,
              incoterms: 'FOB',
              logisticsMethod: LogisticsMethod.perTransportUnit,
              logisticsValue: 5400,
              transportTypeId: 'truck22',
              transportUnits: 1,
            ),
      );
      // Profiles.
      final auth = ctx().read<AuthController>();
      final m = await auth.addUser(
        name: 'Менеджер Али',
        role: UserRole.manager,
        pin: '4321',
      );
      await auth.addUser(
        name: 'Клиент Азиз',
        role: UserRole.client,
        pin: '1111',
        clientId: client.id,
      );
      await deals.setAssignees('ctl', [m.id]);
    });
    await settle(t);
    await shot(t, '03_dashboard');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(t);
    await shot(t, '04_dashboard_clients');

    // New deal editor (empty) — kinds.
    await push(const DealEditorScreen());
    await shot(t, '05_new_deal');
    await pop();

    // Editor of the sample deal.
    await push(const DealEditorScreen(dealId: 'ctl'));
    await shot(t, '06_contract1');
    await t.tap(find.text('Контракт №2').first);
    await settle(t);
    await scrollTo('ЛОГИСТИКА', extra: 120);
    await shot(t, '07_logistics');
    await scrollTo('АГЕНТСКИЕ УСЛУГИ', extra: 200);
    await shot(t, '08_agent');
    await t.tap(find.text('Итог').first);
    await settle(t);
    await shot(t, '09_summary');
    await pop();

    // Deal card.
    await push(const DealDetailScreen(dealId: 'ctl'));
    await shot(t, '10_deal');
    await scrollTo('ЭТАПЫ ВЫПОЛНЕНИЯ', extra: 100);
    await shot(t, '11_stages');
    await scrollTo('ОФИЦИАЛЬНЫЙ КОНТРАКТ', extra: 60);
    await shot(t, '12_official');
    await scrollTo('ДОКУМЕНТЫ', extra: 60);
    await shot(t, '13_dossier');
    await t.tap(find.text('Invoice_INV-77.pdf'));
    await settle(t);
    await shot(t, '14_document');
    await pop();
    await pop();

    // Price calculator.
    final q = ctx().read<QuotesController>().quotes.first;
    await push(QuoteEditorScreen(quoteId: q.id));
    await shot(t, '15_calculator');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -1400));
    await settle(t);
    await shot(t, '16_calculator_result');
    await pop();

    // Clients.
    await push(const ClientsScreen());
    await shot(t, '17_clients');
    final c = ctx().read<ClientsController>().clients.first;
    await push(ClientDetailScreen(clientId: c.id));
    await shot(t, '18_client');
    await pop();
    await pop();

    // Users.
    await push(const UsersScreen());
    await shot(t, '19_users');
    await pop();

    // Settings, backups, trash.
    await push(const SettingsScreen());
    await scrollTo('НАПОМИНАНИЯ', extra: 50);
    await shot(t, '20_reminders_widget');
    await pop();
    await push(const BackupScreen());
    await shot(t, '21_backup');
    await pop();
    await push(const TrashScreen());
    await shot(t, '22_trash');
    await pop();

    // Manager view.
    await t.runAsync(() async {
      final auth = ctx().read<AuthController>();
      auth.switchUser();
    });
    await settle(t);
    await shot(t, '23_lock_profiles');
    await t.runAsync(() async {
      final auth = ctx().read<AuthController>();
      await auth.unlockAsUser(
        auth.users.firstWhere((u) => u.role == UserRole.manager).id,
        '4321',
      );
    });
    await settle(t);
    await push(const DealDetailScreen(dealId: 'ctl'));
    await shot(t, '24_manager_deal');
  }, skip: skip);
}
