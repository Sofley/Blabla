import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/logistics_route.dart';
import '../../state/routes_controller.dart';
import '../common/widgets.dart';
import 'rates_screen.dart';

/// Create / edit / delete one tariff line.
Future<void> showRouteEditor(BuildContext context, {LogisticsRoute? route}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _RouteEditor(route: route),
    ),
  );
}

/// Lets the user pick a route; returns it or null.
Future<LogisticsRoute?> pickRoute(BuildContext context) {
  return showModalBottomSheet<LogisticsRoute>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final s = ctx.s;
      final routes = ctx.watch<RoutesController>().routes;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(s.pickRoute, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(s.pickRouteHint, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (routes.isEmpty) Text(s.noRoutes),
            for (final r in routes) ...[
              RouteCard(route: r, onTap: () => Navigator.pop(ctx, r)),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
    },
  );
}

class _RouteEditor extends StatefulWidget {
  const _RouteEditor({this.route});

  final LogisticsRoute? route;

  @override
  State<_RouteEditor> createState() => _RouteEditorState();
}

class _RouteEditorState extends State<_RouteEditor> {
  late LogisticsRoute _r =
      widget.route ?? context.read<RoutesController>().createDraft();
  late final _origin = TextEditingController(text: _r.origin);
  late final _dest = TextEditingController(text: _r.destination);
  late final _cargo = TextEditingController(text: _r.cargo);
  late final _pMin = TextEditingController(text: Fmt.editable(_r.priceMin));
  late final _pMax = TextEditingController(text: Fmt.editable(_r.priceMax));
  late final _dMin = TextEditingController(
    text: _r.daysMin == 0 ? '' : '${_r.daysMin}',
  );
  late final _dMax = TextEditingController(
    text: _r.daysMax == 0 ? '' : '${_r.daysMax}',
  );
  late final _notes = TextEditingController(text: _r.notes);

  static const _cargoPresets = [
    '20ft',
    '40ft',
    '40HC',
    'LCL',
    'FTL',
    'кг',
    'м³',
  ];

  @override
  void dispose() {
    for (final c in [
      _origin,
      _dest,
      _cargo,
      _pMin,
      _pMax,
      _dMin,
      _dMax,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = context.s;
    if (_origin.text.trim().isEmpty || _dest.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.routeNeedsPoints)));
      return;
    }
    final routes = context.read<RoutesController>();
    final nav = Navigator.of(context);
    await routes.upsert(
      _r.copyWith(
        origin: _origin.text.trim(),
        destination: _dest.text.trim(),
        cargo: _cargo.text.trim(),
        priceMin: Fmt.parse(_pMin.text) ?? 0,
        priceMax: Fmt.parse(_pMax.text) ?? 0,
        daysMin: int.tryParse(_dMin.text.trim()) ?? 0,
        daysMax: int.tryParse(_dMax.text.trim()) ?? 0,
        notes: _notes.text.trim(),
      ),
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    const gap = SizedBox(height: 10);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.route == null ? s.newRoute : s.editRoute,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in TransportMode.values)
                  ChoiceChip(
                    avatar: Icon(routeIcon(m), size: 16),
                    label: Text(s.transportMode(m)),
                    selected: _r.mode == m,
                    onSelected: (_) =>
                        setState(() => _r = _r.copyWith(mode: m)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _origin,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: s.routeFrom),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 18),
                ),
                Expanded(
                  child: TextField(
                    controller: _dest,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: s.routeTo),
                  ),
                ),
              ],
            ),
            gap,
            TextField(
              controller: _cargo,
              decoration: InputDecoration(labelText: s.cargoType),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final c in _cargoPresets)
                  ActionChip(
                    label: Text(c),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _cargo.text = c),
                  ),
              ],
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: NumberField(
                    controller: _pMin,
                    label: s.priceFrom,
                    suffix: 'USD',
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NumberField(
                    controller: _pMax,
                    label: s.priceTo,
                    suffix: 'USD',
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dMin,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.daysFrom),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _dMax,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.daysTo),
                  ),
                ),
              ],
            ),
            gap,
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: s.notesSection),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.route != null)
                  IconButton(
                    tooltip: s.delete,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () async {
                      final routes = context.read<RoutesController>();
                      final nav = Navigator.of(context);
                      await routes.delete(_r.id);
                      nav.pop();
                    },
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: Text(s.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
