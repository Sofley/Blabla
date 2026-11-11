import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/currency.dart';
import '../../data/models/price_quote.dart';
import '../../data/models/trade_contract.dart' show AgencyMode, LogisticsMethod;
import '../deals/widgets/logistics_fields.dart';
import '../../domain/price_calculator.dart';
import '../../state/auth_controller.dart';
import '../../state/deals_controller.dart';
import '../../state/quotes_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/rates_controller.dart';
import '../assistant/assistant_screen.dart';
import '../common/export_sheet.dart';
import '../common/vat_bonus_section.dart';
import '../rates/route_editor_sheet.dart';
import '../common/widgets.dart';
import '../deals/deal_editor_screen.dart';
import 'widgets/price_result.dart';

/// Our own price calculation: EXW + logistics + agent % + profit,
/// plus VAT refund paid back to the intermediary. Every number is editable.
class QuoteEditorScreen extends StatefulWidget {
  const QuoteEditorScreen({super.key, this.quoteId});

  final String? quoteId;

  static Future<void> open(BuildContext context, {String? quoteId}) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => QuoteEditorScreen(quoteId: quoteId)),
      );

  @override
  State<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends State<QuoteEditorScreen> {
  late PriceQuote _q;
  late bool _isNew;
  bool _dirty = false;

  late final _product = TextEditingController(text: _q.productName);
  late final _buyer = TextEditingController(text: _q.buyerName);
  late final _qty = TextEditingController(text: Fmt.editable(_q.quantity));
  late final _unit = TextEditingController(text: _q.unit);
  late final _rate = TextEditingController(text: Fmt.editable(_q.ratePerUsd));
  late final _exw = TextEditingController(text: Fmt.editable(_q.exwPrice));
  late final _log = TextEditingController(
    text: Fmt.editableOpt(_q.logisticsValue),
  );
  late final _agentVat = TextEditingController(
    text: Fmt.editableOpt(_q.agentVatPercent),
  );
  late final _agentFixed = TextEditingController(
    text: Fmt.editableOpt(_q.agentFixed),
  );
  late final _units = TextEditingController(
    text: _q.transportUnits?.toString() ?? '',
  );
  late final _tonnes = TextEditingController(
    text: Fmt.editableOpt(_q.cargoTonnes),
  );
  late final _vat = TextEditingController(text: Fmt.editable(_q.vatPercent));
  late final _agent = TextEditingController(
    text: Fmt.editable(_q.agentPercent),
  );
  late final _profit = TextEditingController(
    text: Fmt.editable(_q.profitValue),
  );
  late final _refund = TextEditingController(
    text: Fmt.editable(_q.vatRefundPercent),
  );
  late final _notes = TextEditingController(text: _q.notes);

  static const _incoterms = [
    'EXW',
    'FCA',
    'FOB',
    'CFR',
    'CIF',
    'CPT',
    'CIP',
    'DAP',
    'DDP',
  ];

  @override
  void initState() {
    super.initState();
    final quotes = context.read<QuotesController>();
    final settings = context.read<SettingsController>();
    final existing = widget.quoteId == null
        ? null
        : quotes.byId(widget.quoteId!);
    _isNew = existing == null;
    _q =
        existing ??
        quotes.createDraft(
          agentPercent: settings.defaultAgencyFee,
          agentVatPercent: settings.defaultAgentVat,
          vatPercent: settings.defaultVat,
          vatRefundPercent: settings.defaultVatRefund,
          vatBonusShare: settings.defaultVatShare,
          profitPerUnit: settings.defaultProfitPerUnit,
          unit: settings.defaultUnit,
        );
  }

  @override
  void dispose() {
    for (final c in [
      _product,
      _buyer,
      _qty,
      _unit,
      _vat,
      _rate,
      _exw,
      _log,
      _agent,
      _agentVat,
      _agentFixed,
      _units,
      _tonnes,
      _profit,
      _refund,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(PriceQuote q) => setState(() {
    _q = q;
    _dirty = true;
  });

  Future<bool> _save({bool pop = true}) async {
    FocusScope.of(context).unfocus();
    final s = context.s;
    if (_q.exwPrice <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.enterExwPrice)));
      return false;
    }
    await context.read<QuotesController>().upsert(_q);
    _dirty = false;
    _isNew = false;
    if (!mounted) return true;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.quoteSaved)));
    if (pop) Navigator.of(context).pop();
    return true;
  }

  Future<void> _createDeal() async {
    if (!await _save(pop: false) || !mounted) return;
    final deals = context.read<DealsController>();
    final settings = context.read<SettingsController>();
    final deal = deals.createFromQuote(_q, companyName: settings.companyName);
    await DealEditorScreen.open(context, draft: deal);
  }

  Future<void> _delete() async {
    final s = context.s;
    final navigator = Navigator.of(context);
    final quotes = context.read<QuotesController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteQuoteQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      _dirty = false;
      navigator.pop();
      await quotes.delete(_q.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final b = PriceBreakdown(_q);
    final c = _q.currency;
    final perUnit = _q.unit.isEmpty
        ? '${c.code} ${s.perUnitShort}'
        : '${c.code} / ${_q.unit}';
    const gap = SizedBox(height: 10);
    final perThousandLabel = s.perThousandLabel(tonneUnit(_q.unit));
    final observer = !context.watch<AuthController>().policy.canEditDeals;
    final liveRate = context.watch<RatesController>().ratePerUsd(c);

    return PopScope(
      canPop: !_dirty || observer,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.discardChanges),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.keepEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.discard),
              ),
            ],
          ),
        );
        if (discard == true) {
          _dirty = false;
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? s.newQuote : s.quoteShort),
          actions: [
            IconButton(
              tooltip: s.assistantAsk,
              icon: const Icon(Icons.auto_awesome),
              onPressed: () => AssistantScreen.open(context, quote: _q),
            ),
            IconButton(
              tooltip: s.exportTitle,
              icon: const Icon(Icons.ios_share),
              onPressed: () =>
                  showExportSheet(context, build: (r) => r.quote(_q)),
            ),
            if (!observer)
              PopupMenuButton<String>(
                onSelected: (v) => v == 'delete' ? _delete() : _createDeal(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'deal',
                    child: Text(s.createDealFromQuote),
                  ),
                  if (!_isNew)
                    PopupMenuItem(value: 'delete', child: Text(s.delete)),
                ],
              ),
            if (!observer)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(onPressed: _save, child: Text(s.save)),
              ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              if (observer) ...[
                Text(
                  s.observerNotSaved,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFFE0A000)),
                ),
                gap,
              ],
              SalePriceCard(b: b),
              gap,
              SectionCard(
                title: s.goodsAndTerms,
                accent: Theme.of(context).colorScheme.primary,
                child: Column(
                  children: [
                    TextField(
                      controller: _product,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: s.productName),
                      onChanged: (v) => _set(_q.copyWith(productName: v)),
                    ),
                    gap,
                    TextField(
                      controller: _buyer,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: s.buyerOptional),
                      onChanged: (v) => _set(_q.copyWith(buyerName: v)),
                    ),
                    gap,
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Currency>(
                            initialValue: _q.currency,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: s.currency),
                            items: [
                              for (final cur in Currency.values)
                                DropdownMenuItem(
                                  value: cur,
                                  child: Text(cur.code),
                                ),
                            ],
                            onChanged: (cur) {
                              if (cur == null) return;
                              final rate = cur.defaultRatePerUsd;
                              _rate.text = Fmt.editable(rate);
                              _set(
                                _q.copyWith(currency: cur, ratePerUsd: rate),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _incoterms.contains(_q.incoterms)
                                ? _q.incoterms
                                : 'EXW',
                            isExpanded: true,
                            decoration: InputDecoration(labelText: s.incoterms),
                            items: [
                              for (final t in _incoterms)
                                DropdownMenuItem(value: t, child: Text(t)),
                            ],
                            onChanged: (t) => _set(_q.copyWith(incoterms: t)),
                          ),
                        ),
                      ],
                    ),
                    if (c != Currency.usd) ...[
                      gap,
                      NumberField(
                        controller: _rate,
                        label: s.ratePerUsd(c.code),
                        helper: s.rateCheckHint,
                        mustBePositive: true,
                        onChanged: (v) => _set(_q.copyWith(ratePerUsd: v)),
                      ),
                      if (liveRate != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.currency_exchange, size: 16),
                            label: Text(
                              '${s.useOfficialRate}: ${Fmt.editable(double.parse(liveRate.toStringAsFixed(4)))}',
                            ),
                            onPressed: () {
                              final r = double.parse(
                                liveRate.toStringAsFixed(4),
                              );
                              _rate.text = Fmt.editable(r);
                              _set(_q.copyWith(ratePerUsd: r));
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              gap,
              SectionCard(
                title: s.priceSteps,
                accent: PriceColors.exw,
                trailing: Text(
                  c.code,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Step(
                      n: 1,
                      title: s.stepGoodsPrice,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(s.perUnitMode),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(perThousandLabel),
                              ),
                            ],
                            selected: {_q.exwPerThousand},
                            onSelectionChanged: (v) =>
                                _set(_q.copyWith(exwPerThousand: v.first)),
                          ),
                          gap,
                          NumberField(
                            controller: _exw,
                            label: '${s.exwPrice} (${_q.incoterms})',
                            suffix: _q.exwPerThousand
                                ? '${c.code} / ${tonneUnit(_q.unit)}'
                                : perUnit,
                            helper: _q.exwPerThousand
                                ? '= ${fmt.price(b.goodsPerUnit, c)} ${s.perUnitShort} · ${fmt.money(b.purchaseTotal, c)} ${s.forBatchShort}'
                                : null,
                            onChanged: (v) => _set(_q.copyWith(exwPrice: v)),
                          ),
                        ],
                      ),
                    ),
                    _Step(
                      n: 2,
                      title: s.stepQuantity,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: NumberField(
                              controller: _qty,
                              label: s.quantityVolume,
                              onChanged: (v) => _set(_q.copyWith(quantity: v)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _unit,
                              decoration: InputDecoration(
                                labelText: s.unitLabel,
                                hintText: s.unitHint,
                              ),
                              onChanged: (v) =>
                                  _set(_q.copyWith(unit: v.trim())),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Step(
                      n: 3,
                      title: s.stepLogistics,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LogisticsInputs(
                            method: _q.logisticsMethod,
                            currencyCode: c.code,
                            tonnesFromUnit: _q
                                .copyWith(cargoTonnes: null)
                                .tonnes,
                            cargoTonnes: _q.cargoTonnes,
                            transportTypeId: _q.transportTypeId,
                            transportUnits: _q.transportUnits,
                            total: b.logisticsUnset ? null : b.logisticsTotal,
                            rateController: _log,
                            unitsController: _units,
                            tonnesController: _tonnes,
                            onMethod: (m) =>
                                _set(_q.copyWith(logisticsMethod: m)),
                            onRate: (v) => _set(_q.copyWith(logisticsValue: v)),
                            onType: (id, units) => _set(
                              _q.copyWith(
                                transportTypeId: id,
                                transportUnits: units ?? _q.transportUnits,
                              ),
                            ),
                            onUnits: (v) =>
                                _set(_q.copyWith(transportUnits: v)),
                            onTonnes: (v) => _set(_q.copyWith(cargoTonnes: v)),
                          ),
                          if (_q.logisticsMethod == LogisticsMethod.manual) ...[
                            gap,
                            SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: false,
                                  label: Text(s.perUnitMode),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text(s.wholeBatchMode),
                                ),
                              ],
                              selected: {_q.logisticsIsTotal},
                              onSelectionChanged: (v) =>
                                  _set(_q.copyWith(logisticsIsTotal: v.first)),
                            ),
                            gap,
                            OptionalNumberField(
                              controller: _log,
                              label: s.logisticsPerUnit,
                              suffix: _q.logisticsIsTotal ? c.code : perUnit,
                              helper: b.logisticsUnset
                                  ? null
                                  : _q.logisticsIsTotal
                                  ? '= ${fmt.price(b.logisticsPerUnit, c)} ${s.perUnitShort}'
                                  : '= ${fmt.money(b.logisticsTotal, c)} ${s.forBatchShort}',
                              onChanged: (v) =>
                                  _set(_q.copyWith(logisticsValue: v)),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.alt_route, size: 16),
                                label: Text(s.fromTariffs),
                                onPressed: () async {
                                  final r = await pickRoute(context);
                                  if (r == null) return;
                                  // Tariffs are in USD: convert to quote currency.
                                  final rate = _q.currency == Currency.usd
                                      ? 1.0
                                      : _q.ratePerUsd;
                                  final v = double.parse(
                                    (r.priceAvg * rate).toStringAsFixed(2),
                                  );
                                  _log.text = Fmt.editableOpt(v);
                                  _set(
                                    _q.copyWith(
                                      logisticsIsTotal: true,
                                      logisticsValue: v,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _Step(
                      n: 4,
                      title: s.stepAgent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(s.agencyFee),
                            subtitle: Text(s.agencyOnGoodsHint),
                            value: _q.agentEnabled,
                            onChanged: (v) =>
                                _set(_q.copyWith(agentEnabled: v)),
                          ),
                          if (_q.agentEnabled) ...[
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
                              selected: {_q.agentMode},
                              onSelectionChanged: (v) =>
                                  _set(_q.copyWith(agentMode: v.first)),
                            ),
                            gap,
                            Row(
                              children: [
                                Expanded(
                                  child: _q.agentMode == AgencyMode.percent
                                      ? NumberField(
                                          controller: _agent,
                                          label: s.agencyPercentOfGoods,
                                          suffix: '%',
                                          onChanged: (v) => _set(
                                            _q.copyWith(
                                              agentPercent: v.clamp(0, 100),
                                            ),
                                          ),
                                        )
                                      : OptionalNumberField(
                                          controller: _agentFixed,
                                          label: s.agencyFixedAmount,
                                          suffix: c.code,
                                          helper: s.forBatchShort,
                                          onChanged: (v) =>
                                              _set(_q.copyWith(agentFixed: v)),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _Computed(
                                    label: s.agentAmount,
                                    value: fmt.price(
                                      b.agentPerUnit,
                                      c,
                                      symbol: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(s.agentVatSwitch),
                              value: _q.agentVatEnabled,
                              onChanged: (v) =>
                                  _set(_q.copyWith(agentVatEnabled: v)),
                            ),
                            if (_q.agentVatEnabled)
                              OptionalNumberField(
                                controller: _agentVat,
                                label: s.agentVat,
                                suffix: '%',
                                helper: b.agentVatUnset
                                    ? s.agentVatHint
                                    : '= ${fmt.price(b.agentVatPerUnit, c)} ${s.perUnitShort}',
                                onChanged: (v) =>
                                    _set(_q.copyWith(agentVatPercent: v)),
                              ),
                          ],
                        ],
                      ),
                    ),
                    _Step(
                      n: 5,
                      title: s.stepVat,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(s.vatInPrice),
                            subtitle: Text(s.vatInPriceHint),
                            value: _q.vatEnabled,
                            onChanged: (v) => _set(_q.copyWith(vatEnabled: v)),
                          ),
                          if (_q.vatEnabled)
                            Row(
                              children: [
                                Expanded(
                                  child: NumberField(
                                    controller: _vat,
                                    label: s.vatPercent,
                                    suffix: '%',
                                    onChanged: (v) =>
                                        _set(_q.copyWith(vatPercent: v)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _Computed(
                                    label: s.vatAmount,
                                    value: fmt.price(
                                      b.vatPerUnit,
                                      c,
                                      symbol: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    _Step(
                      n: 6,
                      title: s.stepMyProfit,
                      last: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<ProfitMode>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: ProfitMode.amount,
                                label: Text(s.amountPerUnit),
                              ),
                              ButtonSegment(
                                value: ProfitMode.percent,
                                label: Text(s.commissionPercent),
                              ),
                              ButtonSegment(
                                value: ProfitMode.salePrice,
                                label: Text(s.fromBuyerPrice),
                              ),
                            ],
                            selected: {_q.profitMode},
                            onSelectionChanged: (v) {
                              // Keep the same money per unit when switching mode.
                              final perUnit = b.profitPerUnit;
                              final cost = b.costPerUnit;
                              final value = switch (v.first) {
                                ProfitMode.amount => perUnit,
                                ProfitMode.percent =>
                                  cost > 0 ? perUnit / cost * 100 : 0.0,
                                ProfitMode.salePrice => cost + perUnit,
                              };
                              final rounded = double.parse(
                                value.toStringAsFixed(4),
                              );
                              _profit.text = Fmt.editable(rounded);
                              _set(
                                _q.copyWith(
                                  profitMode: v.first,
                                  profitValue: rounded,
                                ),
                              );
                            },
                          ),
                          gap,
                          NumberField(
                            controller: _profit,
                            label: switch (_q.profitMode) {
                              ProfitMode.amount => s.myProfitPerUnit,
                              ProfitMode.percent => s.myCommissionPercent,
                              ProfitMode.salePrice => s.buyerPricePerUnit,
                            },
                            suffix: _q.profitMode == ProfitMode.percent
                                ? '%'
                                : perUnit,
                            helper: switch (_q.profitMode) {
                              ProfitMode.percent =>
                                '${s.ofCost} ${fmt.price(b.costPerUnit, c)} = ${fmt.price(b.profitPerUnit, c)} ${s.perUnitShort}',
                              ProfitMode.amount =>
                                '= ${fmt.percent(b.costPerUnit > 0 ? b.profitPerUnit / b.costPerUnit * 100 : 0)} ${s.ofCost} ${fmt.price(b.costPerUnit, c)}',
                              ProfitMode.salePrice =>
                                '${s.myProfitPerUnit}: ${fmt.price(b.profitPerUnit, c)} · ${s.breakEvenPrice}: ${fmt.price(b.costPerUnit, c)}',
                            },
                            onChanged: (v) => _set(_q.copyWith(profitValue: v)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              gap,
              BatchTotalsCard(b: b),
              gap,
              // VAT refund & VAT bonus — at the very bottom of the calculations.
              VatBonusSection(
                enabled: _q.vatRefundEnabled,
                refundController: _refund,
                share: _q.vatBonusShare,
                inProfit: _q.vatBonusInProfit,
                refundText: fmt.money(b.vatRefundTotal, c),
                bonusText: fmt.money(b.vatBonusTotal, c),
                baseHint: '${s.ofExw} (${fmt.money(b.purchaseTotal, c)})',
                onEnabled: (v) => _set(_q.copyWith(vatRefundEnabled: v)),
                onRefundPercent: (v) => _set(_q.copyWith(vatRefundPercent: v)),
                onShare: (v) => _set(_q.copyWith(vatBonusShare: v)),
                onInProfit: (v) => _set(_q.copyWith(vatBonusInProfit: v)),
              ),
              gap,
              SectionCard(
                title: s.notesSection,
                child: TextField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: s.notesHint,
                    hintMaxLines: 3,
                  ),
                  onChanged: (v) => _set(_q.copyWith(notes: v)),
                ),
              ),
              const SizedBox(height: 16),
              if (!observer)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _createDeal,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(s.createDealFromQuote),
                ),
              const SizedBox(height: 6),
              Text(
                s.createDealHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numbered step of the price calculation.
class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.child,
    this.last = false,
  });

  final int n;
  final String title;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$n',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Read-only computed value shown next to an input.
class _Computed extends StatelessWidget {
  const _Computed({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label, enabled: false),
    child: Text(
      value,
      style: const TextStyle(fontFeatures: AppTheme.tabularFigures),
    ),
  );
}
