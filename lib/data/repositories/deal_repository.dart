import 'package:hive_flutter/hive_flutter.dart';

import '../models/deal.dart';

/// Local persistence of deals in a Hive box (JSON-like maps, no codegen).
class DealRepository {
  DealRepository(this._box);

  final Box<Map> _box;

  List<Deal> loadAll() {
    final result = <Deal>[];
    for (final raw in _box.values) {
      try {
        result.add(Deal.fromJson(raw));
      } catch (_) {
        // Skip a corrupted record instead of crashing the whole app.
      }
    }
    return result;
  }

  Future<void> save(Deal deal) => _box.put(deal.id, deal.toJson());

  Future<void> delete(String id) => _box.delete(id);

  Future<void> replaceAll(Iterable<Deal> deals) async {
    await _box.clear();
    await _box.putAll({for (final d in deals) d.id: d.toJson()});
  }
}
