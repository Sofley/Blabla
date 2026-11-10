import 'package:b2b_contracts/data/models/price_quote.dart';
import 'package:b2b_contracts/domain/price_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The user's example: 15 c EXW, 10 c logistics, 9 % agent, 5 c profit,
  // 9 % VAT refund, 500 000 pcs.
  final now = DateTime(2026, 11, 10);
  final q = PriceQuote(
    id: 'q',
    quantity: 500000,
    unit: 'pcs',
    exwPrice: 0.15,
    logisticsPerUnit: 0.10,
    agentPercent: 9,
    profitPerUnit: 0.05,
    vatRefundPercent: 9,
    createdAt: now,
    updatedAt: now,
  );

  test('selling price per unit', () {
    final b = PriceBreakdown(q);
    expect(b.agentPerUnit, closeTo(0.0135, 1e-12));
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
    expect(b.marginPercent, closeTo(0.0635 / 0.3135 * 100, 1e-9));
  });

  test('VAT refund can be switched off', () {
    final b = PriceBreakdown(q.copyWith(vatRefundEnabled: false));
    expect(b.totalProfit, closeTo(25000, 1e-6));
  });

  test('json round-trip', () {
    final copy = PriceQuote.fromJson(q.toJson());
    expect(PriceBreakdown(copy).totalProfit, closeTo(31750, 1e-6));
  });
}
