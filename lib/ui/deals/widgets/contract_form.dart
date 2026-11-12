import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../state/rates_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/currency.dart';
import '../../../data/models/deal.dart';
import '../../../data/models/trade_contract.dart';
import '../../../domain/finance_calculator.dart';
import '../../common/vat_bonus_section.dart';
import '../../common/widgets.dart';
import 'finance_cards.dart';
import 'logistics_fields.dart';

/// Editable form for ONE contract. Owns its own controllers, so the data of
/// Contract #1 and Contract #2 can never mix.
class ContractForm extends StatefulWidget {
  const ContractForm({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.defaultAgencyFee,
    required this.defaultVat,
    this.kind = DealKind.backToBack,
    this.header,
    this.partiesExtra,
    this.pricingControl,
    this.computedUnitPrice,
    this.showRequisites = true,
  });

  final TradeContract initial;
  final ValueChanged<TradeContract> onChanged;
  final double defaultAgencyFee;
  final double defaultVat;
  final DealKind kind;

  /// Replaces the default contract header.
  final Widget? header;

  /// Extra widgets at the end of the parties card (three-party contract).
  final Widget? partiesExtra;

  /// "How the price is set" control above the goods section (buyer side).
  final Widget? pricingControl;

  /// When set, the unit price is calculated (from the margin) and read-only.
  final double? computedUnitPrice;

  /// False for the internal calculation of a three-party contract, whose
  /// number, date and parties live in the single contract tab.
  final bool showRequisites;

  @override
  State<ContractForm> createState() => _ContractFormState();
}

class _ContractFormState extends State<ContractForm>
    with AutomaticKeepAliveClientMixin {
  late TradeContract _c = widget.initial;

  late final _number = TextEditingController(text: _c.number);
  late final _counterparty = TextEditingController(text: _c.counterpartyName);
  late final _intermediary = TextEditingController(text: _c.intermediaryName);
  late final _product = TextEditingController(text: _c.productName);
  late final _goods = TextEditingController(text: Fmt.editable(_c.unitPrice));
  late final _qty = TextEditingController(text: Fmt.editable(_c.quantity));
  late final _unit = TextEditingController(text: _c.unit);
  late final _refund = TextEditingController(
    text: Fmt.editable(_c.vatRefundPercent),
  );
  bool _rateAutoSet = false;
  bool _logRateAutoSet = false;
  late final _goodsRate = TextEditingController(
    text: Fmt.editable(_c.goodsRatePerUsd),
  );
  late final _transport = TextEditingController(
    text: Fmt.editableOpt(_c.transportCost),
  );
  late final _freight = TextEditingController(
    text: Fmt.editableOpt(_c.freightCost),
  );
  late final _port = TextEditingController(text: Fmt.editableOpt(_c.portFees));
  late final _agentVat = TextEditingController(
    text: Fmt.editableOpt(_c.agentVatPercent),
  );
  late final _agencyFixed = TextEditingController(
    text: Fmt.editableOpt(_c.agencyFixedUsd),
  );
  late final _logisticsRate = TextEditingController(
    text: Fmt.editableOpt(_c.logisticsRate),
  );
  late final _units = TextEditingController(
    text: _c.transportUnits?.toString() ?? '',
  );
  late final _tonnes = TextEditingController(
    text: Fmt.editableOpt(_c.cargoTonnes),
  );
  late final _closingRate = TextEditingController(
    text: Fmt.editableOpt(_c.closingRatePerUsd),
  );
  late final _logRate = TextEditingController(
    text: Fmt.editable(_c.logisticsRatePerUsd),
  );
  late final _agency = TextEditingController(
    text: Fmt.editable(_c.agencyFeePercent),
  );
  late final _vat = TextEditingController(text: Fmt.editable(_c.vatPercent));
  late final _notes = TextEditingController(text: _c.notes);

  /// Last contract this form emitted; anything else coming in is external.
  TradeContract? _emitted;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(ContractForm old) {
    super.didUpdateWidget(old);
    final incoming = widget.initial;
    if (!identical(incoming, _emitted) && !identical(incoming, _c)) {
      _c = incoming;
      _syncControllers();
    }
  }

  void _set(TextEditingController c, String text) {
    if (c.text != text) c.text = text;
  }

  void _syncControllers() {
    _set(_number, _c.number);
    _set(_counterparty, _c.counterpartyName);
    _set(_intermediary, _c.intermediaryName);
    _set(_product, _c.productName);
    if (Fmt.parse(_goods.text) != _c.unitPrice) {
      _set(_goods, Fmt.editable(_c.unitPrice));
    }
    if (Fmt.parse(_qty.text) != _c.quantity) {
      _set(_qty, Fmt.editable(_c.quantity));
    }
    _set(_unit, _c.unit);
    if (Fmt.parse(_goodsRate.text) != _c.goodsRatePerUsd) {
      _set(_goodsRate, Fmt.editable(_c.goodsRatePerUsd));
    }
  }

  bool get _isBuyer => _c.side == ContractSide.buyer;

  /// Internal costs are never shown on the buyer's contract, unless an
  /// older record already has them (so they can be cleared).
  bool get _showLogistics => !_isBuyer || _c.logisticsTotal > 0;
  bool get _showAgency =>
      !_isBuyer || (_c.agencyEnabled && _c.agencyFeePercent > 0);
  bool get _showVatBonus => !_isBuyer || _c.vatRefundEnabled;

  @override
  void dispose() {
    for (final c in [
      _number,
      _counterparty,
      _intermediary,
      _product,
      _goods,
      _qty,
      _unit,
      _refund,
      _goodsRate,
      _transport,
      _freight,
      _port,
      _logRate,
      _agency,
      _vat,
      _notes,
      _agentVat,
      _closingRate,
      _agencyFixed,
      _logisticsRate,
      _units,
      _tonnes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(TradeContract next) {
    setState(() => _c = next);
    _emitted = next;
    widget.onChanged(next);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _c.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _update(_c.copyWith(date: picked));
  }

  void _setCurrency(Currency cur) {
    final rate = cur == Currency.usd ? 1.0 : cur.defaultRatePerUsd;
    _goodsRate.text = Fmt.editable(rate);
    _rateAutoSet = cur != Currency.usd;
    _update(_c.copyWith(currency: cur, goodsRatePerUsd: rate));
  }

  void _setLogisticsCurrency(Currency cur) {
    final rate = cur == Currency.usd ? 1.0 : cur.defaultRatePerUsd;
    _logRate.text = Fmt.editable(rate);
    _logRateAutoSet = cur != Currency.usd;
    _update(_c.copyWith(logisticsCurrency: cur, logisticsRatePerUsd: rate));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final accent = accentFor(context, _c.side);
    const gap = SizedBox(height: 12);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        widget.header ?? _ContractHeader(side: _c.side, accent: accent),
        gap,
        // 1. Requisites
        if (widget.showRequisites)
          SectionCard(
            title: s.requisites,
            accent: accent,
            child: Column(
              children: [
                TextFormField(
                  controller: _number,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: '${s.contractNumber} *',
                    prefixIcon: const Icon(Icons.tag, size: 18),
                  ),
                  onChanged: (v) => _update(_c.copyWith(number: v.trim())),
                ),
                gap,
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: s.contractDate,
                      prefixIcon: const Icon(Icons.event_outlined, size: 18),
                    ),
                    child: Text(fmt.date(_c.date)),
                  ),
                ),
              ],
            ),
          ),
        if (widget.showRequisites) ...[
          gap,
          // 2. Parties
          SectionCard(
            title: s.parties,
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._partyFields(s),
                if (widget.partiesExtra != null) ...[gap, widget.partiesExtra!],
              ],
            ),
          ),
        ],
        gap,
        if (widget.pricingControl != null) ...[widget.pricingControl!, gap],
        // 3. Goods cost
        SectionCard(
          title: s.goodsSection,
          accent: accent,
          child: Column(
            children: [
              TextFormField(
                controller: _product,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: s.productName,
                  prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                ),
                onChanged: (v) => _update(_c.copyWith(productName: v)),
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: widget.computedUnitPrice != null
                        ? InputDecorator(
                            decoration: InputDecoration(
                              labelText: s.unitPriceCalculated,
                              suffixText: _c.currency.code,
                              enabled: false,
                            ),
                            child: Text(
                              fmt.price(
                                widget.computedUnitPrice!,
                                _c.currency,
                                symbol: false,
                              ),
                            ),
                          )
                        : NumberField(
                            controller: _goods,
                            label: _isBuyer ? s.unitPrice : s.factoryUnitPrice,
                            suffix: _c.currency.code,
                            onChanged: (v) =>
                                _update(_c.copyWith(unitPrice: v)),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _CurrencyDropdown(
                      label: s.contractCurrency,
                      value: _c.currency,
                      options: Currency.values,
                      onChanged: _setCurrency,
                    ),
                  ),
                ],
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: NumberField(
                      controller: _qty,
                      label: s.quantity,
                      onChanged: (v) => _update(_c.copyWith(quantity: v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _unit,
                      decoration: InputDecoration(
                        labelText: s.unitLabel,
                        hintText: s.unitHint,
                      ),
                      onChanged: (v) => _update(_c.copyWith(unit: v.trim())),
                    ),
                  ),
                ],
              ),
              if (_c.currency != Currency.usd) ...[
                gap,
                NumberField(
                  controller: _goodsRate,
                  label: _c.currency == Currency.cny
                      ? s.crossRateUsdCny
                      : s.ratePerUsd(_c.currency.code),
                  helper: _rateAutoSet ? s.rateCheckHint : s.rateHint,
                  mustBePositive: true,
                  onChanged: (v) {
                    _rateAutoSet = false;
                    _update(_c.copyWith(goodsRatePerUsd: v));
                  },
                ),
                Builder(
                  builder: (context) {
                    final live = context.watch<RatesController>().ratePerUsd(
                      _c.currency,
                    );
                    if (live == null) return const SizedBox.shrink();
                    final r = double.parse(live.toStringAsFixed(4));
                    return Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.currency_exchange, size: 16),
                        label: Text('${s.useOfficialRate}: ${Fmt.editable(r)}'),
                        onPressed: () {
                          _rateAutoSet = false;
                          _goodsRate.text = Fmt.editable(r);
                          _update(_c.copyWith(goodsRatePerUsd: r));
                        },
                      ),
                    );
                  },
                ),
                OptionalNumberField(
                  controller: _closingRate,
                  label: s.closingRate,
                  helper: s.closingRateHint,
                  onChanged: (v) => _update(_c.copyWith(closingRatePerUsd: v)),
                ),
              ],
              const SizedBox(height: 4),
              AmountRow(
                label: s.goodsCost,
                value: fmt.money(_c.goodsCost, _c.currency),
                emphasize: true,
              ),
            ],
          ),
        ),
        // 4. Logistics (internal: never on the buyer's contract)
        if (_showLogistics) ...[
          gap,
          SectionCard(
            title: s.logisticsSection,
            accent: accent,
            child: Column(
              children: [
                _CurrencyDropdown(
                  label: s.logisticsCurrency,
                  value: _c.logisticsCurrency,
                  options: Currency.logistics,
                  onChanged: _setLogisticsCurrency,
                ),
                gap,
                LogisticsMethodFields(
                  contract: _c,
                  rateController: _logisticsRate,
                  unitsController: _units,
                  tonnesController: _tonnes,
                  onChanged: _update,
                ),
                if (_c.logisticsMethod == LogisticsMethod.manual) ...[
                  gap,
                  OptionalNumberField(
                    controller: _transport,
                    label: s.transport,
                    suffix: _c.logisticsCurrency.code,
                    onChanged: (v) => _update(_c.copyWith(transportCost: v)),
                  ),
                  gap,
                  OptionalNumberField(
                    controller: _freight,
                    label: s.freight,
                    suffix: _c.logisticsCurrency.code,
                    onChanged: (v) => _update(_c.copyWith(freightCost: v)),
                  ),
                ],
                gap,
                OptionalNumberField(
                  controller: _port,
                  label: s.portFees,
                  suffix: _c.logisticsCurrency.code,
                  onChanged: (v) => _update(_c.copyWith(portFees: v)),
                ),
                if (_c.logisticsCurrency != Currency.usd) ...[
                  gap,
                  NumberField(
                    controller: _logRate,
                    label: s.ratePerUsd(_c.logisticsCurrency.code),
                    helper: _logRateAutoSet ? s.rateCheckHint : s.rateHint,
                    mustBePositive: true,
                    onChanged: (v) {
                      _logRateAutoSet = false;
                      _update(_c.copyWith(logisticsRatePerUsd: v));
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
        gap,
        // 5. Agency fee (internal) & VAT
        SectionCard(
          title: _showAgency ? s.feesSection : s.vatSection,
          accent: accent,
          child: Column(
            children: [
              if (_showAgency) ...[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.agencyFee),
                  subtitle: Text(s.agencyOnGoodsHint),
                  value: _c.agencyEnabled,
                  onChanged: (v) => _update(_c.copyWith(agencyEnabled: v)),
                ),
                if (_c.agencyEnabled) ...[
                  SegmentedButton<AgencyMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: AgencyMode.percent,
                        label: Text(s.agencyPercentMode),
                      ),
                      ButtonSegment(
                        value: AgencyMode.fixed,
                        label: Text(s.agencyFixedMode),
                      ),
                    ],
                    selected: {_c.agencyMode},
                    onSelectionChanged: (v) =>
                        _update(_c.copyWith(agencyMode: v.first)),
                  ),
                  gap,
                  if (_c.agencyMode == AgencyMode.percent) ...[
                    NumberField(
                      controller: _agency,
                      label: s.agencyPercentOfGoods,
                      suffix: '%',
                      onChanged: (v) => _update(
                        _c.copyWith(agencyFeePercent: v.clamp(0, 100)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: Text(
                          '${s.resetDefault}: ${fmt.percent(widget.defaultAgencyFee)}',
                        ),
                        onPressed: () {
                          _agency.text = Fmt.editable(widget.defaultAgencyFee);
                          _update(
                            _c.copyWith(
                              agencyFeePercent: widget.defaultAgencyFee,
                            ),
                          );
                        },
                      ),
                    ),
                    // Only a 3.0 test build could use V as the base: let such
                    // a record be switched back to the goods cost.
                    if (!_isBuyer &&
                        _c.agencyBase == AgencyBase.goodsAndLogistics)
                      TextButton.icon(
                        icon: const Icon(Icons.warning_amber, size: 16),
                        label: Text('${s.agencyBaseTitle}: ${s.agencyBaseV}'),
                        onPressed: () =>
                            _update(_c.copyWith(agencyBase: AgencyBase.goods)),
                      ),
                  ] else
                    OptionalNumberField(
                      controller: _agencyFixed,
                      label: s.agencyFixedAmount,
                      suffix: 'USD',
                      onChanged: (v) => _update(_c.copyWith(agencyFixedUsd: v)),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.agentVatSwitch),
                    subtitle: Text(s.agentVatHint),
                    value: _c.agentVatEnabled,
                    onChanged: (v) => _update(_c.copyWith(agentVatEnabled: v)),
                  ),
                  if (_c.agentVatEnabled)
                    OptionalNumberField(
                      controller: _agentVat,
                      label: s.agentVat,
                      suffix: '%',
                      onChanged: (v) =>
                          _update(_c.copyWith(agentVatPercent: v)),
                    ),
                ],
              ],
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(s.vatEnabled),
                subtitle: _c.vatEnabled ? null : Text(s.vatDisabledHint),
                value: _c.vatEnabled,
                onChanged: (v) => _update(_c.copyWith(vatEnabled: v)),
              ),
              if (_c.vatEnabled) ...[
                NumberField(
                  controller: _vat,
                  label: s.vatPercent,
                  suffix: '%',
                  onChanged: (v) => _update(_c.copyWith(vatPercent: v)),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: Text(
                      '${s.resetDefault}: ${fmt.percent(widget.defaultVat)}',
                    ),
                    onPressed: () {
                      _vat.text = Fmt.editable(widget.defaultVat);
                      _update(_c.copyWith(vatPercent: widget.defaultVat));
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        gap,
        // 6. Live calculation
        ContractCalculationCard(contract: _c),
        // 7. VAT refund & VAT bonus — at the very bottom of the calculations
        if (_showVatBonus) ...[
          gap,
          VatBonusSection(
            enabled: _c.vatRefundEnabled,
            refundController: _refund,
            share: _c.vatBonusShare,
            inProfit: _c.vatBonusInProfit,
            refundText: fmt.money(ContractFinancials.of(_c).vatRefundUsd),
            bonusText: fmt.money(ContractFinancials.of(_c).vatBonusUsd),
            baseHint: s.refundBaseLabel(_c.vatRefundBase),
            onEnabled: (v) => _update(_c.copyWith(vatRefundEnabled: v)),
            onRefundPercent: (v) => _update(_c.copyWith(vatRefundPercent: v)),
            onShare: (v) => _update(_c.copyWith(vatBonusShare: v)),
            onInProfit: (v) => _update(_c.copyWith(vatBonusInProfit: v)),
            baseSelector: DropdownButtonFormField<VatRefundBase>(
              initialValue: _c.vatRefundBase,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.refundBase),
              items: [
                for (final b in VatRefundBase.values)
                  DropdownMenuItem(
                    value: b,
                    child: Text(
                      s.refundBaseLabel(b),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (b) {
                if (b != null) _update(_c.copyWith(vatRefundBase: b));
              },
            ),
          ),
        ],
        gap,
        // 8. Remarks / Notes (internal for Contract #2)
        SectionCard(
          title: s.notesSection,
          accent: accent,
          child: TextFormField(
            controller: _notes,
            minLines: 4,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: s.notesHint,
              hintMaxLines: 3,
              alignLabelWithHint: true,
            ),
            style: theme.textTheme.bodyMedium,
            onChanged: (v) => _update(_c.copyWith(notes: v)),
          ),
        ),
      ],
    );
  }

  List<Widget> _partyFields(AppStrings s) {
    final counterparty = TextFormField(
      controller: _counterparty,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: s.counterpartyLabel(_c.side),
        prefixIcon: Icon(
          _c.side == ContractSide.buyer
              ? Icons.storefront_outlined
              : Icons.factory_outlined,
          size: 18,
        ),
      ),
      onChanged: (v) => _update(_c.copyWith(counterpartyName: v.trim())),
    );
    final intermediary = TextFormField(
      controller: _intermediary,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: widget.kind == DealKind.threeParty
            ? s.payerTrader
            : s.intermediary,
        prefixIcon: const Icon(Icons.business_outlined, size: 18),
      ),
      onChanged: (v) => _update(_c.copyWith(intermediaryName: v.trim())),
    );
    // A two-party contract has no intermediary: Buyer ↔ Seller only.
    if (widget.kind == DealKind.twoParty) return [counterparty];
    // Order follows the contract wording: Buyer ↔ Intermediary, Intermediary ↔ Seller.
    return _c.side == ContractSide.buyer
        ? [counterparty, const SizedBox(height: 12), intermediary]
        : [intermediary, const SizedBox(height: 12), counterparty];
  }
}

class _ContractHeader extends StatelessWidget {
  const _ContractHeader({required this.side, required this.accent});

  final ContractSide side;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            side == ContractSide.buyer ? Icons.call_received : Icons.call_made,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.s.contractTitle(side),
                  style: theme.textTheme.titleMedium?.copyWith(color: accent),
                ),
                Text(
                  context.s.contractParties(side),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final Currency value;
  final List<Currency> options;
  final ValueChanged<Currency> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Currency>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final c in options)
          DropdownMenuItem(value: c, child: Text('${c.code}  ${c.symbol}')),
      ],
      onChanged: (c) {
        if (c != null) onChanged(c);
      },
    );
  }
}
