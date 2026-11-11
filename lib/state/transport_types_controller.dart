import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/models/transport_type.dart';

/// Directory of transport / loading types (editable, with own additions).
class TransportTypesController extends ChangeNotifier {
  TransportTypesController(this._box) {
    reload();
  }

  final Box _box;
  static const _key = 'transportTypes';
  static const _uuid = Uuid();

  List<TransportType> _types = [];
  List<TransportType> get types => List.unmodifiable(_types);

  TransportType? byId(String? id) {
    for (final t in _types) {
      if (t.id == id) return t;
    }
    return null;
  }

  void reload() {
    final raw = _box.get(_key);
    _types = raw is List
        ? [
            for (final t in raw)
              if (t is Map) ?TransportType.fromJson(t),
          ]
        : [...TransportType.defaults];
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await _box.put(_key, [for (final t in _types) t.toJson()]);
  }

  TransportType createDraft() => TransportType(id: _uuid.v4(), name: '');

  Future<void> upsert(TransportType t) async {
    final i = _types.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      _types[i] = t;
    } else {
      _types.add(t);
    }
    await _save();
  }

  Future<void> delete(String id) async {
    _types.removeWhere((t) => t.id == id);
    await _save();
  }

  List<Map<String, dynamic>> toBackup() => [for (final t in _types) t.toJson()];

  Future<void> restoreBackup(Object? raw) async {
    if (raw is! List) return;
    _types = [
      for (final t in raw)
        if (t is Map) ?TransportType.fromJson(t),
    ];
    await _save();
  }
}
