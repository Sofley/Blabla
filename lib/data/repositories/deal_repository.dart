import 'package:hive_flutter/hive_flutter.dart';

import '../models/deal.dart';

/// Local persistence of deals in a Hive box (JSON-like maps, no codegen).
class DealRepository {
  DealRepository(this._box);

  static const boxName = 'deals_v1';

  static Future<DealRepository> open() async {
    final box = await Hive.openBox<Map>(boxName);
    return DealRepository(box);
  }

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
}
