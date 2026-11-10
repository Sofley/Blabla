import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/currency.dart';
import '../../data/models/price_quote.dart';
import '../../domain/price_calculator.dart';
import '../../state/deals_controller.dart';
import '../../state/quotes_controller.dart';
import '../../state/settings_controller.dart';
import '../common/export_sheet.dart';
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
    text: Fmt.editable(_q.logisticsPerUnit),
  );
  late final _agent = TextEditingController(
    text: Fmt.editable(_q.agentPercent),
  );
  late final _profit = TextEditingController(
    text: Fmt.editable(_q.profitPerUnit),
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
          vatRefundPercent: settings.defaultVatRefund,
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
      _rate,
      _exw,
      _log,
      _agent,
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
    final refundColor = FinanceColors.of(context).refund;

    return PopScope(
      canPop: !_dirty,
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
              tooltip: s.exportTitle,
              icon: const Icon(Icons.ios_share),
              onPressed: () =>
                  showExportSheet(context, build: (r) => r.quote(_q)),
            ),
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
                          flex: 3,
                          child: NumberField(
                            controller: _qty,
                            label: s.quantity,
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
                            onChanged: (v) => _set(_q.copyWith(unit: v.trim())),
                          ),
                        ),
                      ],
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
                    ],
                  ],
                ),
              ),
              gap,
              SectionCard(
                title: s.pricePerUnitStructure,
                accent: PriceColors.exw,
                trailing: Text(
                  c.code,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                child: Column(
                  children: [
                    NumberField(
                      controller: _exw,
                      label: '${s.exwPrice} (${_q.incoterms})',
                      suffix: perUnit,
                      onChanged: (v) => _set(_q.copyWith(exwPrice: v)),
                    ),
                    gap,
                    NumberField(
                      controller: _log,
                      label: s.logisticsPerUnit,
                      suffix: perUnit,
                      onChanged: (v) => _set(_q.copyWith(logisticsPerUnit: v)),
                    ),
                    gap,
                    Row(
                      children: [
                        Expanded(
                          child: NumberField(
                            controller: _agent,
                            label: s.agentPercentOfPurchase,
                            suffix: '%',
                            onChanged: (v) =>
                                _set(_q.copyWith(agentPercent: v)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: s.agentAmount,
                              enabled: false,
                            ),
                            child: Text(
                              fmt.price(b.agentPerUnit, c, symbol: false),
                              style: const TextStyle(
                                fontFeatures: AppTheme.tabularFigures,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    gap,
                    NumberField(
                      controller: _profit,
                      label: s.ourProfitMarkup,
                      suffix: perUnit,
                      onChanged: (v) => _set(_q.copyWith(profitPerUnit: v)),
                    ),
                  ],
                ),
              ),
              gap,
              SectionCard(
                title: s.vatRefundToIntermediary,
                accent: refundColor,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.includeVatRefund),
                      subtitle: Text(s.vatRefundExplain),
                      value: _q.vatRefundEnabled,
                      onChanged: (v) => _set(_q.copyWith(vatRefundEnabled: v)),
                    ),
                    if (_q.vatRefundEnabled)
                      NumberField(
                        controller: _refund,
                        label: s.vatRefundRate,
                        suffix: '%',
                        helper:
                            '${s.ofExw}: ${fmt.price(b.vatRefundPerUnit, c)} ${s.perUnitShort}',
                        onChanged: (v) =>
                            _set(_q.copyWith(vatRefundPercent: v)),
                      ),
                  ],
                ),
              ),
              gap,
              BatchTotalsCard(b: b),
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
