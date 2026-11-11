import 'dart:convert';
import 'dart:io';

import 'package:b2b_contracts/core/theme/app_theme.dart';
import 'package:b2b_contracts/data/models/chat_message.dart';
import 'package:b2b_contracts/data/models/contract_stage.dart';
import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/logistics_route.dart';
import 'package:b2b_contracts/data/repositories/deal_repository.dart';
import 'package:b2b_contracts/data/services/cbu_rates_api.dart';
import 'package:b2b_contracts/export/backup_service.dart';
import 'package:b2b_contracts/state/chat_controller.dart';
import 'package:b2b_contracts/state/deals_controller.dart';
import 'package:b2b_contracts/state/rates_controller.dart';
import 'package:b2b_contracts/state/routes_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Shape of https://cbu.uz/ru/arkhiv-kursov-valyut/json/ (numbers as strings).
const cbuFixture = '''
[
 {"id":69,"Code":"840","Ccy":"USD","CcyNm_RU":"Доллар США","Nominal":"1","Rate":"12850.00","Diff":"-12.50","Date":"10.11.2026"},
 {"id":21,"Code":"978","Ccy":"EUR","CcyNm_RU":"Евро","Nominal":"1","Rate":"13878.00","Diff":"20.10","Date":"10.11.2026"},
 {"id":16,"Code":"156","Ccy":"CNY","CcyNm_RU":"Юань ренминби","Nominal":"1","Rate":"1785.00","Diff":"0","Date":"10.11.2026"},
 {"id":57,"Code":"643","Ccy":"RUB","CcyNm_RU":"Российский рубль","Nominal":"1","Rate":"158.40","Diff":"1.2","Date":"10.11.2026"},
 {"id":40,"Code":"392","Ccy":"JPY","CcyNm_RU":"Японская иена","Nominal":"10","Rate":"850.00","Diff":"0","Date":"10.11.2026"}
]
''';

void main() {
  late Directory dir;
  late Box settings;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nexus');
    Hive.init(dir.path);
    settings = await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('CBU rates', () {
    test('parses cbu.uz JSON', () {
      final r = CbuRatesApi.parse(cbuFixture);
      expect(r.length, 5);
      expect(r.first.code, 'USD');
      expect(r.first.rate, 12850);
      expect(r.first.diff, -12.5);
      expect(r.first.date, DateTime(2026, 11, 10));
      expect(r.last.perUnit, 85); // JPY nominal 10
    });

    test('fetch, cache, cross rates and PBOC override', () async {
      final api = CbuRatesApi(
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(cbuFixture), 200),
        ),
      );
      final rates = RatesController(settings, api: api);
      expect(await rates.refreshCbu(), isTrue);
      expect(rates.cbu.map((r) => r.code).take(3), ['USD', 'EUR', 'CNY']);

      // 1 USD = 12850 / 1785 CNY
      expect(rates.cbuCrossToCny('USD'), closeTo(12850 / 1785, 1e-9));
      expect(rates.ratePerUsd(Currency.cny), closeTo(12850 / 1785, 1e-9));
      expect(rates.ratePerUsd(Currency.eur), closeTo(12850 / 13878, 1e-9));
      expect(rates.ratePerUsd(Currency.uzs), 12850);

      await rates.setPboc('USD', 7.1);
      expect(rates.ratePerUsd(Currency.cny), 7.1);

      // Cached: a new controller reads the same data offline.
      final offline = RatesController(
        settings,
        api: CbuRatesApi(
          client: MockClient((_) async => http.Response('', 500)),
        ),
      );
      expect(offline.cbu.length, 5);
      expect(offline.pboc['USD']!.perUnit, 7.1);
      expect(await offline.refreshCbu(), isFalse);
      expect(offline.error, isNotNull);
      expect(offline.cbu.length, 5);
    });
  });

  test('tariff grid is seeded once with editable examples', () async {
    final box = await Hive.openBox<Map>('routes');
    final routes = RoutesController(box, flags: settings);
    expect(routes.routes.length, 2);
    final rail = routes.routes.firstWhere((r) => r.mode == TransportMode.rail);
    expect(rail.priceAvg, 5850);

    await routes.delete(rail.id);
    // Second launch does not re-seed deleted examples.
    expect(RoutesController(box, flags: settings).routes.length, 1);
  });

  test('status changes are posted to the deal chat', () async {
    final chat = ChatController(await Hive.openBox<Map>('chat'));
    final deals = DealsController(
      DealRepository(await Hive.openBox<Map>('deals')),
      onEvent: (id, code) => code == 'deleted'
          ? chat.deleteDealChat(id)
          : chat.post(id, ChatAuthor.system, code),
    );
    final d = deals.createDraft(companyName: 'X', agencyFee: 9, vat: 9);
    await deals.upsert(d);
    await deals.setStage(d.id, ContractStage.prepayment);
    await chat.post(d.id, ChatAuthor.buyer, '30% предоплата ўтказилди');
    expect(chat.messages(d.id).map((m) => m.text), [
      'created',
      'stage:prepayment',
      '30% предоплата ўтказилди',
    ]);
    await deals.delete(d.id);
    expect(chat.messages(d.id), isEmpty);
  });

  test('backup v3 keeps routes and chat', () {
    const svc = BackupService();
    final now = DateTime(2026, 11, 11);
    final bytes = svc.encode(
      deals: const [],
      quotes: const [],
      settings: {'pbocRates': []},
      routes: [
        LogisticsRoute(
          id: 'r',
          origin: 'Сиань',
          destination: 'Ташкент',
          updatedAt: now,
        ),
      ],
      chat: [
        ChatMessage(
          id: 'm',
          dealId: 'd',
          author: ChatAuthor.seller,
          text: 'OK',
          createdAt: now,
        ),
      ],
    );
    final c = svc.decode(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
    expect(c.hasRoutes, isTrue);
    expect(c.routes.single.destination, 'Ташкент');
    expect(c.chat.single.author, ChatAuthor.seller);
    // A v2 backup has no routes: keep the current grid.
    expect(svc.decode({'format': BackupService.format}).hasRoutes, isFalse);
  });

  test('themes: AMOLED is true black, every accent builds', () {
    for (final a in AccentColor.values) {
      final dark = AppTheme.dark(accent: a);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(dark.colorScheme.primary, a.dark);
      expect(AppTheme.light(accent: a).colorScheme.primary, a.light);
      // With a wallpaper the pages become transparent.
      expect(
        AppTheme.light(accent: a, glass: true).scaffoldBackgroundColor,
        Colors.transparent,
      );
    }
  });
}
