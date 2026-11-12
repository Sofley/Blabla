import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/trade_contract.dart';
import 'package:b2b_contracts/data/models/transport_type.dart';
import 'package:flutter_test/flutter_test.dart';

TradeContract seller({
  double quantity = 22,
  String unit = 't',
  LogisticsMethod method = LogisticsMethod.manual,
  double? rate,
  int? units,
  double? cargoTonnes,
  double? freight,
  double? portFees,
}) => TradeContract(
  side: ContractSide.seller,
  date: DateTime(2026, 11, 5),
  currency: Currency.usd,
  unitPrice: 1600,
  quantity: quantity,
  unit: unit,
  logisticsMethod: method,
  logisticsRate: rate,
  transportUnits: units,
  cargoTonnes: cargoTonnes,
  freightCost: freight,
  portFees: portFees,
);

void main() {
  group('TradeContract.tonnes', () {
    test('reads tonnes directly for t / т / 吨', () {
      expect(seller(unit: 't').tonnes, 22);
      expect(seller(unit: ' Т ').tonnes, 22);
      expect(seller(unit: '吨').tonnes, 22);
    });

    test('converts kilograms', () {
      expect(seller(quantity: 22000, unit: 'kg').tonnes, 22);
      expect(seller(quantity: 22000, unit: 'кг').tonnes, 22);
    });

    test('other units use the cargo weight entered by hand', () {
      expect(seller(unit: 'bags', cargoTonnes: 12.5).tonnes, 12.5);
      expect(seller(unit: 'bags').tonnes, isNull);
    });
  });

  group('TradeContract.calculatedFreight', () {
    test('per tonne: rate × tonnes', () {
      final c = seller(method: LogisticsMethod.perTonne, rate: 245.45);
      expect(c.calculatedFreight, closeTo(5399.9, 1e-9));
    });

    test('per truck / container: rate × units', () {
      final c = seller(
        method: LogisticsMethod.perTransportUnit,
        rate: 5400,
        units: 2,
      );
      expect(c.calculatedFreight, 10800);
    });

    test('an empty rate or unit count is "not set", not zero', () {
      expect(
        seller(method: LogisticsMethod.perTonne).calculatedFreight,
        isNull,
      );
      expect(
        seller(
          method: LogisticsMethod.perTransportUnit,
          rate: 5400,
        ).calculatedFreight,
        isNull,
      );
      expect(
        seller(
          method: LogisticsMethod.perTransportUnit,
          rate: 5400,
        ).logisticsEntered,
        isFalse,
      );
    });

    test('manual method ignores the rate', () {
      final c = seller(rate: 999, freight: 5400);
      expect(c.calculatedFreight, isNull);
      expect(c.logisticsTotal, 5400);
    });

    test('port fees are added to the calculated freight', () {
      final c = seller(
        method: LogisticsMethod.perTransportUnit,
        rate: 5400,
        units: 1,
        portFees: 150,
      );
      expect(c.logisticsTotal, 5550);
      expect(c.logisticsEntered, isTrue);
    });
  });

  group('TransportType.unitsFor', () {
    final truck22 = TransportType.defaults.firstWhere((t) => t.id == 'truck22');
    final cont20 = TransportType.defaults.firstWhere((t) => t.id == 'cont20');

    test('rounds up to whole trucks', () {
      expect(truck22.unitsFor(22), 1);
      expect(truck22.unitsFor(22.5), 2);
      expect(truck22.unitsFor(44), 2);
    });

    test('unknown weight or capacity gives no count', () {
      expect(truck22.unitsFor(null), isNull);
      expect(truck22.unitsFor(0), isNull);
      expect(cont20.unitsFor(22), isNull);
    });
  });
}
