import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/models/logistics_route.dart';

/// Logistics tariff grid: routes with price ranges and transit times.
class RoutesController extends ChangeNotifier {
  /// No example tariffs are created: the grid holds only what the user
  /// entered (v2.x example routes are removed by the v3 migration).
  RoutesController(this._box) {
    reload();
  }

  final Box<Map> _box;
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
