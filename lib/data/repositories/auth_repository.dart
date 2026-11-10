import 'package:hive_flutter/hive_flutter.dart';

import '../models/account.dart';

/// Stores the local account and brute-force counters.
class AuthRepository {
  AuthRepository(this._box);

  final Box _box;

  Account? get account {
    final raw = _box.get('account');
    if (raw is! Map) return null;
    try {
      return Account.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAccount(Account a) => _box.put('account', a.toJson());

  int get failedAttempts => _box.get('failedAttempts') as int? ?? 0;
  Future<void> setFailedAttempts(int v) => _box.put('failedAttempts', v);

  DateTime? get lockedUntil {
    final ms = _box.get('lockedUntil') as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLockedUntil(DateTime? t) => t == null
      ? _box.delete('lockedUntil')
      : _box.put('lockedUntil', t.millisecondsSinceEpoch);
}
