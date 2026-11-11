// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/models/logistics_route.dart';

/// Logistics tariff grid: routes with price ranges and transit times.
class RoutesController extends ChangeNotifier {
  RoutesController(this._box, {Box? flags}) : _flags = flags {
    _seedIfFirstRun();
    reload();
  }

  final Box<Map> _box;
  final Box? _flags;
  static const _uuid = Uuid();

  List<LogisticsRoute> _routes = [];
  List<LogisticsRoute> get routes => List.unmodifiable(_routes);

  void reload() {
    _routes = [for (final r in _box.values) ?_safe(r)]
      ..sort((a, b) => a.origin.compareTo(b.origin));
    notifyListeners();
  }

  static LogisticsRoute? _safe(Map raw) {
    try {
      return LogisticsRoute.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// Starter routes (editable examples) on the very first launch.
  void _seedIfFirstRun() {
    final flags = _flags;
    if (flags == null || flags.get('routesSeeded') == true) return;
    final now = DateTime.now();
    for (final r in [
      LogisticsRoute(
        id: _uuid.v4(),
        origin: 'Нинбо / Шанхай',
        destination: 'Поти',
        mode: TransportMode.sea,
        cargo: '40ft',
        priceMin: 4200,
        priceMax: 4800,
        daysMin: 25,
        daysMax: 30,
        notes: 'Пример: обновите по актуальной ставке',
        updatedAt: now,
      ),
      LogisticsRoute(
        id: _uuid.v4(),
        origin: 'Сиань',
        destination: 'Ташкент',
        mode: TransportMode.rail,
        cargo: '40ft',
        priceMin: 5600,
        priceMax: 6100,
        daysMin: 12,
        daysMax: 15,
        notes: 'Пример: обновите по актуальной ставке',
        updatedAt: now,
      ),
    ]) {
      _box.put(r.id, r.toJson());
    }
    flags.put('routesSeeded', true);
  }

  LogisticsRoute createDraft() => LogisticsRoute(
    id: _uuid.v4(),
    origin: '',
    destination: '',
    updatedAt: DateTime.now(),
  );

  Future<void> upsert(LogisticsRoute r) async {
    await _box.put(r.id, r.copyWith(updatedAt: DateTime.now()).toJson());
    reload();
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    reload();
  }

  Future<void> replaceAll(List<LogisticsRoute> routes) async {
    await _box.clear();
    await _box.putAll({for (final r in routes) r.id: r.toJson()});
    reload();
  }
}
