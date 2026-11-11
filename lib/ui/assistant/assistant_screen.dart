import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/price_quote.dart';
import '../../state/deals_controller.dart';
import '../../state/quotes_controller.dart';
import '../../state/rates_controller.dart';
import 'assistant_engine.dart';

class _Msg {
  const _Msg.user(this.text) : insights = const [], fromUser = true;
  const _Msg.bot({this.text, this.insights = const []}) : fromUser = false;

  final bool fromUser;
  final String? text;
  final List<Insight> insights;
}

/// Chat-style business assistant. Offline (rule-based) mode works now;
/// the online mode is shown as "coming later".
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.quote, this.dealId});

  /// Optional context to analyse right away.
  final PriceQuote? quote;
  final String? dealId;

  static Future<void> open(
    BuildContext context, {
    PriceQuote? quote,
    String? dealId,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AssistantScreen(quote: quote, dealId: dealId),
    ),
  );

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _messages = <_Msg>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _started = false;

  AssistantEngine get _engine => AssistantEngine(
    context.s,
    Fmt.of(context),
    context.read<RatesController>(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _messages.add(_Msg.bot(text: context.s.assistantHello));
    if (widget.quote != null) _analyseQuote(widget.quote!, silent: true);
    if (widget.dealId != null) _analyseDeal(widget.dealId!, silent: true);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _push(List<_Msg> msgs) {
    setState(() => _messages.addAll(msgs));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _analyseQuote(PriceQuote q, {bool silent = false}) {
    final title = q.productName.isEmpty
        ? context.s.priceCalculator
        : q.productName;
    final msgs = [
      if (!silent) _Msg.user(title),
      _Msg.bot(insights: _engine.quote(q)),
    ];
    if (silent) {
      _messages.addAll(msgs);
    } else {
      _push(msgs);
    }
  }

  void _analyseDeal(String id, {bool silent = false}) {
    final d = context.read<DealsController>().byId(id);
    if (d == null) return;
    final msgs = [
      if (!silent) _Msg.user(d.displayTitle),
      _Msg.bot(insights: _engine.deal(d)),
    ];
    if (silent) {
      _messages.addAll(msgs);
    } else {
      _push(msgs);
    }
  }

  void _lastQuote() {
    final quotes = context.read<QuotesController>().quotes;
    if (quotes.isEmpty) {
      _push([
        _Msg.user(context.s.askLastQuote),
        _Msg.bot(text: context.s.assistantNoQuotes),
      ]);
      return;
    }
    _analyseQuote(quotes.first);
  }

  void _month() {
    final s = context.s;
    final deals = context.read<DealsController>().deals;
    _push([
      _Msg.user(s.askMonth),
      deals.isEmpty
          ? _Msg.bot(text: s.assistantNoDeals)
          : _Msg.bot(insights: _engine.month(deals)),
    ]);
  }

  void _rates() {
    final s = context.s;
    _push([_Msg.user(s.askRates), _Msg.bot(insights: _engine.ratesStatus())]);
  }

  Future<void> _pickQuote() async {
    final s = context.s;
    final quotes = context.read<QuotesController>().quotes;
    if (quotes.isEmpty) {
      _push([_Msg.user(s.askPickQuote), _Msg.bot(text: s.assistantNoQuotes)]);
      return;
    }
    final q = await _pick<PriceQuote>(
      s.askPickQuote,
      quotes,
      (q) => q.productName.isEmpty ? '—' : q.productName,
    );
    if (q != null) _analyseQuote(q);
  }

  Future<void> _pickDeal() async {
    final s = context.s;
    final deals = context.read<DealsController>().deals;
    if (deals.isEmpty) {
      _push([_Msg.user(s.askPickDeal), _Msg.bot(text: s.assistantNoDeals)]);
      return;
    }
    final d = await _pick(s.askPickDeal, deals, (d) => d.displayTitle);
    if (d != null) _analyseDeal(d.id);
  }

  Future<T?> _pick<T>(String title, List<T> items, String Function(T) label) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            for (final i in items.take(30))
              ListTile(
                title: Text(label(i)),
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
  }

  /// Very small keyword router — enough for an offline helper.
  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final t = text.toLowerCase();
    bool has(List<String> keys) => keys.any(t.contains);
    if (has([
      'цен',
      'narx',
      'нарх',
      'price',
      'cen',
      'цен',
      '价格',
      '报价',
      'расч',
      'hisob',
      'ҳисоб',
    ])) {
      _push([_Msg.user(text)]);
      _lastQuote();
    } else if (has([
      'сдел',
      'deal',
      'bitim',
      'битим',
      'posao',
      'посао',
      '交易',
      'контракт',
      'contract',
      'ugovor',
    ])) {
      _push([_Msg.user(text)]);
      _pickDeal();
    } else if (has(['меся', 'month', 'oy', 'ой', 'mesec', 'месец', '月'])) {
      _push([_Msg.user(text)]);
      _month();
    } else if (has(['курс', 'rate', 'kurs', '汇率', 'cbu', 'pboc'])) {
      _push([_Msg.user(text)]);
      _rates();
    } else {
      _push([
        _Msg.user(text),
        _Msg.bot(text: context.s.assistantDontUnderstand),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.assistantTitle),
            Text(s.assistantSubtitle, style: theme.textTheme.bodySmall),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text('🟢 ${s.assistantOnline}'),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('🟠 ${s.assistantOffline}'),
                  ),
                ],
                selected: const {false},
                onSelectionChanged: (v) {
                  if (v.first) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.assistantOnlineSoon)),
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _Bubble(msg: _messages[i]),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (label, icon, action) in [
                          (
                            s.askLastQuote,
                            Icons.calculate_outlined,
                            _lastQuote,
                          ),
                          (
                            s.askPickDeal,
                            Icons.folder_copy_outlined,
                            _pickDeal,
                          ),
                          (s.askPickQuote, Icons.list_alt, _pickQuote),
                          (s.askMonth, Icons.insights_outlined, _month),
                          (s.askRates, Icons.currency_exchange, _rates),
                        ]) ...[
                          ActionChip(
                            avatar: Icon(icon, size: 16),
                            label: Text(label),
                            onPressed: action,
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          decoration: InputDecoration(hintText: s.askHint),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        onPressed: _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});

  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    if (msg.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            msg.text!,
            style: TextStyle(color: theme.colorScheme.onPrimary),
          ),
        ),
      );
    }
    (IconData, Color) look(InsightLevel l) => switch (l) {
      InsightLevel.good => (Icons.check_circle_outline, colors.positive),
      InsightLevel.info => (Icons.lightbulb_outline, theme.colorScheme.primary),
      InsightLevel.warning => (
        Icons.warning_amber_rounded,
        const Color(0xFFE0A000),
      ),
      InsightLevel.danger => (Icons.error_outline, colors.negative),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .88,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  context.s.assistantTitle,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (msg.text != null)
              Text(msg.text!, style: theme.textTheme.bodyMedium),
            for (final i in msg.insights)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(look(i.level).$1, size: 18, color: look(i.level).$2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(i.text, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
