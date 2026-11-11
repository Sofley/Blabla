import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/models/chat_message.dart';

/// Per-deal chat and status log, stored on the device.
class ChatController extends ChangeNotifier {
  ChatController(this._box) {
    reload();
  }

  final Box<Map> _box;
  static const _uuid = Uuid();

  final Map<String, List<ChatMessage>> _byDeal = {};

  void reload() {
    _byDeal.clear();
    for (final raw in _box.values) {
      try {
        final m = ChatMessage.fromJson(raw);
        (_byDeal[m.dealId] ??= []).add(m);
      } catch (_) {}
    }
    for (final list in _byDeal.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    notifyListeners();
  }

  List<ChatMessage> messages(String dealId) =>
      List.unmodifiable(_byDeal[dealId] ?? const []);

  ChatMessage? last(String dealId) {
    final l = _byDeal[dealId];
    return l == null || l.isEmpty ? null : l.last;
  }

  List<ChatMessage> get all => [for (final l in _byDeal.values) ...l];

  Future<void> post(String dealId, ChatAuthor author, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final m = ChatMessage(
      id: _uuid.v4(),
      dealId: dealId,
      author: author,
      text: t,
      createdAt: DateTime.now(),
    );
    (_byDeal[dealId] ??= []).add(m);
    notifyListeners();
    await _box.put(m.id, m.toJson());
  }

  Future<void> deleteMessage(ChatMessage m) async {
    _byDeal[m.dealId]?.removeWhere((x) => x.id == m.id);
    notifyListeners();
    await _box.delete(m.id);
  }

  Future<void> deleteDealChat(String dealId) async {
    final ids = [for (final m in _byDeal.remove(dealId) ?? const []) m.id];
    notifyListeners();
    await _box.deleteAll(ids);
  }

  Future<void> replaceAll(List<ChatMessage> messages) async {
    await _box.clear();
    await _box.putAll({for (final m in messages) m.id: m.toJson()});
    reload();
  }
}
