import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trade_contract.dart';
import '../../../data/models/transport_type.dart';
import '../../../state/transport_types_controller.dart';
import '../../common/widgets.dart';

/// Method of the logistics calculation and its inputs:
/// typed amounts, rate per tonne, or rate per truck / container.
class LogisticsMethodFields extends StatelessWidget {
  const LogisticsMethodFields({
    super.key,
    required this.contract,
    required this.rateController,
    required this.unitsController,
    required this.tonnesController,
    required this.onChanged,
  });

  final TradeContract contract;
  final TextEditingController rateController;
  final TextEditingController unitsController;
  final TextEditingController tonnesController;
  final ValueChanged<TradeContract> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = contract;
    return LogisticsInputs(
      method: c.logisticsMethod,
      currencyCode: c.logisticsCurrency.code,
      tonnesFromUnit: _unitTonnes(c),
      cargoTonnes: c.cargoTonnes,
      transportTypeId: c.transportTypeId,
      transportUnits: c.transportUnits,
      total: c.calculatedFreight,
      rateController: rateController,
      unitsController: unitsController,
      tonnesController: tonnesController,
      onMethod: (m) => onChanged(c.copyWith(logisticsMethod: m)),
      onRate: (v) => onChanged(c.copyWith(logisticsRate: v)),
      onType: (id, units) => onChanged(
        c.copyWith(
          transportTypeId: id,
          transportUnits: units ?? c.transportUnits,
        ),
      ),
      onUnits: (v) => onChanged(c.copyWith(transportUnits: v)),
      onTonnes: (v) => onChanged(c.copyWith(cargoTonnes: v)),
    );
  }

  static double? _unitTonnes(TradeContract c) =>
      c.copyWith(cargoTonnes: null).tonnes;
}

/// Shared by the contract form and the price calculator.
class LogisticsInputs extends StatelessWidget {
  const LogisticsInputs({
    super.key,
    required this.method,
    required this.currencyCode,
    required this.tonnesFromUnit,
    required this.cargoTonnes,
    required this.transportTypeId,
    required this.transportUnits,
    required this.total,
    required this.rateController,
    required this.unitsController,
    required this.tonnesController,
    required this.onMethod,
    required this.onRate,
    required this.onType,
    required this.onUnits,
    required this.onTonnes,
    this.showManual = true,
  });

  final LogisticsMethod method;
  final String currencyCode;

  /// Weight read from the unit of measure (t / kg); null when unknown.
  final double? tonnesFromUnit;
  final double? cargoTonnes;
  final String? transportTypeId;
  final int? transportUnits;

  /// Calculated logistics for the batch, null when something is missing.
  final double? total;
  final TextEditingController rateController;
  final TextEditingController unitsController;
  final TextEditingController tonnesController;
  final ValueChanged<LogisticsMethod> onMethod;
  final ValueChanged<double?> onRate;

  /// New transport type and the number of units calculated for it.
  final void Function(String? id, int? units) onType;
  final ValueChanged<int?> onUnits;
  final ValueChanged<double?> onTonnes;
  final bool showManual;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final types = context.watch<TransportTypesController>();
    final tonnes = tonnesFromUnit ?? cargoTonnes;
    const gap = SizedBox(height: 12);
    final type = types.byId(transportTypeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<LogisticsMethod>(
          showSelectedIcon: false,
          segments: [
            if (showManual)
              ButtonSegment(
                value: LogisticsMethod.manual,
                label: Text(s.logisticsManual),
              ),
            ButtonSegment(
              value: LogisticsMethod.perTonne,
              label: Text(s.logisticsPerTonne),
            ),
            ButtonSegment(
              value: LogisticsMethod.perTransportUnit,
              label: Text(s.logisticsPerTransport),
            ),
          ],
          selected: {method},
          onSelectionChanged: (v) => onMethod(v.first),
        ),
        if (method != LogisticsMethod.manual) ...[
          gap,
          if (method == LogisticsMethod.perTransportUnit) ...[
            DropdownButtonFormField<String>(
              initialValue: type?.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.transportType),
              items: [
                for (final t in types.types)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(t.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) {
                final units = types.byId(id)?.unitsFor(tonnes);
                if (units != null) unitsController.text = '$units';
                onType(id, units);
              },
            ),
            gap,
          ],
          OptionalNumberField(
            controller: rateController,
            label: method == LogisticsMethod.perTonne
                ? s.ratePerTonne
                : s.ratePerTransportUnit,
            suffix: currencyCode,
            onChanged: onRate,
          ),
          gap,
          if (tonnesFromUnit == null)
            OptionalNumberField(
              controller: tonnesController,
              label: s.cargoWeightTonnes,
              suffix: 't',
              onChanged: (v) {
                onTonnes(v);
                final units = type?.unitsFor(v);
                if (method == LogisticsMethod.perTransportUnit &&
                    units != null) {
                  unitsController.text = '$units';
                  onUnits(units);
                }
              },
            )
          else
            AmountRow(
              label: s.cargoWeightTonnes,
              value: '${fmt.number(tonnesFromUnit!)} t',
            ),
          if (method == LogisticsMethod.perTransportUnit) ...[
            gap,
            TextFormField(
              controller: unitsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: s.transportUnitsCount,
                hintText: s.notSetValue,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                helperText: _unitsHelper(s, type, tonnes),
                helperMaxLines: 2,
                suffixIcon: type?.unitsFor(tonnes) == null
                    ? null
                    : IconButton(
                        tooltip: s.recalculate,
                        icon: const Icon(Icons.calculate_outlined, size: 20),
                        onPressed: () {
                          final u = type!.unitsFor(tonnes)!;
                          unitsController.text = '$u';
                          onUnits(u);
                        },
                      ),
              ),
              onChanged: (v) => onUnits(int.tryParse(v)),
            ),
          ],
          const SizedBox(height: 4),
          AmountRow(
            label: s.logistics,
            value: total == null
                ? s.notSetValue
                : '${fmt.number(total!)} $currencyCode',
            emphasize: true,
          ),
        ],
      ],
    );
  }

  static String? _unitsHelper(AppStrings s, TransportType? t, double? tonnes) {
    if (t == null) return null;
    if (t.capacityTonnes == null) return s.capacityNotSetHint;
    final auto = t.unitsFor(tonnes);
    return auto == null ? null : s.unitsAutoHint(auto, t.capacityTonnes!);
  }
}
