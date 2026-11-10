import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/currency.dart';
import '../../../data/models/trade_contract.dart';
import '../../common/widgets.dart';
import 'finance_cards.dart';

/// Editable form for ONE contract. Owns its own controllers, so the data of
/// Contract #1 and Contract #2 can never mix.
class ContractForm extends StatefulWidget {
  const ContractForm({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.defaultAgencyFee,
    required this.defaultVat,
  });

  final TradeContract initial;
  final ValueChanged<TradeContract> onChanged;
  final double defaultAgencyFee;
  final double defaultVat;

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
    text: Fmt.editable(_c.transportCost),
  );
  late final _freight = TextEditingController(
    text: Fmt.editable(_c.freightCost),
  );
  late final _port = TextEditingController(text: Fmt.editable(_c.portFees));
  late final _logRate = TextEditingController(
    text: Fmt.editable(_c.logisticsRatePerUsd),
  );
  late final _agency = TextEditingController(
    text: Fmt.editable(_c.agencyFeePercent),
  );
  late final _vat = TextEditingController(text: Fmt.editable(_c.vatPercent));
  late final _notes = TextEditingController(text: _c.notes);

  @override
  bool get wantKeepAlive => true;

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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(TradeContract next) {
    setState(() => _c = next);
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
        _ContractHeader(side: _c.side, accent: accent),
        gap,
        // 1. Requisites
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
        gap,
        // 2. Parties
        SectionCard(
          title: s.parties,
          accent: accent,
          child: Column(children: _partyFields(s)),
        ),
        gap,
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
                    child: NumberField(
                      controller: _goods,
                      label: s.unitPrice,
                      suffix: _c.currency.code,
                      onChanged: (v) => _update(_c.copyWith(unitPrice: v)),
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
                  label: s.ratePerUsd(_c.currency.code),
                  helper: _rateAutoSet ? s.rateCheckHint : s.rateHint,
                  mustBePositive: true,
                  onChanged: (v) {
                    _rateAutoSet = false;
                    _update(_c.copyWith(goodsRatePerUsd: v));
                  },
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
        gap,
        // 4. Logistics
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
              NumberField(
                controller: _transport,
                label: s.transport,
                suffix: _c.logisticsCurrency.code,
                onChanged: (v) => _update(_c.copyWith(transportCost: v)),
              ),
              gap,
              NumberField(
                controller: _freight,
                label: s.freight,
                suffix: _c.logisticsCurrency.code,
                onChanged: (v) => _update(_c.copyWith(freightCost: v)),
              ),
              gap,
              NumberField(
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
        gap,
        // 5. Agency fee & VAT
        SectionCard(
          title: s.feesSection,
          accent: accent,
          child: Column(
            children: [
              NumberField(
                controller: _agency,
                label: s.agencyFee,
                suffix: '%',
                onChanged: (v) => _update(_c.copyWith(agencyFeePercent: v)),
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
                      _c.copyWith(agencyFeePercent: widget.defaultAgencyFee),
                    );
                  },
                ),
              ),
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
        // 6. VAT refund (paid back to the intermediary)
        SectionCard(
          title: s.vatRefundToIntermediary,
          accent: FinanceColors.of(context).refund,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(s.includeVatRefund),
                subtitle: Text(s.vatRefundExplain),
                value: _c.vatRefundEnabled,
                onChanged: (v) => _update(_c.copyWith(vatRefundEnabled: v)),
              ),
              if (_c.vatRefundEnabled) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: NumberField(
                        controller: _refund,
                        label: s.vatRefundRate,
                        suffix: '%',
                        onChanged: (v) =>
                            _update(_c.copyWith(vatRefundPercent: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<VatRefundBase>(
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
                          if (b != null) {
                            _update(_c.copyWith(vatRefundBase: b));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        gap,
        // 7. Live calculation
        ContractCalculationCard(contract: _c),
        gap,
        // 8. Remarks / Notes
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
        labelText: s.intermediary,
        prefixIcon: const Icon(Icons.business_outlined, size: 18),
      ),
      onChanged: (v) => _update(_c.copyWith(intermediaryName: v.trim())),
    );
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
