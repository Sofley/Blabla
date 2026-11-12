// Manual tool (skipped in normal runs): drives the real price calculator in
// dark mode and records every frame plus where the finger is, for the
// "walkthrough" animation (tools/video/make_walkthrough.py).
//   NT_WALK=/out/dir flutter test test/tools/walkthrough_tool_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:b2b_contracts/app.dart';
import 'package:b2b_contracts/data/models/account.dart';
import 'package:b2b_contracts/data/storage/local_store.dart';
import 'package:b2b_contracts/export/backup_service.dart';
import 'package:b2b_contracts/state/auth_controller.dart';
import 'package:b2b_contracts/state/backup_controller.dart';
import 'package:b2b_contracts/state/reminders_controller.dart';
import 'package:b2b_contracts/state/widget_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../test_helpers.dart';

final out = Platform.environment['NT_WALK'];
const dpr = 2.625;
const capture = 0.8; // physical px → captured px

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

class Recorder {
  Recorder(this.t);
  final WidgetTester t;
  final frames = <Map<String, Object?>>[];
  var n = 0;

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

  /// Brings [f] into the middle of the screen with a recorded swipe when
  /// it is near or beyond the edges.
  Future<void> reveal(Finder f) async {
    final inList = find
        .ancestor(
          of: f,
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        )
        .evaluate()
        .isNotEmpty;
    if (!inList) return;
    final h = t.view.physicalSize.height / dpr;
    final y = t.getCenter(f).dy;
    if (y > h * 0.80 || y < h * 0.14) {
      await scroll(y - h * 0.45, steps: 10);
    }
  }

  /// Finger moves to [f], presses (ink ripple visible), releases.
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

  /// Types [text] character by character into the field [f].
  Future<void> type(Finder f, String text) async {
    await reveal(f);
    final c = t.getCenter(f);
    await tap(f, after: 0.25, reveal: false);
    for (var i = 1; i <= text.length; i++) {
      await t.enterText(f, text.substring(0, i));
      await t.pump(const Duration(milliseconds: 60));
      await frame(finger: c, hold: 0.13, kind: 'typing');
    }
    await settle();
    await frame(finger: c, hold: 0.5, kind: 'rest');
  }

  /// Swipe up by [dy] logical px in smooth steps.
  Future<void> scroll(double dy, {int steps = 8}) async {
    final area = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first;
    final start = t.getCenter(area) + const Offset(90, 180);
    final g = await t.startGesture(start);
    for (var i = 1; i <= steps; i++) {
      await g.moveBy(Offset(0, -dy / steps));
      await t.pump(const Duration(milliseconds: 16));
      await frame(
        finger: start + Offset(0, -dy * i / steps),
        press: true,
        hold: 0.07,
        kind: 'swipe',
      );
    }
    await g.up();
    await settle();
    await frame(hold: 0.5, kind: 'rest');
  }
}

void main() {
  final skip = out == null;
  late LocalStore store;

  setUpAll(() async {
    if (skip) return;
    Directory(out!).createSync(recursive: true);
    await loadFonts();
    await initializeDateFormatting();
    final dir = await Directory.systemTemp.createTemp('walk');
    Hive.init(dir.path);
    store = await LocalStore.open(encrypt: false);
    await store.settings.put('languageCode', 'ru');
    await store.settings.put('themeMode', 'dark');
    await store.settings.put('defaultUnit', 'кг');
  });

  testWidgets('calculator walkthrough', (t) async {
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
    await t.runAsync(() async {
      final auth = t
          .element(find.byType(Navigator).first)
          .read<AuthController>();
      await auth.register(
        type: LoginType.email,
        login: 'owner@nexustrade.uz',
        password: 'Test2026x',
      );
      auth.skipQuickSetup();
    });
    await r.settle();
    await r.frame(hold: 1.2, kind: 'rest');

    // Price tab → new calculation.
    await r.tap(find.text('Цена').last);
    await r.tap(find.text('Новый расчёт'), after: 0.8);

    Finder field(String label) => find.widgetWithText(TextField, label).first;
    Finder fieldContaining(String label) => find
        .ancestor(
          of: find.textContaining(label),
          matching: find.byType(TextField),
        )
        .first;

    await r.type(field('Наименование товара'), 'Полипропилен');
    await r.tap(find.text('За т').first);
    await r.type(fieldContaining('Цена товара'), '1600');
    await r.type(field('Количество / объём'), '22000');
    await r.tap(find.text('За фуру / контейнер').first, after: 0.5);
    // Transport type: open the list and pick the 22 t truck.
    await r.tap(find.byType(DropdownButtonFormField<String>).last, after: 0.4);
    await r.tap(find.textContaining('Фура 22').last, after: 0.6, reveal: false);
    await r.type(fieldContaining('Ставка за фуру'), '5400');
    await r.scroll(700);
    await r.scroll(700);
    // Back to the top: the selling price card, then "Save".
    await t.drag(
      find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
      const Offset(0, 6000),
    );
    await r.settle();
    await r.frame(hold: 1.2, kind: 'rest');
    await r.tap(find.text('Сохранить').first, after: 2.2, reveal: false);

    File('$out/timeline.json').writeAsStringSync(jsonEncode(r.frames));
    // ignore: avoid_print
    print('FRAMES ${r.frames.length}');
  }, skip: skip);
}
