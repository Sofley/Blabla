import 'package:b2b_contracts/data/models/contract_stage.dart';
import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/deal.dart';
import 'package:b2b_contracts/data/models/trade_contract.dart';
import 'package:b2b_contracts/domain/analytics_service.dart';
import 'package:b2b_contracts/domain/finance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

TradeContract _seller() => TradeContract(
  side: ContractSide.seller,
  number: 'S-1',
  date: DateTime(2026, 3, 10),
  currency: Currency.cny,
  unitPrice: 1.44,
  quantity: 50000, // 72 000 CNY = 10 000 USD at 7.2
  goodsRatePerUsd: 7.2,
  transportCost: 300,
  freightCost: 1500,
  portFees: 200, // 2 000 USD
  logisticsCurrency: Currency.usd,
  logisticsRatePerUsd: 1,
  agencyFeePercent: 9,
  vatEnabled: false,
);

TradeContract _buyer() => TradeContract(
  side: ContractSide.buyer,
  number: 'B-1',
  date: DateTime(2026, 3, 12),
  currency: Currency.usd,
  unitPrice: 14000,
  goodsRatePerUsd: 1,
  logisticsRatePerUsd: 1,
  agencyFeePercent: 0,
  vatEnabled: true,
  vatPercent: 9,
);

Deal _deal() => Deal(
  id: 'd1',
  buyerContract: _buyer(),
  sellerContract: _seller(),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

void main() {
  group('ContractFinancials', () {
    test('converts currencies and applies agency fee', () {
      final f = ContractFinancials.of(_seller());
      expect(f.goodsUsd, closeTo(10000, 1e-9));
      expect(f.logisticsUsd, closeTo(2000, 1e-9));
      expect(f.agencyFeeUsd, closeTo(900, 1e-9));
      expect(f.vatUsd, 0);
      expect(f.totalUsd, closeTo(12900, 1e-9));
      expect(f.totalInContractCurrency, closeTo(12900 * 7.2, 1e-6));
    });

    test('VAT is charged on goods + logistics + agency', () {
      final f = ContractFinancials.of(
        _seller().copyWith(vatEnabled: true, vatPercent: 9),
      );
      expect(f.vatUsd, closeTo(12900 * 0.09, 1e-9));
      expect(f.totalUsd, closeTo(12900 * 1.09, 1e-9));
    });

    test('zero rate never divides by zero', () {
      final f = ContractFinancials.of(_seller().copyWith(goodsRatePerUsd: 0));
      expect(f.goodsUsd, 0);
    });
  });

  group('DealProfit', () {
    test('profit = contract #1 excl. VAT − contract #2 total', () {
      final p = DealProfit.of(_deal());
      expect(p.turnoverUsd, closeTo(14000 * 1.09, 1e-9));
      expect(p.revenueExVatUsd, closeTo(14000, 1e-9));
      expect(p.expensesUsd, closeTo(12900, 1e-9));
      expect(p.netProfitUsd, closeTo(1100, 1e-9));
      expect(p.marginPercent, closeTo(1100 / 14000 * 100, 1e-9));
    });
  });

  group('AnalyticsService', () {
    test('aggregates by month of contract #1', () {
      final deals = [
        _deal(),
        _deal().copyWith(
          buyerContract: _buyer().copyWith(date: DateTime(2026, 4, 2)),
        ),
      ];
      const a = AnalyticsService();
      final march = a.summarize(deals, DateTime(2026, 3, 20));
      expect(march.contractCount, 1);
      expect(march.netProfitUsd, closeTo(1100, 1e-9));
      expect(march.stageCounts[ContractStage.signed], 1);

      final trend = a.trailing(deals, DateTime(2026, 4), 3);
      expect(trend.map((m) => m.contractCount), [0, 1, 1]);
    });
  });

  group('VAT refund', () {
    test('refund on goods is added to deal profit', () {
      final deal = _deal().copyWith(
        sellerContract: _seller().copyWith(
          vatRefundEnabled: true,
          vatRefundPercent: 9,
          vatBonusShare: 100,
          vatBonusInProfit: true,
        ),
      );
      final p = DealProfit.of(deal);
      expect(p.vatRefundUsd, closeTo(900, 1e-9)); // 9% of 10 000
      expect(p.markupUsd, closeTo(1100, 1e-9));
      expect(p.netProfitUsd, closeTo(2000, 1e-9));
    });

    test('refund on contract total', () {
      final f = ContractFinancials.of(
        _seller().copyWith(
          vatRefundEnabled: true,
          vatRefundPercent: 10,
          vatRefundBase: VatRefundBase.contractTotal,
        ),
      );
      expect(f.vatRefundUsd, closeTo(1290, 1e-9));
    });

    test('v1 records with lump-sum goodsCost still load', () {
      final json = _seller().toJson()
        ..remove('unitPrice')
        ..remove('quantity')
        ..['goodsCost'] = 72000;
      final c = TradeContract.fromJson(json);
      expect(c.goodsCost, 72000);
      expect(c.quantity, 1);
    });
  });

  group('Persistence', () {
    test('deal survives JSON round-trip', () {
      final deal = _deal().withStage(
        ContractStage.payment,
        at: DateTime(2026, 5),
      );
      final copy = Deal.fromJson(deal.toJson());
      expect(copy.stage, ContractStage.payment);
      expect(copy.stageDates.length, 4);
      expect(copy.sellerContract.goodsCost, closeTo(72000, 1e-6));
      expect(copy.sellerContract.currency, Currency.cny);
      expect(copy.buyerContract.vatEnabled, isTrue);
      expect(DealProfit.of(copy).netProfitUsd, closeTo(1100, 1e-9));
    });

    test('moving back drops dates of later stages', () {
      final deal = _deal()
          .withStage(ContractStage.closed)
          .withStage(ContractStage.prepayment);
      expect(deal.stageDates.keys, [
        ContractStage.signed,
        ContractStage.prepayment,
      ]);
    });
  });
}
