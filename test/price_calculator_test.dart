import 'dart:io';

import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/price_quote.dart';
import 'package:b2b_contracts/data/repositories/deal_repository.dart';
import 'package:b2b_contracts/domain/finance_calculator.dart';
import 'package:b2b_contracts/domain/price_calculator.dart';
import 'package:b2b_contracts/state/deals_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  // The user's example: 15 c EXW, 500 000 pcs, 10 c logistics,
  // 9 % agent, (VAT), 5 c my profit, 9 % VAT refund.
  final now = DateTime(2026, 11, 10);
  final q = PriceQuote(
    id: 'q',
    quantity: 500000,
    unit: 'pcs',
    exwPrice: 0.15,
    logisticsValue: 0.10,
    agentPercent: 9,
    profitValue: 0.05,
    vatRefundPercent: 9,
    vatBonusShare: 100,
    vatBonusInProfit: true,
    createdAt: now,
    updatedAt: now,
  );

  test('without VAT: selling price per unit', () {
    final b = PriceBreakdown(q);
    expect(b.agentPerUnit, closeTo(0.0135, 1e-12));
    expect(b.vatPerUnit, 0);
    expect(b.salePricePerUnit, closeTo(0.3135, 1e-12));
    expect(b.vatRefundPerUnit, closeTo(0.0135, 1e-12));
    expect(b.totalProfitPerUnit, closeTo(0.0635, 1e-12));
  });

  test('batch totals', () {
    final b = PriceBreakdown(q);
    expect(b.saleTotal, closeTo(156750, 1e-6));
    expect(b.purchaseTotal, closeTo(75000, 1e-6));
    expect(b.logisticsTotal, closeTo(50000, 1e-6));
    expect(b.agentTotal, closeTo(6750, 1e-6));
    expect(b.markupTotal, closeTo(25000, 1e-6));
    expect(b.vatRefundTotal, closeTo(6750, 1e-6));
    expect(b.totalProfit, closeTo(31750, 1e-6));
  });

  test('step 5: VAT on goods + logistics + agent', () {
    final b = PriceBreakdown(q.copyWith(vatEnabled: true, vatPercent: 9));
    expect(b.vatPerUnit, closeTo(0.2635 * 0.09, 1e-12)); // 0.023715
    expect(b.costPerUnit, closeTo(0.287215, 1e-12));
    expect(b.salePricePerUnit, closeTo(0.337215, 1e-12));
    expect(b.vatTotal, closeTo(11857.5, 1e-6));
    // VAT is passed on to the buyer: my profit is unchanged.
    expect(b.totalProfit, closeTo(31750, 1e-6));
  });

  test('step 6: my commission in percent of cost', () {
    final b = PriceBreakdown(
      q.copyWith(
        vatEnabled: true,
        profitMode: ProfitMode.percent,
        profitValue: 10,
      ),
    );
    expect(b.profitPerUnit, closeTo(0.0287215, 1e-12));
    expect(b.salePricePerUnit, closeTo(0.287215 * 1.1, 1e-12));
  });

  test('step 3: logistics for the whole batch', () {
    final b = PriceBreakdown(
      q.copyWith(logisticsIsTotal: true, logisticsValue: 50000),
    );
    expect(b.logisticsPerUnit, closeTo(0.10, 1e-12));
    expect(b.salePricePerUnit, closeTo(0.3135, 1e-12));
    expect(b.logisticsTotal, 50000);
  });

  test('VAT refund can be switched off', () {
    final b = PriceBreakdown(q.copyWith(vatRefundEnabled: false));
    expect(b.totalProfit, closeTo(25000, 1e-6));
  });

  test('json round-trip and v1.1 compatibility', () {
    final full = q.copyWith(
      vatEnabled: true,
      profitMode: ProfitMode.percent,
      profitValue: 7,
    );
    final copy = PriceQuote.fromJson(full.toJson());
    expect(copy.vatEnabled, isTrue);
    expect(copy.profitIsPercent, isTrue);
    expect(copy.profitValue, 7);

    final v11 = q.toJson()
      ..remove('logisticsValue')
      ..remove('profitValue')
      ..remove('vatEnabled')
      ..['logisticsPerUnit'] = 0.10
      ..['profitPerUnit'] = 0.05;
    final old = PriceBreakdown(PriceQuote.fromJson(v11));
    expect(old.salePricePerUnit, closeTo(0.3135, 1e-12));
  });

  test('deal created from a quote has the same profit', () async {
    final dir = await Directory.systemTemp.createTemp('quote_deal');
    Hive.init(dir.path);
    final box = await Hive.openBox<Map>('deals');
    final deals = DealsController(DealRepository(box));
    for (final quote in [
      q,
      q.copyWith(
        vatEnabled: true,
        profitMode: ProfitMode.percent,
        profitValue: 10,
      ),
      q.copyWith(
        currency: Currency.cny,
        ratePerUsd: 7.2,
        exwPrice: 1.08,
        logisticsIsTotal: true,
        logisticsValue: 360000,
        vatEnabled: true,
      ),
    ]) {
      final b = PriceBreakdown(quote);
      final deal = deals.createFromQuote(quote, companyName: 'X');
      final p = DealProfit.of(deal);
      expect(p.turnoverUsd, closeTo(b.toUsd(b.saleTotal), 1e-6));
      expect(p.netProfitUsd, closeTo(b.toUsd(b.totalProfit), 1e-6));
    }
    await Hive.close();
    await dir.delete(recursive: true);
  });
}
