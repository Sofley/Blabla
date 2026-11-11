import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/client.dart';
import '../models/deal.dart';
import '../models/price_quote.dart';
import 'local_store.dart';

/// One-time upgrade of v1–v2.1 data to the v3.0 schema. Nothing is lost:
///
/// 1. Every original record (deals, quotes, routes, settings) is copied
///    as-is into the encrypted box [LocalStore.snapshotBox] first.
/// 2. Deals and quotes are re-saved through their v3 readers, which
///    * turn old zeros in optional amounts (transport, freight, port fees,
///      logistics) into "not entered";
///    * keep the agent fee base of old deals (goods only) — old deals are
///      never recalculated;
///    * map old stages onto the 5 new ones and keep the old names in the
///      stage history.
/// 3. Buyers named in Contract #1 become clients of the directory.
/// 4. The two example tariffs created by v2.x are removed, only if the user
///    never edited them.
/// 5. The old default agent fee 9 % becomes 8 % (approved rate); a value the
///    user set to anything else is kept.
class DataMigration {
  static const currentSchema = 3;
  static const _uuid = Uuid();

  static const _exampleNote = 'Пример: обновите по актуальной ставке';

  /// Returns true when a migration was performed.
  static Future<bool> run(LocalStore store) async {
    final from = (store.settings.get('dataSchema') as num?)?.toInt() ?? 0;
    if (from >= currentSchema) return false;
    final fresh =
        store.deals.isEmpty &&
        store.quotes.isEmpty &&
        store.routes.isEmpty &&
        !store.auth.containsKey('account');
    if (!fresh) {
      await _snapshot(store);
      await _migrateDeals(store);
      await _migrateQuotes(store);
      await _removeExampleRoutes(store);
      final fee = store.settings.get('defaultAgencyFee');
      if (fee is num && fee == 9) {
        await store.settings.put('defaultAgencyFee', 8.0);
      }
      await store.settings.delete('observerMode');
    }
    await store.settings.put('dataSchema', currentSchema);
    return !fresh;
  }

  static Future<void> _snapshot(LocalStore store) async {
    final box = await Hive.openBox(
      LocalStore.snapshotBox,
      encryptionCipher: store.cipher,
    );
    await box.put('takenAt', DateTime.now().toIso8601String());
    await box.put('deals', [for (final v in store.deals.values) v]);
    await box.put('quotes', [for (final v in store.quotes.values) v]);
    await box.put('routes', [for (final v in store.routes.values) v]);
    await box.put('settings', {
      for (final k in store.settings.keys) k.toString(): store.settings.get(k),
    });
    await box.close();
  }

  static Future<void> _migrateDeals(LocalStore store) async {
    final clients = <String, Client>{
      for (final raw in store.clients.values)
        if (Client.fromJson(raw).name.isNotEmpty)
          Client.key(Client.fromJson(raw).name): Client.fromJson(raw),
    };
    for (final key in store.deals.keys.toList()) {
      final raw = store.deals.get(key);
      if (raw == null) continue;
      final Deal deal;
      try {
        deal = Deal.fromJson(raw);
      } catch (_) {
        continue; // unreadable record stays untouched (and in the snapshot)
      }
      var updated = deal;
      final buyer = deal.buyerContract.counterpartyName.trim();
      if (deal.clientId == null && buyer.isNotEmpty) {
        final client = clients.putIfAbsent(
          Client.key(buyer),
          () => Client(id: _uuid.v4(), name: buyer, createdAt: deal.createdAt),
        );
        updated = deal.copyWith(clientId: client.id);
      }
      await store.deals.put(key, updated.toJson());
    }
    for (final c in clients.values) {
      await store.clients.put(c.id, c.toJson());
    }
  }

  static Future<void> _migrateQuotes(LocalStore store) async {
    for (final key in store.quotes.keys.toList()) {
      final raw = store.quotes.get(key);
      if (raw == null) continue;
      try {
        await store.quotes.put(key, PriceQuote.fromJson(raw).toJson());
      } catch (_) {
        // keep as is
      }
    }
  }

  static Future<void> _removeExampleRoutes(LocalStore store) async {
    const examples = {(4200, 4800), (5600, 6100)};
    for (final key in store.routes.keys.toList()) {
      final r = store.routes.get(key);
      if (r == null) continue;
      final min = (r['priceMin'] as num?)?.toInt();
      final max = (r['priceMax'] as num?)?.toInt();
      if (r['notes'] == _exampleNote && examples.contains((min, max))) {
        await store.routes.delete(key);
      }
    }
  }
}
