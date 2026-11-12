import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/deal.dart';
import 'package:b2b_contracts/data/models/trade_contract.dart';
import 'package:b2b_contracts/domain/finance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The approved control example: FOB 1 600 USD/t × 22 t, truck 5 400 USD,
/// agent 8 % of the goods cost, buyer price 2.30 USD/kg × 22 000 kg.
Deal controlDeal({double? closingRate}) {
  final date = DateTime(2026, 11, 5);
  return Deal(
    id: 'ctl',
    buyerContract: TradeContract(
      side: ContractSide.buyer,
      date: date,
      currency: Currency.usd,
      unitPrice: 2.30,
      quantity: 22000,
      unit: 'kg',
      goodsRatePerUsd: 1,
      agencyFeePercent: 0,
      vatEnabled: false,
    ),
    sellerContract: TradeContract(
      side: ContractSide.seller,
      date: date,
      currency: Currency.usd,
      unitPrice: 1600,
      quantity: 22,
      unit: 't',
      goodsRatePerUsd: 1,
      freightCost: 5400,
      logisticsRatePerUsd: 1,
      agencyFeePercent: 8,
      vatEnabled: false,
      closingRatePerUsd: closingRate,
    ),
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('snapshotOf', () {
    late CalcSnapshot snap;
    final at = DateTime(2026, 11, 12, 10, 30);

    setUp(() {
      snap = snapshotOf(controlDeal(), 'signed', at: at);
    });

    test('keeps the event and the moment it was taken', () {
      expect(snap.event, 'signed');
      expect(snap.at, at);
    });

    test('freezes the control example amounts in USD', () {
      expect(snap.values['goods'], closeTo(35200, 1e-6));
      expect(snap.values['logistics'], closeTo(5400, 1e-6));
      expect(snap.values['agency'], closeTo(2816, 1e-6));
      expect(snap.values['revenue'], closeTo(50600, 1e-6));
      expect(snap.values['profit'], closeTo(7184, 1e-6));
      expect(snap.values['margin'], closeTo(7184 / 50600 * 100, 0.05));
    });

    test('has no FX entry while the closing rate is not set', () {
      expect(snap.values.containsKey('fx'), isFalse);
    });

    test('survives a JSON round trip unchanged', () {
      final back = CalcSnapshot.fromJson(snap.toJson())!;
      expect(back.event, snap.event);
      expect(back.at, snap.at);
      expect(back.values, snap.values);
    });

    test('a snapshot does not follow later edits of the deal', () {
      final edited = controlDeal().copyWith(
        buyerContract: controlDeal().buyerContract.copyWith(unitPrice: 2.50),
      );
      final later = snapshotOf(edited, 'closed', at: at);
      expect(snap.values['profit'], closeTo(7184, 1e-6));
      expect(later.values['profit']! > snap.values['profit']!, isTrue);
    });
  });

  group('CalcSnapshot.fromJson', () {
    test('rejects a record without a valid date', () {
      expect(CalcSnapshot.fromJson({'event': 'signed', 'values': {}}), isNull);
    });

    test('skips non-numeric values instead of reading them as zero', () {
      final s = CalcSnapshot.fromJson({
        'event': 'closed',
        'at': '2026-11-12T00:00:00.000',
        'values': {'profit': 10, 'fx': null, 'note': 'x'},
      })!;
      expect(s.values, {'profit': 10.0});
    });
  });
}
