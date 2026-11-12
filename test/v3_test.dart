import 'dart:convert';
import 'dart:io';

import 'package:b2b_contracts/core/l10n/app_strings.dart';
import 'package:b2b_contracts/core/l10n/tr_sr.dart';
import 'package:b2b_contracts/core/l10n/tr_uz.dart';
import 'package:b2b_contracts/core/l10n/tr_v3.dart';
import 'package:b2b_contracts/core/l10n/tr_zh.dart';
import 'package:b2b_contracts/core/utils/formatters.dart';
import 'package:b2b_contracts/data/models/app_user.dart';
import 'package:b2b_contracts/data/models/contract_stage.dart';
import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/deal.dart';
import 'package:b2b_contracts/data/models/price_quote.dart';
import 'package:b2b_contracts/data/models/trade_contract.dart';
import 'package:b2b_contracts/data/models/transport_type.dart';
import 'package:b2b_contracts/data/repositories/auth_repository.dart';
import 'package:b2b_contracts/data/repositories/deal_repository.dart';
import 'package:b2b_contracts/data/repositories/quote_repository.dart';
import 'package:b2b_contracts/data/repositories/settings_repository.dart';
import 'package:b2b_contracts/data/storage/attachment_store.dart';
import 'package:b2b_contracts/data/storage/data_migration.dart';
import 'package:b2b_contracts/data/storage/local_store.dart';
import 'package:b2b_contracts/domain/access_policy.dart';
import 'package:b2b_contracts/domain/analytics_service.dart';
import 'package:b2b_contracts/domain/finance_calculator.dart';
import 'package:b2b_contracts/domain/price_calculator.dart';
import 'package:b2b_contracts/export/backup_service.dart';
import 'package:b2b_contracts/export/report_builders.dart';
import 'package:b2b_contracts/state/auth_controller.dart';
import 'package:b2b_contracts/state/backup_controller.dart';
import 'package:b2b_contracts/state/chat_controller.dart';
import 'package:b2b_contracts/state/clients_controller.dart';
import 'package:b2b_contracts/state/deals_controller.dart';
import 'package:b2b_contracts/state/quotes_controller.dart';
import 'package:b2b_contracts/state/rates_controller.dart';
import 'package:b2b_contracts/state/reminders_controller.dart';
import 'package:b2b_contracts/state/routes_controller.dart';
import 'package:b2b_contracts/state/settings_controller.dart';
import 'package:b2b_contracts/state/widget_sync.dart';
import 'package:b2b_contracts/ui/deals/deals_list_screen.dart';
import 'package:b2b_contracts/ui/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'test_helpers.dart';

/// The approved control example: FOB 1 600 USD/t, 22 t truck, logistics
/// 5 400 USD per truck, agent 8 % of the goods cost, agent VAT OFF.
Deal controlDeal({double price = 2.30, double? agentVat}) {
  final now = DateTime(2026, 11, 5);
  return Deal(
    id: 'ctl',
    buyerContract: TradeContract(
      side: ContractSide.buyer,
      number: 'S-1',
      date: now,
      counterpartyName: 'Buyer LLC',
      intermediaryName: 'Nexus',
      productName: 'Polypropylene',
      currency: Currency.usd,
      unitPrice: price,
      quantity: 22000,
      unit: 'kg',
      goodsRatePerUsd: 1,
      agencyFeePercent: 0,
      vatEnabled: false,
    ),
    sellerContract: TradeContract(
      side: ContractSide.seller,
      number: 'P-1',
      date: now,
      counterpartyName: 'Qingdao Factory',
      intermediaryName: 'Nexus',
      currency: Currency.usd,
      unitPrice: 1600,
      quantity: 22,
      unit: 't',
      goodsRatePerUsd: 1,
      freightCost: 5400,
      logisticsRatePerUsd: 1,
      agencyFeePercent: 8,
      agencyBase: AgencyBase.goods,
      agentVatEnabled: agentVat != null,
      agentVatPercent: agentVat,
      vatEnabled: false,
      vatRefundEnabled: true,
      vatRefundPercent: 9,
      vatBonusShare: 0,
      vatBonusInProfit: false,
    ),
    clientId: 'c1',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('v3');
    Hive.init(dir.path);
    await initializeDateFormatting();
  });

  group('Formulas on the control values', () {
    test(
      'agent 8 % of goods cost; price 2.30 → profit 7 184 USD (0.3265 USD/kg)',
      () {
        final p = DealProfit.of(controlDeal());
        expect(p.purchase.goodsUsd, closeTo(35200, 1e-6)); // FOB 1 600 × 22
        expect(p.purchase.logisticsUsd, closeTo(5400, 1e-6));
        // 8 % of the goods cost only (EXW or FOB), not of logistics.
        expect(p.purchase.agencyFeeUsd, closeTo(2816, 1e-6));
        expect(p.expensesUsd, closeTo(43416, 1e-6));
        expect(p.revenueExVatUsd, closeTo(50600, 1e-6)); // 2.30 × 22 000
        expect(p.netProfitUsd, closeTo(7184, 1e-6));
        expect(p.netProfitUsd / 22000, closeTo(0.326545, 1e-6));
        // Agent VAT is OFF: nothing added, no "not set" warning.
        expect(p.agentVatUnset, isFalse);
        expect(p.purchase.agentVatUsd, 0);
        expect(p.logisticsUnset, isFalse);
      },
    );

    test('profit 0.33 USD/kg (manual) → price 2.303455 USD/kg', () {
      final d = controlDeal().copyWith(
        pricingMode: PricingMode.profitPerUnit,
        marginValue: 0.33,
      );
      final price = computedBuyerUnitPrice(d)!;
      expect(price, closeTo(2.3034545, 1e-6));
      final withPrice = d.copyWith(
        buyerContract: d.buyerContract.copyWith(unitPrice: price),
      );
      expect(DealProfit.of(withPrice).netProfitUsd, closeTo(7260, 1e-6));
    });

    test('price and profit stay independent: a manual price is kept', () {
      final d = controlDeal(price: 2.30);
      expect(d.pricingMode, PricingMode.manual);
      expect(computedBuyerUnitPrice(d), isNull);
    });

    test('agent VAT ON is part of the cost; ON without a rate = not set', () {
      final p = DealProfit.of(controlDeal(agentVat: 12));
      expect(p.purchase.agentVatUsd, closeTo(337.92, 1e-6));
      expect(p.netProfitUsd, closeTo(7184 - 337.92, 1e-6));
      expect(p.agentVatUnset, isFalse);
      final on = controlDeal().copyWith(
        sellerContract: controlDeal().sellerContract.copyWith(
          agentVatEnabled: true,
        ),
      );
      expect(DealProfit.of(on).agentVatUnset, isTrue);
      expect(DealProfit.of(on).netProfitUsd, closeTo(7184, 1e-6));
    });

    test('agent fee OFF, or a fixed sum', () {
      final c = controlDeal().sellerContract;
      final off = controlDeal().copyWith(
        sellerContract: c.copyWith(agencyEnabled: false),
      );
      expect(DealProfit.of(off).purchase.agencyFeeUsd, 0);
      expect(DealProfit.of(off).netProfitUsd, closeTo(10000, 1e-6));
      final fixed = controlDeal().copyWith(
        sellerContract: c.copyWith(
          agencyMode: AgencyMode.fixed,
          agencyFixedUsd: 1500,
        ),
      );
      expect(DealProfit.of(fixed).purchase.agencyFeeUsd, 1500);
      final unset = controlDeal().copyWith(
        sellerContract: c.copyWith(agencyMode: AgencyMode.fixed),
      );
      expect(DealProfit.of(unset).agencyUnset, isTrue);
    });

    test('logistics per tonne and per truck / container', () {
      final c = controlDeal().sellerContract.copyWith(freightCost: null);
      final perTonne = c.copyWith(
        logisticsMethod: LogisticsMethod.perTonne,
        logisticsRate: 245.4545,
      );
      expect(perTonne.tonnes, 22);
      expect(perTonne.logisticsTotal, closeTo(5400, 0.01));
      final perTruck = c.copyWith(
        logisticsMethod: LogisticsMethod.perTransportUnit,
        logisticsRate: 5400,
        transportUnits: 1,
      );
      expect(perTruck.logisticsTotal, 5400);
      expect(TradeContract.fromJson(perTruck.toJson()).logisticsTotal, 5400);
      // No units entered → "not set", not zero.
      expect(perTruck.copyWith(transportUnits: null).logisticsEntered, isFalse);
      // Auto count from the directory: 22 t truck, 50 t → 3 trucks.
      final truck22 = TransportType.defaults.firstWhere(
        (t) => t.id == 'truck22',
      );
      expect(truck22.unitsFor(22), 1);
      expect(truck22.unitsFor(50), 3);
      // Containers have no capacity until the user sets one.
      expect(TransportType.defaults.first.unitsFor(22), isNull);
    });

    test('VAT refund 9 % of FOB, share 0 % → not in profit', () {
      final p = DealProfit.of(controlDeal());
      expect(p.vatRefundUsd, closeTo(3168, 1e-6));
      expect(p.vatBonusUsd, 0);
      expect(p.netProfitUsd, closeTo(7184, 1e-6));
    });

    test('FX difference at closing is information only', () {
      final d = controlDeal();
      final cny = d.copyWith(
        sellerContract: d.sellerContract.copyWith(
          currency: Currency.cny,
          unitPrice: 11520, // 1 600 USD × 7.2
          goodsRatePerUsd: 7.2,
          closingRatePerUsd: 7.0,
        ),
      );
      final p = DealProfit.of(cny);
      expect(p.netProfitUsd, closeTo(7184, 1e-6)); // unchanged
      // 253 440 CNY: 36 205.71 at 7.0 vs 35 200 at 7.2 → we paid more.
      expect(p.fxDifferenceUsd, closeTo(-1005.714, 1e-3));
    });

    test('price calculator gives the same numbers', () {
      final now = DateTime(2026, 11, 5);
      final q = PriceQuote(
        id: 'q',
        quantity: 22000,
        unit: 'kg',
        exwPrice: 1600,
        exwPerThousand: true,
        logisticsValue: 5400,
        logisticsIsTotal: true,
        agentPercent: 8,
        profitMode: ProfitMode.amount,
        profitValue: 0.33,
        createdAt: now,
        updatedAt: now,
      );
      final b = PriceBreakdown(q);
      expect(b.agentTotal, closeTo(2816, 1e-6));
      expect(b.salePricePerUnit, closeTo(2.3034545, 1e-6));
      final at230 = PriceBreakdown(
        q.copyWith(profitMode: ProfitMode.salePrice, profitValue: 2.30),
      );
      expect(at230.totalProfit, closeTo(7184, 1e-6));
      expect(b.agentVatUnset, isFalse);
      final perTruck = PriceBreakdown(
        q.copyWith(
          logisticsMethod: LogisticsMethod.perTransportUnit,
          logisticsValue: 5400,
          transportUnits: 1,
        ),
      );
      expect(perTruck.logisticsTotal, 5400);
      final off = PriceBreakdown(q.copyWith(agentEnabled: false));
      expect(off.agentTotal, 0);
    });

    test('empty logistics is not zero; a confirmed zero is', () {
      final empty = controlDeal().sellerContract.copyWith(freightCost: null);
      expect(empty.logisticsEntered, isFalse);
      expect(ContractFinancials.of(empty).logisticsUnset, isTrue);
      final zero = empty.copyWith(freightCost: 0);
      expect(zero.logisticsEntered, isTrue);
      final back = TradeContract.fromJson(zero.toJson());
      expect(back.freightCost, 0); // stays a confirmed zero after saving
      expect(TradeContract.fromJson(empty.toJson()).freightCost, isNull);
    });

    test('reports print "not set", skip empty fields, print confirmed 0', () {
      final b = ReportBuilders(AppStrings(const Locale('en')), Fmt('en'));
      String text(Deal d) {
        final out = StringBuffer();
        for (final block in b.deal(d).blocks) {
          try {
            for (final (label, cell) in (block as dynamic).rows) {
              out.write('$label=${cell.text};');
            }
          } catch (_) {}
        }
        return out.toString();
      }

      final t = text(controlDeal());
      expect(t, contains('VAT on agent services=No'));
      expect(t, isNot(contains('Port fees')));
      final zeroPort = controlDeal().copyWith(
        sellerContract: controlDeal().sellerContract.copyWith(portFees: 0),
      );
      expect(text(zeroPort), contains('Port fees=0'));
    });
  });

  group('Migration v2.1 → v3.0', () {
    Map<String, dynamic> v21Deal() {
      final j = controlDeal().toJson();
      j.remove('schema');
      j.remove('stageHistory');
      j.remove('clientId');
      for (final side in ['buyerContract', 'sellerContract']) {
        final c = Map<String, dynamic>.from(j[side] as Map);
        c.remove('schema');
        c.remove('agencyBase');
        c.remove('agentVatPercent');
        c['transportCost'] = 0;
        c['portFees'] = 0;
        j[side] = c;
      }
      j['stage'] = 'inTransit';
      j['stageDates'] = {
        'signed': '2026-10-01T00:00:00.000',
        'prepayment': '2026-10-05T00:00:00.000',
        'factoryPaymentCny': '2026-10-10T00:00:00.000',
        'inTransit': '2026-10-20T00:00:00.000',
      };
      return j;
    }

    test('old record reads correctly and keeps its old calculation', () {
      final d = Deal.fromJson(v21Deal());
      // Old zeros of optional amounts become "not entered".
      expect(d.sellerContract.transportCost, isNull);
      expect(d.sellerContract.portFees, isNull);
      expect(d.sellerContract.freightCost, 5400); // real value kept
      // Old deals keep the agent fee on goods only: 8 % × 35 200.
      expect(d.sellerContract.agencyBase, AgencyBase.goods);
      expect(DealProfit.of(d).purchase.agencyFeeUsd, closeTo(2816, 1e-6));
      // Stages mapped, history keeps the old names.
      expect(d.stage, ContractStage.loading);
      expect(d.stageDates[ContractStage.prepayment], DateTime(2026, 10, 5));
      expect(d.stageHistory.length, 4);
      expect(d.stageHistory.map((e) => e.legacyName), [
        null,
        null,
        'factoryPaymentCny',
        'inTransit',
      ]);
    });

    test(
      'store migration: snapshot, clients, example tariffs removed',
      () async {
        final store = await LocalStore.open(encrypt: false);
        await store.wipe();
        await store.auth.put('account', {'login': 'x'});
        await store.deals.put('ctl', v21Deal());
        await store.routes.put('ex', {
          'id': 'ex',
          'origin': 'Сиань',
          'destination': 'Ташкент',
          'priceMin': 5600,
          'priceMax': 6100,
          'notes': 'Пример: обновите по актуальной ставке',
          'updatedAt': '2026-01-01T00:00:00.000',
        });
        await store.routes.put('mine', {
          'id': 'mine',
          'origin': 'Qingdao',
          'destination': 'Tashkent',
          'priceMin': 5400,
          'priceMax': 5400,
          'updatedAt': '2026-01-01T00:00:00.000',
        });
        await store.settings.put('defaultAgencyFee', 9);
        await store.settings.put('observerMode', true);

        expect(await DataMigration.run(store), isTrue);
        expect(await DataMigration.run(store), isFalse); // only once

        final snap = await Hive.openBox(LocalStore.snapshotBox);
        expect((snap.get('deals') as List).length, 1);
        expect((snap.get('routes') as List).length, 2);
        await snap.close();

        final d = Deal.fromJson(store.deals.get('ctl')!);
        expect(d.clientId, isNotNull);
        expect(store.clients.length, 1);
        expect(store.clients.values.single['name'], 'Buyer LLC');
        expect(store.routes.keys, ['mine']);
        expect(store.settings.get('defaultAgencyFee'), 8);
        expect(store.settings.get('observerMode'), isNull);
        // Profit of the old deal is unchanged by the migration.
        expect(
          DealProfit.of(d).netProfitUsd,
          closeTo(DealProfit.of(Deal.fromJson(v21Deal())).netProfitUsd, 1e-9),
        );
      },
    );
  });

  group('Roles and access', () {
    AccessPolicy as(UserRole r, {String? id, String? client}) =>
        AccessPolicy(role: r, userId: id, clientId: client);

    test('only the owner sees internal finance', () {
      final d = controlDeal().copyWith(assignedUserIds: ['m1']);
      for (final r in [
        UserRole.admin,
        UserRole.manager,
        UserRole.partner,
        UserRole.client,
      ]) {
        final p = as(r, id: 'm1', client: 'c1');
        expect(p.seesFinance, isFalse);
        final x = p.redact(d);
        final profit = DealProfit.of(x);
        expect(profit.purchase.goodsUsd, 0, reason: '$r');
        expect(profit.purchase.agencyFeeUsd, 0, reason: '$r');
        expect(profit.purchase.logisticsUsd, 0, reason: '$r');
        expect(profit.vatRefundUsd, 0, reason: '$r');
        expect(x.sellerContract.notes, isEmpty);
        expect(x.buyerContract.notes, isEmpty);
        expect(x.marginValue, 0);
        // The JSON of the redacted deal holds no internal numbers at all.
        final json = jsonEncode(x.toJson());
        expect(json, isNot(contains('1600')), reason: '$r');
        expect(json, isNot(contains('5400')), reason: '$r');
      }
      expect(AccessPolicy.owner.redact(d), same(d));
    });

    test('client: own deal only, no factory in back-to-back', () {
      final p = as(UserRole.client, id: 'u', client: 'c1');
      expect(p.canSee(controlDeal()), isTrue);
      expect(p.canSee(controlDeal().copyWith(clientId: 'other')), isFalse);
      final x = p.redact(controlDeal());
      expect(x.sellerContract.counterpartyName, isEmpty);
      expect(x.buyerContract.unitPrice, 2.30); // the client's own price
      expect(p.canChangeStages, isFalse);
      expect(p.canUseChat, isFalse);
    });

    test('partner: assigned deals, basic info and stages, no sums', () {
      final p = as(UserRole.partner, id: 'p1');
      expect(p.canSee(controlDeal()), isFalse);
      final d = controlDeal().copyWith(assignedUserIds: ['p1']);
      expect(p.canSee(d), isTrue);
      expect(p.redact(d).buyerContract.unitPrice, 0);
      expect(p.canChangeStages, isFalse);
    });

    test('manager / admin: documents and stages, no finance', () {
      final m = as(UserRole.manager, id: 'm1');
      final a = as(UserRole.admin, id: 'a1');
      expect(m.canChangeStages && m.canManageDocuments, isTrue);
      expect(a.canManageUsers && a.canSee(controlDeal()), isTrue);
      expect(m.canEditDeals || a.canEditDeals, isFalse);
      expect(m.canSee(controlDeal()), isFalse); // not assigned
    });

    test('controller enforces the policy on reads and writes', () async {
      var policy = AccessPolicy.owner;
      final deals = DealsController(
        DealRepository(await Hive.openBox<Map>('roles_deals')),
        policy: () => policy,
        actor: () => 'Ali',
        attachments: MemoryAttachmentStore(),
      );
      await deals.upsert(controlDeal());
      policy = as(UserRole.manager, id: 'm1');
      expect(deals.deals, isEmpty); // not assigned
      expect(() => deals.upsert(controlDeal()), throwsStateError);
      expect(deals.rawForBackup, throwsStateError);
      policy = AccessPolicy.owner;
      await deals.setAssignees('ctl', ['m1']);
      policy = as(UserRole.manager, id: 'm1');
      final seen = deals.deals.single;
      expect(DealProfit.of(seen).purchase.agencyFeeUsd, 0);
      await deals.setStage('ctl', ContractStage.prepayment);
      expect(deals.byId('ctl')!.stageHistory.last.by, 'Ali');
      await deals.addDocument(
        'ctl',
        category: DocCategory.invoice,
        fileName: 'invoice.pdf',
        bytes: [1, 2, 3],
      );
      final a = deals.byId('ctl')!.documents.single;
      expect(await deals.readFile('ctl', a.current!.fileId), [1, 2, 3]);
      expect(() => deals.delete('ctl'), throwsStateError);
    });

    test('profiles: PIN login, stored hash only, owner role refused', () async {
      final auth = AuthController(
        AuthRepository(await Hive.openBox('roles_auth')),
        hasher: const FastHasher(),
      );
      final u = await auth.addUser(
        name: 'Manager',
        role: UserRole.manager,
        pin: '4321',
      );
      expect(u.pinHash, isNot(contains('4321')));
      expect(
        () => auth.addUser(name: 'x', role: UserRole.owner, pin: '1111'),
        throwsArgumentError,
      );
      auth.switchUser();
      expect(await auth.unlockAsUser(u.id, '0000'), AuthResult.wrong);
      expect(await auth.unlockAsUser(u.id, '4321'), AuthResult.ok);
      expect(auth.role, UserRole.manager);
      expect(auth.policy.seesFinance, isFalse);
      expect(
        () => auth.addUser(name: 'y', role: UserRole.client, pin: '1111'),
        throwsStateError,
      );
      // A stored profile can never claim to be the owner.
      expect(
        AppUser.fromJson({...u.toJson(), 'role': 'owner'}).role,
        UserRole.client,
      );
    });
  });

  group('Trash (15 days)', () {
    test(
      'delete → trash → restore; purge after 15 days with documents',
      () async {
        final files = MemoryAttachmentStore();
        final events = <String>[];
        final deals = DealsController(
          DealRepository(await Hive.openBox<Map>('trash_deals')),
          attachments: files,
          onEvent: (_, code) => events.add(code),
        );
        await deals.upsert(controlDeal());
        await deals.addDocument(
          'ctl',
          category: DocCategory.other,
          fileName: 'a.pdf',
          bytes: [9],
        );
        await deals.delete('ctl');
        expect(deals.deals, isEmpty);
        expect(deals.trash.single.id, 'ctl');
        await deals.restore('ctl');
        expect(deals.deals.single.id, 'ctl');
        await deals.delete('ctl');
        final deletedAt = deals.trash.single.deletedAt!;
        expect(
          await deals.purgeExpired(
            now: deletedAt.add(const Duration(days: 14)),
          ),
          0,
        );
        expect(
          await deals.purgeExpired(
            now: deletedAt.add(const Duration(days: 15)),
          ),
          1,
        );
        expect(deals.trash, isEmpty);
        expect(files.files, isEmpty);
        expect(events, containsAllInOrder(['trashed', 'restored', 'deleted']));
      },
    );
  });

  group('Monthly analytics', () {
    test('profit per client by month of signing', () {
      Deal at(String id, String client, DateTime date, double price) {
        final d = controlDeal(price: price);
        return Deal.fromJson({
          ...d.toJson(),
          'id': id,
          'clientId': client,
          'buyerContract': d.buyerContract.copyWith(date: date).toJson(),
        });
      }

      final deals = [
        at('1', 'a', DateTime(2026, 11, 2), 2.30),
        at('2', 'a', DateTime(2026, 11, 20), 2.30),
        at('3', 'b', DateTime(2026, 11, 3), 2.40),
        at('4', 'a', DateTime(2026, 10, 30), 2.30), // previous month
      ];
      const a = AnalyticsService();
      final nov = a.byClient(deals, month: DateTime(2026, 11));
      expect(nov.length, 2);
      final ca = nov.firstWhere((c) => c.clientId == 'a');
      expect(ca.dealCount, 2);
      expect(ca.netProfitUsd, closeTo(2 * 7184, 1e-6));
      expect(ca.turnoverUsd, closeTo(2 * 50600, 1e-6));
      final cb = nov.firstWhere((c) => c.clientId == 'b');
      expect(cb.netProfitUsd, closeTo(7184 + 0.10 * 22000, 1e-6));
      expect(nov.first.clientId, 'a'); // sorted by profit
      final s = a.summarize(deals, DateTime(2026, 11));
      expect(s.contractCount, 3);
      expect(s.netProfitUsd, closeTo(3 * 7184 + 2200, 1e-6));
    });
  });

  group('Encrypted backups', () {
    test('weekly backup, restore on a new phone, v2.1 file', () async {
      final settingsBox = await Hive.openBox('bk_settings');
      final store = await LocalStore.open(encrypt: false);
      final auth = AuthController(
        AuthRepository(await Hive.openBox('bk_auth')),
        hasher: const FastHasher(),
      );
      final deals = DealsController(
        DealRepository(await Hive.openBox<Map>('bk_deals')),
        attachments: MemoryAttachmentStore(),
      );
      final backupDir = await dir.createTemp('files');
      final vault = MemoryBackupKeyVault();
      final ctl = BackupController(
        settingsBox: settingsBox,
        auth: auth,
        deals: deals,
        quotes: QuotesController(
          QuoteRepository(await Hive.openBox<Map>('bq')),
        ),
        settings: SettingsController(SettingsRepository(settingsBox)),
        rates: RatesController(settingsBox),
        routes: RoutesController(await Hive.openBox<Map>('br')),
        chat: ChatController(await Hive.openBox<Map>('bc')),
        clients: ClientsController(store.clients),
        vault: vault,
        directory: () async => backupDir,
        kdf: const KdfParams(memoryKiB: 256, iterations: 1),
      );
      await deals.upsert(controlDeal());
      await deals.addDocument(
        'ctl',
        category: DocCategory.mainContract,
        fileName: 'contract.pdf',
        bytes: [7, 7, 7],
        number: 'DOG-15',
      );

      // No key yet: nothing is made (the password is needed first).
      expect(await ctl.runWeeklyIfDue(), isNull);
      await ctl.rememberPassword('Secret123');
      expect(vault.value, isNot(contains('Secret123')));
      final file = await ctl.runWeeklyIfDue();
      expect(file, isNotNull);
      expect(await ctl.runWeeklyIfDue(), isNull); // not due again
      expect(
        await ctl.runWeeklyIfDue(
          now: DateTime.now().add(const Duration(days: 8)),
        ),
        isNotNull,
      );

      // "New phone": data gone, key gone, restore with the password.
      final json =
          jsonDecode(await file!.readAsString()) as Map<String, dynamic>;
      await deals.replaceAll(const []);
      await ctl.forgetKey();
      await expectLater(ctl.open(json, password: 'nope'), throwsA(anything));
      final content = await ctl.open(json, password: 'Secret123');
      await ctl.apply(content);
      final restored = deals.deals.single;
      expect(DealProfit.of(restored).netProfitUsd, closeTo(7184, 1e-6));
      expect(
        await deals.readFile('ctl', restored.documents.single.current!.fileId),
        [7, 7, 7],
      );

      // A plain v2.1 backup still restores (and gets a client).
      final legacy = {
        'format': BackupService.legacyFormat,
        'version': 3,
        'deals': [
          {...controlDeal().toJson(), 'clientId': null}..remove('schema'),
        ],
        'quotes': const [],
        'settings': const {},
      };
      await ctl.apply(await ctl.open(legacy));
      expect(deals.deals.single.clientId, isNotNull);
    });
  });

  group('Reminders', () {
    test('daily / every 3 days / weekly at the chosen time', () {
      final now = DateTime(2026, 11, 11, 10, 0);
      const t = TimeOfDay(hour: 9, minute: 30);
      final daily = const ReminderSettings(
        everyDays: 1,
        time: t,
      ).nextTimes(now, count: 2);
      expect(daily, [
        DateTime(2026, 11, 12, 9, 30),
        DateTime(2026, 11, 13, 9, 30),
      ]);
      final every3 = const ReminderSettings(
        everyDays: 3,
        time: t,
      ).nextTimes(now, count: 2);
      expect(every3[1].difference(every3[0]).inDays, 3);
      final weekly = const ReminderSettings(
        everyDays: 7,
        time: t,
      ).nextTimes(now, count: 2);
      expect(weekly[1], DateTime(2026, 11, 19, 9, 30));
      expect(const ReminderSettings().nextTimes(now), isEmpty);
    });

    test('settings are per user', () async {
      var user = 'owner';
      final fake = FakeReminderScheduler();
      final r = RemindersController(
        await Hive.openBox('rem'),
        userId: () => user,
        scheduler: fake,
      );
      await r.update(
        const ReminderSettings(everyDays: 7),
        title: 't',
        body: 'b',
      );
      expect(fake.scheduled, isNotEmpty);
      user = 'manager';
      expect(r.current.enabled, isFalse);
    });
  });

  test('splash: slogan fully readable for at least 3 s, total 4–5 s', () {
    final readable =
        SplashScreen.total - SplashScreen.sloganAt - SplashScreen.sloganFade;
    expect(readable, greaterThanOrEqualTo(const Duration(seconds: 3)));
    expect(SplashScreen.total, lessThanOrEqualTo(const Duration(seconds: 5)));
    expect(
      SplashScreen.total,
      greaterThanOrEqualTo(const Duration(seconds: 4)),
    );
  });

  test('every string of v3.0 is translated (uz, sr, zh)', () {
    final src = File('lib/core/l10n/strings_v3.dart').readAsStringSync();
    final en = RegExp(
      r"_(?:t|f)\(\s*'(?:[^'\\]|\\.)*'\s*,\s*'((?:[^'\\]|\\.)*)'",
    ).allMatches(src).map((m) => m.group(1)!.replaceAll(r"\'", "'"));
    final keys = {...en, 'Signing', 'Loading', 'Payment'};
    expect(keys.length, greaterThan(120));
    for (final dict in [
      {...trUz, ...trUzV3},
      {...trSr, ...trSrV3},
      {...trZh, ...trZhV3},
    ]) {
      final missing = [
        for (final k in keys)
          if (!dict.containsKey(k)) k,
      ];
      expect(missing, isEmpty);
    }
    expect(trUzV3.keys.toSet(), trSrV3.keys.toSet());
    expect(trZhV3.keys.toSet(), trSrV3.keys.toSet());
    expect(
      AppStrings(const Locale('uz', 'Latn')).roleName(UserRole.manager),
      isNot('Manager'),
    );
  });

  group('Home-screen widget', () {
    final s = AppStrings(const Locale('ru'));
    final fmt = Fmt('ru');
    Deal staged(String id, ContractStage st) =>
        Deal.fromJson({...controlDeal().toJson(), 'id': id, 'stage': st.name});

    test('owner: count, stage progress, amount, profit', () {
      final deals = [
        staged('a', ContractStage.loading),
        staged('b', ContractStage.prepayment),
        staged('c', ContractStage.closed),
      ];
      final v = WidgetSnapshot.build(
        deals: deals,
        selectedId: null,
        policy: AccessPolicy.owner,
        s: s,
        fmt: fmt,
        hideAmounts: false,
      ).values;
      expect(v['w_count'], '2'); // closed deals are not active
      expect(v['w_deal'], 'S-1 / P-1');
      expect(v['w_progress'], 2); // Загрузка
      expect(v['w_progress_max'], 4);
      expect(v['w_stage'], 'Загрузка · 3/5');
      expect(v['w_sum'], contains('50'));
      expect(v['w_profit'], contains('7'));
      expect(v['w_profit_negative'], isFalse);
      final chosen = WidgetSnapshot.build(
        deals: deals,
        selectedId: 'c',
        policy: AccessPolicy.owner,
        s: s,
        fmt: fmt,
        hideAmounts: false,
      ).values;
      expect(chosen['w_progress'], 4);
    });

    test('amounts hidden by switch and by role', () {
      final deals = [staged('a', ContractStage.loading)];
      Map<String, Object> as(AccessPolicy p, {bool hide = false}) =>
          WidgetSnapshot.build(
            deals: [for (final d in deals) p.redact(d)],
            selectedId: null,
            policy: p,
            s: s,
            fmt: fmt,
            hideAmounts: hide,
          ).values;
      expect(as(AccessPolicy.owner, hide: true)['w_profit'], '•••');
      expect(as(AccessPolicy.owner, hide: true)['w_sum'], '•••');
      const manager = AccessPolicy(role: UserRole.manager, userId: 'm');
      expect(as(manager)['w_profit'], '•••');
      expect(as(manager)['w_sum'], isNot('•••'));
      const partner = AccessPolicy(role: UserRole.partner, userId: 'p');
      expect(as(partner)['w_sum'], '•••');
    });

    test('no deals', () {
      final v = WidgetSnapshot.build(
        deals: const [],
        selectedId: 'x',
        policy: AccessPolicy.owner,
        s: s,
        fmt: fmt,
        hideAmounts: false,
      ).values;
      expect(v['w_count'], '0');
      expect(v['w_deal'], 'Нет сделок');
    });
  });

  group('Stage A: deal number, snapshots, two-party', () {
    test('NT numbers: automatic, per year, never reused, editable', () async {
      final meta = await Hive.openBox('num_meta');
      final deals = DealsController(
        DealRepository(await Hive.openBox<Map>('num_deals')),
        meta: meta,
      );
      Deal mk(String id, int year) => Deal.fromJson({
        ...controlDeal().toJson(),
        'id': id,
        'createdAt': DateTime(year, 3).toIso8601String(),
      });
      await deals.upsert(mk('a', 2026));
      await deals.upsert(mk('b', 2026));
      await deals.upsert(mk('c', 2027));
      expect(deals.byId('a')!.dealNumber, 'NT-2026-0001');
      expect(deals.byId('b')!.dealNumber, 'NT-2026-0002');
      expect(deals.byId('c')!.dealNumber, 'NT-2027-0001');
      await deals.delete('b');
      await deals.purge('b');
      await deals.upsert(mk('d', 2026));
      expect(deals.byId('d')!.dealNumber, 'NT-2026-0003'); // not reused
      expect(deals.isNumberTaken('nt-2026-0001'), isTrue);
      await deals.upsert(deals.byId('d')!.copyWith(dealNumber: 'SPECIAL-7'));
      expect(deals.byId('d')!.dealNumber, 'SPECIAL-7');
      expect(deals.byId('d')!.displayTitle, 'SPECIAL-7');
    });

    test('snapshots at signing and closing stay frozen', () async {
      final deals = DealsController(
        DealRepository(await Hive.openBox<Map>('snap_deals')),
      );
      await deals.upsert(controlDeal());
      final signed = deals.byId('ctl')!.snapshots.single;
      expect(signed.event, 'signed');
      expect(signed.values['profit'], closeTo(7184, 1e-6));
      // Price changed later: the signing snapshot keeps 7 184.
      final d = deals.byId('ctl')!;
      await deals.upsert(
        d.copyWith(buyerContract: d.buyerContract.copyWith(unitPrice: 2.40)),
      );
      await deals.setStage('ctl', ContractStage.closed);
      final snaps = deals.byId('ctl')!.snapshots;
      expect(snaps.map((x) => x.event), ['signed', 'closed']);
      expect(snaps.first.values['profit'], closeTo(7184, 1e-6));
      expect(snaps.last.values['profit'], closeTo(7184 + 2200, 1e-6));
      // Survives saving and is never given to other roles.
      final back = Deal.fromJson(deals.byId('ctl')!.toJson());
      expect(back.snapshots.length, 2);
      const manager = AccessPolicy(role: UserRole.admin, userId: 'a');
      expect(manager.redact(back).snapshots, isEmpty);
    });

    test('two-party contract: buyer and seller only; client sees seller', () {
      final d = controlDeal().copyWith(kind: DealKind.twoParty);
      expect(d.isSingleContract && d.isTwoParty, isTrue);
      expect(DealProfit.of(d).netProfitUsd, closeTo(7184, 1e-6));
      const client = AccessPolicy(
        role: UserRole.client,
        userId: 'u',
        clientId: 'c1',
      );
      final x = client.redact(d);
      expect(x.sellerContract.counterpartyName, 'Qingdao Factory');
      expect(DealProfit.of(x).purchase.goodsUsd, 0);
      expect(DealKind.fromName('twoParty'), DealKind.twoParty);
      final b = ReportBuilders(AppStrings(const Locale('en')), Fmt('en'));
      final r = b.buyerContract(d);
      expect(r.title, startsWith('Two-party contract'));
    });
  });

  group('Stage B: documents dossier', () {
    Future<DealsController> make(
      String box,
      MemoryAttachmentStore files,
    ) async {
      final deals = DealsController(
        DealRepository(await Hive.openBox<Map>(box)),
        attachments: files,
      );
      await deals.upsert(controlDeal());
      return deals;
    }

    test('official contract, versions, corrections, statuses', () async {
      final files = MemoryAttachmentStore();
      final deals = await make('dos1', files);
      final main = await deals.addDocument(
        'ctl',
        category: DocCategory.mainContract,
        fileName: 'contract.pdf',
        bytes: [1],
        number: 'DOG-2026/15',
        date: DateTime(2026, 11, 1),
      );
      // Replacing the file keeps the previous version.
      await deals.addVersion(
        'ctl',
        main.id,
        fileName: 'contract_v2.pdf',
        bytes: [2],
      );
      var doc = deals.byId('ctl')!.documents.single;
      expect(doc.versions.map((v) => v.fileName), [
        'contract.pdf',
        'contract_v2.pdf',
      ]);
      expect(await deals.readFile('ctl', doc.versions.first.fileId), [1]);
      expect(await deals.readFile('ctl', doc.current!.fileId), [2]);
      // Invoice + corrected invoice: the original becomes "replaced".
      final inv = await deals.addDocument(
        'ctl',
        category: DocCategory.invoice,
        fileName: 'inv-7.pdf',
        bytes: [3],
        number: 'INV-7',
        relatedId: main.id,
      );
      await deals.addDocument(
        'ctl',
        category: DocCategory.correction,
        fileName: 'inv-7-fixed.pdf',
        bytes: [4],
        number: 'INV-7/1',
        replacesId: inv.id,
      );
      final docs = deals.byId('ctl')!.documents;
      expect(docs.firstWhere((d) => d.id == inv.id).status, DocStatus.replaced);
      expect(docs.length, 3);
      // Cancel by hand; metadata edits never touch the files.
      doc = docs.firstWhere((d) => d.id == inv.id);
      await deals.updateDocument(
        'ctl',
        doc.copyWith(status: DocStatus.cancelled, versions: const []),
      );
      expect(
        deals
            .byId('ctl')!
            .documents
            .firstWhere((d) => d.id == inv.id)
            .versions
            .length,
        1,
      );
      // Delete removes every version file.
      await deals.removeDocument('ctl', main.id);
      expect(files.files.length, 2);
      // Survives saving.
      final back = Deal.fromJson(deals.byId('ctl')!.toJson());
      expect(back.documents.length, 2);
      expect(back.documents.first.number, 'INV-7');
    });

    test('clients and partners see only documents marked for them', () async {
      final files = MemoryAttachmentStore();
      var policy = AccessPolicy.owner;
      final deals = DealsController(
        DealRepository(await Hive.openBox<Map>('dos2')),
        attachments: files,
        policy: () => policy,
      );
      await deals.upsert(controlDeal());
      final internal = await deals.addDocument(
        'ctl',
        category: DocCategory.other,
        fileName: 'internal.xlsx',
        bytes: [5],
      );
      await deals.addDocument(
        'ctl',
        category: DocCategory.mainContract,
        fileName: 'contract.pdf',
        bytes: [6],
        visibleToClient: true,
      );
      policy = const AccessPolicy(
        role: UserRole.client,
        userId: 'u',
        clientId: 'c1',
      );
      final seen = deals.byId('ctl')!;
      expect(seen.documents.map((d) => d.title), ['contract.pdf']);
      expect(
        await deals.readFile('ctl', seen.documents.single.current!.fileId),
        [6],
      );
      expect(
        () => deals.readFile('ctl', internal.current!.fileId),
        throwsStateError,
      );
      expect(
        () => deals.addDocument(
          'ctl',
          category: DocCategory.other,
          fileName: 'x',
          bytes: [1],
        ),
        throwsStateError,
      );
    });

    test('3.0 attachments migrate to "other" documents; file ids kept', () {
      final j = controlDeal().toJson()
        ..remove('documents')
        ..['attachments'] = [
          {
            'id': 'f1',
            'name': 'old.pdf',
            'size': 3,
            'addedAt': '2026-11-10T10:00:00.000',
          },
        ];
      final d = Deal.fromJson(j);
      final doc = d.documents.single;
      expect(doc.category, DocCategory.other);
      expect(doc.current!.fileId, 'f1');
      expect(d.fileIds.toList(), ['f1']);
    });

    test('search by documents, goods and deal number', () {
      final d = controlDeal().copyWith(
        dealNumber: 'NT-2026-0042',
        documents: [
          DealDocument(
            id: 'x',
            category: DocCategory.supplement,
            title: 'Доп. соглашение',
            number: 'DS-3',
            createdAt: DateTime(2026),
          ),
        ],
      );
      final f = dealSearchFields(d).map((e) => e.toLowerCase());
      for (final q in [
        'nt-2026-0042',
        'ds-3',
        'polypropylene',
        'доп. соглашение',
      ]) {
        expect(f.any((v) => v.contains(q)), isTrue, reason: q);
      }
    });
  });
}
