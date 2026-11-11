import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/currency.dart';
import '../../data/models/exchange_rate.dart';
import '../../data/models/logistics_route.dart';
import '../../state/auth_controller.dart';
import '../../state/rates_controller.dart';
import '../../state/routes_controller.dart';
import '../common/widgets.dart';
import 'route_editor_sheet.dart';

/// "Курсы и тарифы": CBU / PBOC rates, converter and logistics tariff grid.
class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key, this.actions = const []});

  final List<Widget> actions;

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch fresh CBU rates when the cache is older than 6 hours.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rates = context.read<RatesController>();
      final at = rates.fetchedAt;
      if (at == null || DateTime.now().difference(at).inHours >= 6) {
        rates.refreshCbu();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.ratesAndTariffs),
          actions: widget.actions,
          bottom: TabBar(
            tabs: [
              Tab(text: s.exchangeRates),
              Tab(text: s.logisticsTariffs),
            ],
          ),
        ),
        body: const TabBarView(children: [_RatesTab(), _TariffsTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Rates

class _RatesTab extends StatelessWidget {
  const _RatesTab();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final rates = context.watch<RatesController>();
    final observer = !context.watch<AuthController>().policy.canEditDeals;
    final cross = rates.cbuCrossToCny('USD');

    return RefreshIndicator(
      onRefresh: rates.refreshCbu,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          const _ConverterCard(),
          const SizedBox(height: 12),
          SectionCard(
            title: s.cbuTitle,
            trailing: rates.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: s.refresh,
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: rates.refreshCbu,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rates.fetchedAt == null
                      ? s.ratesNeverLoaded
                      : '${s.ratesUpdated}: ${fmt.dateTime(rates.fetchedAt!)}'
                            '${rates.cbu.isEmpty ? '' : ' · ${s.ratesOnDate} ${fmt.date(rates.cbu.first.date)}'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (rates.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      rates.cbu.isEmpty
                          ? s.ratesOfflineEmpty
                          : s.ratesOfflineCached,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                for (final r in rates.cbu.where(
                  (r) => RatesController.featured.contains(r.code),
                ))
                  _RateRow(rate: r, base: 'UZS'),
                if (rates.cbu.length > RatesController.featured.length)
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        s.allCurrencies(rates.cbu.length),
                        style: theme.textTheme.bodyMedium,
                      ),
                      children: [
                        for (final r in rates.cbu.where(
                          (r) => !RatesController.featured.contains(r.code),
                        ))
                          _RateRow(rate: r, base: 'UZS'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: s.pbocTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.pbocHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                for (final code in RatesController.pbocCodes)
                  _PbocRow(
                    code: code,
                    rate: rates.pboc[code],
                    suggestion: rates.cbuCrossToCny(code),
                    readOnly: observer,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: s.crossRate,
            child: Column(
              children: [
                AmountRow(
                  label: 'USD / CNY (CBU)',
                  value: cross == null ? '—' : Fmt.editable(_round(cross)),
                ),
                AmountRow(
                  label: 'USD / CNY (PBOC)',
                  value: rates.pboc['USD'] == null
                      ? '—'
                      : Fmt.editable(rates.pboc['USD']!.perUnit),
                ),
                AmountRow(
                  label: s.usedInCalculators,
                  value: rates.ratePerUsd(Currency.cny) == null
                      ? '—'
                      : '1 USD = ${Fmt.editable(_round(rates.ratePerUsd(Currency.cny)!))} CNY',
                  emphasize: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _round(double v) => double.parse(v.toStringAsFixed(4));

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rate, required this.base});

  final ExchangeRate rate;
  final String base;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final fmt = Fmt.of(context);
    final up = rate.diff > 0, down = rate.diff < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              rate.code,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rate.nominal == 1
                  ? rate.name
                  : '${fmt.number(rate.nominal)} ${rate.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            '${fmt.number(rate.rate)} $base',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  up
                      ? Icons.arrow_drop_up
                      : (down ? Icons.arrow_drop_down : Icons.remove),
                  size: 18,
                  color: up
                      ? colors.positive
                      : (down ? colors.negative : colors.neutral),
                ),
                Flexible(
                  child: Text(
                    rate.diff == 0 ? '' : fmt.number(rate.diff.abs()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: up ? colors.positive : colors.negative,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PbocRow extends StatelessWidget {
  const _PbocRow({
    required this.code,
    required this.rate,
    required this.suggestion,
    required this.readOnly,
  });

  final String code;
  final ExchangeRate? rate;
  final double? suggestion;
  final bool readOnly;

  Future<void> _edit(BuildContext context) async {
    final s = context.s;
    final rates = context.read<RatesController>();
    final controller = TextEditingController(
      text: rate == null ? '' : Fmt.editable(rate!.perUnit),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('PBOC · $code / CNY'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NumberField(
              controller: controller,
              label: '1 $code = ? CNY',
              onChanged: (_) {},
            ),
            if (suggestion != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(
                    '${s.useCbuCross}: ${Fmt.editable(_round(suggestion!))}',
                  ),
                  onPressed: () =>
                      controller.text = Fmt.editable(_round(suggestion!)),
                ),
              ),
          ],
        ),
        actions: [
          if (rate != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0.0),
              child: Text(s.clear),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, Fmt.parse(controller.text) ?? 0),
            child: Text(s.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await rates.setPboc(code, value);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      enabled: !readOnly,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: .1),
        child: Text(
          code,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 0,
          ),
        ),
      ),
      title: Text(
        rate == null
            ? s.notSet
            : '1 $code = ${Fmt.editable(rate!.perUnit)} CNY',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: rate == null ? null : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        rate == null
            ? (suggestion == null
                  ? s.tapToEnter
                  : '${s.cbuCrossShort}: ${Fmt.editable(_round(suggestion!))}')
            : '${s.enteredOn} ${fmt.date(rate!.date)}',
      ),
      trailing: readOnly ? null : const Icon(Icons.edit_outlined, size: 18),
      onTap: readOnly ? null : () => _edit(context),
    );
  }
}

/// Quick converter between any two currencies via CBU (UZS).
class _ConverterCard extends StatefulWidget {
  const _ConverterCard();

  @override
  State<_ConverterCard> createState() => _ConverterCardState();
}

class _ConverterCardState extends State<_ConverterCard> {
  final _amount = TextEditingController(text: '1000');
  String _from = 'USD';
  String _to = 'UZS';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final rates = context.watch<RatesController>();
    final codes = ['UZS', ...rates.cbu.map((r) => r.code)];
    if (codes.length == 1) codes.addAll(['USD', 'CNY', 'EUR']);

    double? perUzs(String c) => c == 'UZS' ? 1 : rates.cbuRate(c)?.perUnit;
    final a = Fmt.parse(_amount.text) ?? 0;
    final f = perUzs(_from), t = perUzs(_to);
    final result = (f == null || t == null || t == 0) ? null : a * f / t;

    Widget dropdown(String value, ValueChanged<String> onChanged) =>
        DropdownButtonFormField<String>(
          key: ValueKey('$value-${codes.length}'),
          initialValue: codes.contains(value) ? value : codes.first,
          isExpanded: true,
          decoration: const InputDecoration(),
          items: [
            for (final c in codes) DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => onChanged(v!)),
        );

    return SectionCard(
      title: s.converter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumberField(
            controller: _amount,
            label: s.amount,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: dropdown(_from, (v) => _from = v)),
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => setState(() {
                  final x = _from;
                  _from = _to;
                  _to = x;
                }),
              ),
              Expanded(child: dropdown(_to, (v) => _to = v)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result == null
                ? s.ratesNeeded
                : '${fmt.number(a)} $_from = ${fmt.number(double.parse(result.toStringAsFixed(4)))} $_to',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
          Text(
            s.converterViaCbu,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Tariffs

class _TariffsTab extends StatefulWidget {
  const _TariffsTab();

  @override
  State<_TariffsTab> createState() => _TariffsTabState();
}

class _TariffsTabState extends State<_TariffsTab> {
  TransportMode? _mode;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final observer = !context.watch<AuthController>().policy.canEditDeals;
    final all = context.watch<RoutesController>().routes;
    final routes = _mode == null
        ? all
        : all.where((r) => r.mode == _mode).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: observer
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-route',
              onPressed: () => showRouteEditor(context),
              icon: const Icon(Icons.add_road),
              label: Text(s.newRoute),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(s.all),
                  selected: _mode == null,
                  onSelected: (_) => setState(() => _mode = null),
                ),
                for (final m in TransportMode.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: Icon(routeIcon(m), size: 16),
                    label: Text(s.transportMode(m)),
                    selected: _mode == m,
                    onSelected: (_) =>
                        setState(() => _mode = _mode == m ? null : m),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (routes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                s.noRoutes,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final r in routes) ...[
            RouteCard(
              route: r,
              onTap: observer ? null : () => showRouteEditor(context, route: r),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            s.tariffsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

IconData routeIcon(TransportMode m) => switch (m) {
  TransportMode.sea => Icons.directions_boat_outlined,
  TransportMode.rail => Icons.train_outlined,
  TransportMode.road => Icons.local_shipping_outlined,
  TransportMode.air => Icons.flight_outlined,
  TransportMode.multimodal => Icons.alt_route,
};

class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.route, this.onTap, this.trailing});

  final LogisticsRoute route;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final r = route;
    final price = r.priceMin > 0 && r.priceMax > 0 && r.priceMin != r.priceMax
        ? '${fmt.money(r.priceMin)} – ${fmt.money(r.priceMax)}'
        : fmt.money(r.priceAvg);
    final days = r.daysMax > 0
        ? (r.daysMin > 0 && r.daysMin != r.daysMax
              ? '${r.daysMin}–${r.daysMax}'
              : '${r.daysMax}')
        : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: .1,
                ),
                child: Icon(
                  routeIcon(r.mode),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.origin} → ${r.destination}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.transportMode(r.mode)} · ${r.cargo}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                    if (r.notes.trim().isNotEmpty)
                      Text(
                        r.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (days != null)
                Chip(
                  label: Text(s.daysShort(days)),
                  visualDensity: VisualDensity.compact,
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
