// Manual tool (skipped in normal runs): records the real NexusTrade UI for
// the promo video — every frame plus where the finger is. Empty fields are
// filled in letter by letter, real taps, real reactions.
//   NT_PROMO=/out/dir NT_LANG=ru|en|zh flutter test test/tools/promo_tool_test.dart
// The compositor is tools/video/make_promo.py.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:b2b_contracts/app.dart';
import 'package:b2b_contracts/core/l10n/app_strings.dart';
import 'package:b2b_contracts/data/models/account.dart';
import 'package:b2b_contracts/data/models/contract_stage.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../test_helpers.dart';

final out = Platform.environment['NT_PROMO'];
final lang = Platform.environment['NT_LANG'] ?? 'ru';
const dpr = 2.625;
const capture = 0.8; // physical px → captured px

/// Demo names per language (test data, not real companies).
const names = {
  'ru': (
    owner: 'Владелец',
    buyer: 'ООО «Тест Импорт»',
    seller: 'Qingdao Plastics Co.',
    product: 'Полипропилен',
    unit: 'кг',
    tonne: 'т',
    doc: 'Договор_DOG-2026-16.pdf',
  ),
  'en': (
    owner: 'Owner',
    buyer: 'Test Import LLC',
    seller: 'Qingdao Plastics Co.',
    product: 'Polypropylene',
    unit: 'kg',
    tonne: 't',
    doc: 'Contract_DOG-2026-16.pdf',
  ),
  'zh': (
    owner: '所有者',
    buyer: '测试进口有限公司',
    seller: '青岛塑料有限公司',
    product: '聚丙烯',
    unit: 'kg',
    tonne: 't',
    doc: '合同_DOG-2026-16.pdf',
  ),
};

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

  // Tests have no system fonts: for Chinese, Noto Sans SC (shipped with
  // the app for PDFs) stands in for the phone's system CJK font.
  await family(
    'Roboto',
    lang == 'zh'
        ? ['assets/fonts/NotoSansSC-Regular.ttf']
        : ['assets/fonts/Roboto-Regular.ttf', 'assets/fonts/Roboto-Bold.ttf'],
  );
  await family('MaterialIcons', [
    '/opt/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

bool _isVertical(Widget w) =>
    w is Scrollable && w.axisDirection == AxisDirection.down;

class Recorder {
  Recorder(this.t);
  final WidgetTester t;
  final frames = <Map<String, Object?>>[];
  var n = 0;

  void mark(String scene) => frames.add({'kind': 'mark', 'scene': scene});

  Future<void> frame({
    Offset? finger,
    bool press = false,
    double hold = 0.5,
    String kind = 'tap',
  }) async {
    final name = 'f${(n++).toString().padLeft(4, '0')}.png';
    await t.runAsync(() async {
      final layer = t.binding.renderViews.first.debugLayer! as OffsetLayer;
      final ui.Image img = await layer.toImage(
        Offset.zero & t.view.physicalSize,
        pixelRatio: capture,
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    frames.add({
      'img': name,
      'x': finger == null ? null : finger.dx * dpr * capture,
      'y': finger == null ? null : finger.dy * dpr * capture,
      'press': press,
      'hold': hold,
      'kind': kind,
    });
  }

  Future<void> settle() => t.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );

  Finder get _list => find.byWidgetPredicate(_isVertical).last;

  /// Brings [f] towards the middle of the screen with a recorded swipe.
  Future<void> reveal(Finder f) async {
    final h = t.view.physicalSize.height / dpr;
    // Off-screen items are not built yet: swipe until they exist.
    var guard = 0;
    while (f.evaluate().isEmpty && guard++ < 12) {
      await scroll(h * 0.45, steps: 8);
    }
    final inList = find
        .ancestor(of: f, matching: find.byWidgetPredicate(_isVertical))
        .evaluate()
        .isNotEmpty;
    if (!inList) return;
    final y = t.getCenter(f).dy;
    if (y > h * 0.78 || y < h * 0.16) {
      await scroll(y - h * 0.45, steps: 10);
    }
  }

  Future<void> tap(Finder f, {double after = 0.6, bool reveal = true}) async {
    if (reveal) await this.reveal(f);
    final c = t.getCenter(f);
    await frame(finger: c, hold: 0.35, kind: 'approach');
    final g = await t.startGesture(c);
    await t.pump(const Duration(milliseconds: 90));
    await frame(finger: c, press: true, hold: 0.12, kind: 'down');
    await t.pump(const Duration(milliseconds: 90));
    await frame(finger: c, press: true, hold: 0.12, kind: 'down');
    await g.up();
    await t.pump(const Duration(milliseconds: 120));
    await frame(finger: c, hold: 0.15, kind: 'up');
    await settle();
    await frame(finger: c, hold: after, kind: 'rest');
  }

  /// Types [text] character by character into the empty field [f].
  Future<void> type(Finder f, String text, {double after = 0.4}) async {
    await reveal(f);
    final c = t.getCenter(f);
    await tap(f, after: 0.2, reveal: false);
    for (var i = 1; i <= text.length; i++) {
      await t.enterText(f, text.substring(0, i));
      await t.pump(const Duration(milliseconds: 60));
      await frame(finger: c, hold: 0.09, kind: 'typing');
    }
    await settle();
    await frame(finger: c, hold: after, kind: 'rest');
  }

  Future<void> scroll(double dy, {int steps = 8}) async {
    final start = t.getCenter(_list) + const Offset(90, 120);
    final g = await t.startGesture(start);
    for (var i = 1; i <= steps; i++) {
      await g.moveBy(Offset(0, -dy / steps));
      await t.pump(const Duration(milliseconds: 16));
      await frame(
        finger: start + Offset(0, -dy * i / steps),
        press: true,
        hold: 0.06,
        kind: 'swipe',
      );
    }
    await g.up();
    await settle();
    await frame(hold: 0.4, kind: 'rest');
  }
}

/// An earlier deal so the month analytics are not empty.
Deal earlierDeal(DateTime now, String buyer, String product, String unit,
        String tonne) =>
    Deal(
      id: 'early',
      buyerContract: TradeContract(
        side: ContractSide.buyer,
        number: 'S-15',
        date: now,
        counterpartyName: buyer,
        intermediaryName: 'Nexus Trade LLC',
        productName: product,
        currency: Currency.usd,
        unitPrice: 2.30,
        quantity: 22000,
        unit: unit,
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
        productName: product,
        currency: Currency.usd,
        unitPrice: 1600,
        quantity: 22,
        unit: tonne,
        goodsRatePerUsd: 1,
        freightCost: 5400,
        logisticsRatePerUsd: 1,
        agencyFeePercent: 8,
        vatEnabled: false,
      ),
      createdAt: now,
      updatedAt: now,
    );

void main() {
  final skip = out == null;
  late LocalStore store;
  final nm = names[lang]!;

  setUpAll(() async {
    if (skip) return;
    Directory(out!).createSync(recursive: true);
    await loadFonts();
    await initializeDateFormatting();
    final dir = await Directory.systemTemp.createTemp('promo');
    Hive.init(dir.path);
    store = await LocalStore.open(encrypt: false);
    await store.settings.put('languageCode', lang == 'zh' ? 'zh-Hans' : lang);
    await store.settings.put('themeMode', 'dark');
    await store.settings.put('defaultUnit', nm.unit);
    // Documents are stored under the app support folder.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
  });

  testWidgets('promo walkthrough', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = dpr;
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
    final r = Recorder(t);
    await r.settle();
    BuildContext ctx() => t.element(find.byType(Navigator).first);
    await t.runAsync(() async {
      final auth = ctx().read<AuthController>();
      await auth.register(
        type: LoginType.email,
        login: 'owner@nexustrade.uz',
        password: 'Test2026x',
        displayName: nm.owner,
      );
      auth.skipQuickSetup();
      final deals = ctx().read<DealsController>();
      final now = DateTime.now();
      await deals.upsert(
        earlierDeal(now, nm.buyer, nm.product, nm.unit, nm.tonne),
      );
      await deals.setStage('early', ContractStage.closed);
    });
    await r.settle();
    final s = AppStrings.of(ctx());
    Finder field(String label) => find
        .ancestor(of: find.text(label), matching: find.byType(TextField))
        .first;

    // 1. Home: month analytics.
    r.mark('dashboard');
    await r.frame(hold: 1.6, kind: 'rest');
    await r.scroll(420);
    await r.frame(hold: 1.0, kind: 'rest');
    await r.scroll(-420);

    // 2. New deal: Contract 1, empty fields filled in.
    r.mark('new_deal');
    await r.tap(find.text(s.newDeal).first, after: 0.8, reveal: false);
    await r.tap(find.text(s.kindBackToBack).first, after: 0.4, reveal: false);
    await r.type(field('${s.contractNumber} *'), 'S-16');
    await r.type(field(s.counterpartyLabel(ContractSide.buyer)), nm.buyer);
    r.mark('price');
    await r.tap(find.text(s.pricingManual).first, after: 0.4);
    await r.type(field(s.productName), nm.product);
    await r.type(field(s.unitPrice), '2.30');
    await r.type(field(s.quantity), '22000');

    // 3. Contract 2: factory price and the truck.
    r.mark('contract2');
    await r.tap(
      find.text(s.contractTitle(ContractSide.seller)).first,
      after: 0.6,
      reveal: false,
    );
    await r.type(field('${s.contractNumber} *'), 'P-16');
    await r.type(field(s.counterpartyLabel(ContractSide.seller)), nm.seller);
    await r.type(field(s.factoryUnitPrice), '1600');
    // The factory contract opens in CNY: this deal is priced in USD.
    await r.tap(
      find.byType(DropdownButtonFormField<Currency>).first,
      after: 0.4,
    );
    await r.tap(find.text('USD  \$').last, after: 0.5, reveal: false);
    await r.type(field(s.quantity), '22');
    await r.type(field(s.unitLabel), nm.tonne);
    r.mark('logistics');
    await r.tap(find.text(s.logisticsPerTransport).first, after: 0.5);
    await r.tap(
      find.byType(DropdownButtonFormField<String>).last,
      after: 0.4,
    );
    await r.tap(find.textContaining('22').last, after: 0.6, reveal: false);
    await r.type(field(s.ratePerTransportUnit), '5400');

    // 4. Summary: profit appears.
    r.mark('summary');
    await r.tap(find.text(s.summary).first, after: 1.8, reveal: false);
    await r.scroll(500);
    await r.frame(hold: 1.6, kind: 'rest');
    await r.scroll(-500);
    r.mark('saved');
    await r.tap(find.text(s.save).first, after: 0.2, reveal: false);
    // Saving writes to the encrypted store for real: let it finish.
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await r.settle();
    }
    await r.frame(hold: 2.4, kind: 'rest');

    // 5. Deal card: stages.
    r.mark('stages');
    final id = t
        .element(find.byType(Navigator).first)
        .read<DealsController>()
        .deals
        .firstWhere((d) => d.id != 'early')
        .id;
    Navigator.of(ctx()).push(
      MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: id)),
    );
    await r.settle();
    ScaffoldMessenger.of(ctx()).hideCurrentSnackBar();
    await r.settle();
    await r.frame(hold: 1.2, kind: 'rest');
    await r.tap(
      find.textContaining(s.moveToNextStage).first,
      after: 1.0,
    );
    await r.tap(
      find.textContaining(s.moveToNextStage).first,
      after: 1.0,
      reveal: false,
    );

    // 6. Official contract: attached.
    r.mark('documents');
    await r.reveal(find.text(s.officialContract.toUpperCase()));
    await r.frame(hold: 1.0, kind: 'rest');
    // Finger presses "Add" (no real tap: the system file picker would open).
    final add = t.getCenter(find.text(s.addAction).first);
    await r.frame(finger: add, hold: 0.35, kind: 'approach');
    await r.frame(finger: add, press: true, hold: 0.24, kind: 'down');
    await r.frame(finger: add, hold: 0.4, kind: 'up');
    // The phone's own file picker is not part of NexusTrade: the chosen
    // file is added the way the app does it after the picker closes.
    // Started outside runAsync and driven by pumping: the controller may
    // wait for a frame while it saves.
    var done = false;
    ctx()
        .read<DealsController>()
        .addDocument(
          id,
          category: DocCategory.mainContract,
          fileName: nm.doc,
          bytes: List.filled(250000, 1),
          number: 'DOG-2026/16',
          date: DateTime.now(),
        )
        .then((_) => done = true);
    for (var i = 0; i < 60 && !done; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    await r.settle();
    await r.frame(hold: 2.0, kind: 'attached');

    // 7. Back home: the month grew.
    r.mark('dashboard_end');
    Navigator.of(ctx()).pop();
    await r.settle();
    await r.frame(hold: 2.0, kind: 'rest');

    File('$out/timeline.json').writeAsStringSync(jsonEncode(r.frames));
    // ignore: avoid_print
    print('FRAMES ${r.frames.length}');
  }, skip: skip);
}
