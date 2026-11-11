import 'dart:io';

import 'package:b2b_contracts/core/l10n/app_lang.dart';
import 'package:b2b_contracts/core/l10n/app_strings.dart';
import 'package:b2b_contracts/core/l10n/slogans.dart';
import 'package:b2b_contracts/core/l10n/tr_sr.dart';
import 'package:b2b_contracts/core/l10n/tr_uz.dart';
import 'package:b2b_contracts/core/l10n/tr_zh.dart';
import 'package:b2b_contracts/core/l10n/translit.dart';
import 'package:b2b_contracts/core/utils/formatters.dart';
import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/deal.dart';
import 'package:b2b_contracts/data/models/price_quote.dart';
import 'package:b2b_contracts/data/models/trade_contract.dart';
import 'package:b2b_contracts/data/repositories/deal_repository.dart';
import 'package:b2b_contracts/domain/finance_calculator.dart';
import 'package:b2b_contracts/domain/price_calculator.dart';
import 'package:b2b_contracts/export/report_builders.dart';
import 'package:b2b_contracts/state/deals_controller.dart';
import 'package:b2b_contracts/ui/assistant/assistant_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

/// The user's example: FOB 1 550 $/t × 22 t, logistics 5 200 $, agent 9 %
/// of the factory amount, buyer price 2.30 $/kg, VAT refund 9 % of FOB,
/// my share 50 %.
Deal _deal({bool bonusInProfit = false}) {
  final now = DateTime(2026, 11, 11);
  return Deal(
    id: 'd',
    buyerContract: TradeContract(
      side: ContractSide.buyer,
      number: 'NX-1',
      date: now,
      currency: Currency.usd,
      unitPrice: 2.30,
      quantity: 22000,
      unit: 'kg',
      goodsRatePerUsd: 1,
      logisticsRatePerUsd: 1,
      agencyFeePercent: 0,
      vatEnabled: false,
    ),
    sellerContract: TradeContract(
      side: ContractSide.seller,
      number: 'CN-1',
      date: now,
      currency: Currency.usd,
      unitPrice: 1550,
      quantity: 22,
      unit: 't',
      goodsRatePerUsd: 1,
      freightCost: 5200,
      logisticsRatePerUsd: 1,
      agencyFeePercent: 9,
      vatEnabled: false,
      vatRefundEnabled: true,
      vatRefundPercent: 9,
      vatBonusShare: 50,
      vatBonusInProfit: bonusInProfit,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

PriceQuote _quote({bool bonusInProfit = false}) {
  final now = DateTime(2026, 11, 11);
  return PriceQuote(
    // v2.x formula: agent fee on goods only.
    agentBase: AgencyBase.goods,
    id: 'q',
    productName: 'PP',
    quantity: 22000,
    unit: 'kg',
    exwPrice: 1550,
    exwPerThousand: true,
    logisticsValue: 5200,
    logisticsIsTotal: true,
    agentPercent: 9,
    profitMode: ProfitMode.salePrice,
    profitValue: 2.30,
    vatRefundPercent: 9,
    vatBonusShare: 50,
    vatBonusInProfit: bonusInProfit,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(initializeDateFormatting);

  group('Net profit formula (user example)', () {
    test('switch OFF: bonus is for reference only', () {
      final p = DealProfit.of(_deal());
      expect(p.revenueExVatUsd, closeTo(50600, 1e-6));
      expect(p.purchase.goodsUsd, closeTo(34100, 1e-6));
      expect(p.purchase.logisticsUsd, 5200);
      expect(p.purchase.agencyFeeUsd, closeTo(3069, 1e-6));
      expect(p.vatRefundUsd, closeTo(3069, 1e-6));
      expect(p.vatBonusUsd, closeTo(1534.5, 1e-6));
      expect(p.netProfitUsd, closeTo(8231, 1e-6));
    });

    test('switch ON: bonus is added', () {
      expect(
        DealProfit.of(_deal(bonusInProfit: true)).netProfitUsd,
        closeTo(9765.5, 1e-6),
      );
    });

    test('v3.0 defaults: share 0 %, switch off, agent 8 % of V, no VAT', () {
      final c = TradeContract.empty(ContractSide.seller);
      expect(c.vatBonusShare, 0);
      expect(c.vatBonusInProfit, isFalse);
      expect(c.agencyFeePercent, 8);
      expect(c.agencyBase, AgencyBase.goodsAndLogistics);
      expect(c.agentVatPercent, isNull); // «Не задано», never assumed
      expect(c.vatEnabled, isFalse);
    });

    test('records saved before v2.1 keep their profit', () {
      final json = _deal().sellerContract.toJson()
        ..remove('vatBonusShare')
        ..remove('vatBonusInProfit');
      final old = TradeContract.fromJson(json);
      expect(old.vatBonusShare, 100);
      expect(old.vatBonusInProfit, isTrue);
    });
  });

  group('Price calculator: per tonne and from buyer price', () {
    test('same result as the deal', () {
      final b = PriceBreakdown(_quote());
      expect(b.goodsPerUnit, closeTo(1.55, 1e-12));
      expect(b.purchaseTotal, closeTo(34100, 1e-6));
      expect(b.agentTotal, closeTo(3069, 1e-6));
      expect(b.saleTotal, closeTo(50600, 1e-6));
      expect(b.totalProfit, closeTo(8231, 1e-6));
      expect(b.vatBonusTotal, closeTo(1534.5, 1e-6));
      expect(
        PriceBreakdown(_quote(bonusInProfit: true)).totalProfit,
        closeTo(9765.5, 1e-6),
      );
    });

    test('profit as amount: 0.33 USD/kg needs 2.3035 USD', () {
      final q = _quote().copyWith(
        exwPrice: 1600,
        logisticsValue: 5400,
        agentPercent: 8,
        profitMode: ProfitMode.amount,
        profitValue: 0.33,
      );
      expect(PriceBreakdown(q).salePricePerUnit, closeTo(2.303454545, 1e-8));
    });

    test('legacy quotes load (profitIsPercent, logisticsPerUnit)', () {
      final json = _quote().toJson()
        ..remove('profitMode')
        ..['profitIsPercent'] = true;
      expect(PriceQuote.fromJson(json).profitMode, ProfitMode.percent);
    });

    test('deal from quote keeps the profit (tonnes in Contract #2)', () async {
      final dir = await Directory.systemTemp.createTemp('v21');
      Hive.init(dir.path);
      final deals = DealsController(
        DealRepository(await Hive.openBox<Map>('d')),
      );
      for (final on in [false, true]) {
        final q = _quote(bonusInProfit: on);
        final d = deals.createFromQuote(q, companyName: 'X');
        expect(d.sellerContract.unit, 't');
        expect(d.sellerContract.quantity, 22);
        expect(
          DealProfit.of(d).netProfitUsd,
          closeTo(PriceBreakdown(q).totalProfit, 1e-6),
        );
      }
      await Hive.close();
      await dir.delete(recursive: true);
    });
  });

  group('Three-party contract pricing', () {
    test('margin % of factory amount sets the contract price', () {
      final d = _deal().copyWith(
        kind: DealKind.threeParty,
        pricingMode: PricingMode.marginPercent,
        marginValue: 10,
      );
      final price = computedBuyerUnitPrice(d)!;
      // factory 34 100 + logistics 5 200 + agent 3 069 + margin 3 410
      expect(price * 22000, closeTo(45779, 1e-6));
      final p = DealProfit.of(
        d.copyWith(buyerContract: d.buyerContract.copyWith(unitPrice: price)),
      );
      expect(p.markupUsd, closeTo(3410, 1e-6));
    });

    test('margin as a sum', () {
      final d = _deal().copyWith(
        pricingMode: PricingMode.marginAmount,
        marginValue: 8000,
      );
      expect(computedBuyerUnitPrice(d)! * 22000, closeTo(50369, 1e-6));
      expect(computedBuyerUnitPrice(_deal()), isNull);
    });

    test('buyer document shows the contract price only', () async {
      final b = ReportBuilders(AppStrings(const Locale('en')), Fmt('en'));
      final r = b.buyerContract(_deal().copyWith(kind: DealKind.threeParty));
      // No agent, factory or logistics lines at all.
      final labels = StringBuffer();
      for (final block in r.blocks) {
        try {
          for (final (label, cell) in (block as dynamic).rows) {
            labels.write('$label=${cell.text};');
          }
        } catch (_) {}
      }
      final l = labels.toString();
      expect(l, contains('Contract price'));
      expect(l, isNot(contains('Agent')));
      expect(l, isNot(contains('Logistics')));
      expect(l, isNot(contains('34,100')));
      expect(l, contains('50,600.00 USD'));
    });
  });

  group('Languages', () {
    test('all dictionaries have the same keys', () {
      expect(trUz.keys.toSet(), trSr.keys.toSet());
      expect(trZh.keys.toSet(), trSr.keys.toSet());
      expect(trUz.length, greaterThan(400));
    });

    test('every language translates, both alphabets', () {
      String save(AppLang l) => AppStrings(l.locale).save;
      expect(save(AppLang.ru), 'Сохранить');
      expect(save(AppLang.en), 'Save');
      expect(save(AppLang.uzCyrl), 'Сақлаш');
      expect(save(AppLang.uzLatn), 'Saqlash');
      expect(save(AppLang.srLatn), 'Sačuvaj');
      expect(save(AppLang.srCyrl), 'Сачувај');
      expect(save(AppLang.zh), '保存');
      expect(
        AppStrings(AppLang.uzLatn.locale).welcomeBack('Саид'),
        'Xush kelibsiz, Саид',
      ); // names are never transliterated
    });

    test('transliteration rules', () {
      expect(uzCyrlToLatn('Ўчириш'), 'O‘chirish');
      expect(uzCyrlToLatn('ҚҚС'), 'QQS');
      expect(uzCyrlToLatn('Шартнома'), 'Shartnoma');
      expect(uzCyrlToLatn('Ғалаба ва ҳисоб'), 'G‘alaba va hisob');
      expect(uzCyrlToLatn('Европа келди'), 'Yevropa keldi');
      expect(srLatnToCyrl('Ugovor br. 1, PDV 9%'), 'Уговор бр. 1, ПДВ 9%');
      expect(srLatnToCyrl('Ljiljana i njen džep'), 'Љиљана и њен џеп');
      expect(
        srLatnToCyrl('1 USD = 7,2 CNY, NexusTrade, Excel'),
        '1 USD = 7,2 CNY, NexusTrade, Excel',
      );
    });

    test('seven slogans per language', () {
      for (final l in AppLang.values) {
        final list = Slogans.forLang(l);
        expect(list.length, 7, reason: l.name);
        expect(list.toSet().length, 7);
      }
      expect(
        Slogans.forLang(AppLang.uzLatn).first,
        startsWith('Nexus Trade — bitim'),
      );
      expect(
        Slogans.forLang(AppLang.zh),
        contains('和气生财 · Nexus Trade 掌控每一笔交易'),
      );
    });

    test('formatter falls back for script locales', () {
      expect(Fmt('uz-Cyrl').locale, isNot(contains('-')));
      expect(Fmt('zh-Hans').money(1), isNotEmpty);
      expect(Fmt('xx').locale, 'en');
    });
  });

  group('Offline assistant', () {
    final engine = AssistantEngine(
      AppStrings(const Locale('en')),
      Fmt('en'),
      null,
      now: DateTime(2026, 11, 20),
    );

    test('quote: margin, break-even, bonus off, stale', () {
      final texts = engine.quote(_quote()).map((i) => i.text).join('\n');
      expect(texts, contains('Margin 16.3% is healthy'));
      expect(texts, contains('Break-even price'));
      expect(texts, contains('VAT bonus \$1,534.50 is not counted in profit'));
      expect(texts, contains('Not updated for 9 days'));
      expect(texts, contains('hidden from the buyer'));
    });

    test('quote: loss and low margin', () {
      final loss = engine.quote(_quote().copyWith(profitValue: 1.5));
      expect(loss.first.text, contains('"PP"'));
      expect(loss.any((i) => i.level == InsightLevel.danger), isTrue);
      final low = engine.quote(_quote().copyWith(profitValue: 1.96));
      expect(
        low.map((i) => i.text).join(),
        contains('below the recommended 5%'),
      );
    });

    test('deal: rounding not suggested in buyer-price mode; payer hint', () {
      final d = _deal().copyWith(
        kind: DealKind.threeParty,
        role: CompanyRole.payer,
      );
      final texts = engine.deal(d).map((i) => i.text).join('\n');
      expect(texts, contains('net profit \$8,231.00'));
      expect(texts, contains('Payment Terms'));
    });
  });
}
