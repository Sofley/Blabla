import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/models/client.dart';
import '../domain/access_policy.dart';

/// Clients directory (buyer companies with contacts).
class ClientsController extends ChangeNotifier {
  ClientsController(this._box, {AccessPolicy Function()? policy})
    : _policy = policy ?? (() => AccessPolicy.owner) {
    reload();
  }

  final Box<Map> _box;
  final AccessPolicy Function() _policy;
  static const _uuid = Uuid();

  List<Client> _clients = [];

  /// Clients visible to the current user, sorted by name.
  List<Client> get clients {
    final p = _policy();
    if (p.canSeeClients) return List.unmodifiable(_clients);
    // A client user sees only its own record.
    return [
      for (final c in _clients)
        if (c.id == p.clientId) c,
    ];
  }

  /// Every record, for the owner's backup.
  List<Client> rawForBackup() {
    if (!_policy().seesFinance) throw StateError('forbidden');
    return List.unmodifiable(_clients);
  }

  Client? byId(String? id) {
    if (id == null) return null;
    for (final c in clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  void reload() {
    _clients = [for (final raw in _box.values) ?_safe(raw)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
  }

  void onSessionChanged() => notifyListeners();

  static Client? _safe(Map raw) {
    try {
      return Client.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Client createDraft() =>
      Client(id: _uuid.v4(), name: '', createdAt: DateTime.now());

  Future<void> upsert(Client c) async {
    if (!_policy().canEditClients) throw StateError('forbidden');
    _clients = [
      for (final e in _clients)
        if (e.id != c.id) e,
      c,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    await _box.put(c.id, c.toJson());
  }

  Future<void> delete(String id) async {
    if (!_policy().canEditClients) throw StateError('forbidden');
    _clients.removeWhere((c) => c.id == id);
    notifyListeners();
    await _box.delete(id);
  }

  /// Client with this company name; created when missing. Used to keep the
  /// directory in step with the buyer named in Contract #1.
  Future<Client?> ensure(String name) async {
    final n = name.trim();
    if (n.isEmpty || !_policy().canEditClients) return null;
    final key = Client.key(n);
    for (final c in _clients) {
      if (Client.key(c.name) == key) return c;
    }
    final c = Client(id: _uuid.v4(), name: n, createdAt: DateTime.now());
    await upsert(c);
    return c;
  }

  Future<void> replaceAll(List<Client> clients) async {
    if (!_policy().seesFinance) throw StateError('forbidden');
    await _box.clear();
    await _box.putAll({for (final c in clients) c.id: c.toJson()});
    reload();
  }
}
