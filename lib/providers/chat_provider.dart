import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class ChatProvider extends ChangeNotifier {
  static const _key = 'conversations';
  static const _readKey = 'chat_read_marks';
  final List<Conversation> _convos = [];
  // "convoId|userId" -> number of messages that user has seen.
  final Map<String, int> _read = {};

  void load() {
    _convos
      ..clear()
      ..addAll(StorageService.readList(_key).map(Conversation.fromJson));
    _read.clear();
    for (final e in StorageService.getStringList(_readKey)) {
      final i = e.lastIndexOf('=');
      if (i > 0) _read[e.substring(0, i)] = int.tryParse(e.substring(i + 1)) ?? 0;
    }
  }

  bool isUnread(Conversation c, String userId) =>
      c.messages.isNotEmpty &&
      c.messages.last.senderId != userId &&
      (_read['${c.id}|$userId'] ?? 0) < c.messages.length;

  void markRead(String convoId, String userId) {
    final c = byId(convoId);
    if (c == null) return;
    final k = '$convoId|$userId';
    if (_read[k] == c.messages.length) return;
    _read[k] = c.messages.length;
    StorageService.setStringList(_readKey, _read.entries.map((e) => '${e.key}=${e.value}').toList());
    notifyListeners();
  }

  Future<void> _save() => StorageService.writeList(_key, _convos.map((c) => c.toJson()).toList());

  List<Conversation> forUser(String userId) =>
      _convos.where((c) => c.buyerId == userId || c.sellerId == userId).toList()
        ..sort((a, b) => b.lastAt.compareTo(a.lastAt));

  int unreadHint(String userId) => forUser(userId).where((c) => isUnread(c, userId)).length;

  Conversation? byId(String id) {
    for (final c in _convos) {
      if (c.id == id) return c;
    }
    return null;
  }

  Conversation openFor({required AppUser buyer, required Product product}) {
    for (final c in _convos) {
      if (c.buyerId == buyer.id && c.productId == product.id) return c;
    }
    final c = Conversation(
      id: StorageService.newId('c'),
      buyerId: buyer.id,
      buyerName: buyer.name,
      sellerId: product.sellerId,
      sellerName: product.sellerName,
      productId: product.id,
      productTitle: product.title,
    );
    _convos.add(c);
    _save();
    return c;
  }

  Future<void> send(String convoId, String senderId, String text) async {
    final c = byId(convoId);
    if (c == null || text.trim().isEmpty) return;
    c.messages.add(ChatMessage(senderId: senderId, text: text.trim()));
    await _save();
    notifyListeners();

    // Demo sellers reply automatically so the chat feels alive offline.
    if (senderId == c.buyerId && c.sellerId.startsWith('seller_')) {
      await Future.delayed(const Duration(seconds: 2));
      c.messages.add(ChatMessage(senderId: c.sellerId, text: _autoReply(text, c)));
      await _save();
      notifyListeners();
    }
  }

  String _autoReply(String text, Conversation c) {
    final t = text.toLowerCase();
    if (t.contains('price') || t.contains('last') || t.contains('reduce') || t.contains('discount')) {
      return 'Thanks for asking! For "${c.productTitle}" I can give a small discount if you buy today. Make an offer 🙂';
    }
    if (t.contains('deliver') || t.contains('where') || t.contains('location')) {
      return 'We deliver everywhere in Sierra Leone. Freetown same day, provinces 1–3 days.';
    }
    if (t.contains('available') || t.contains('still')) {
      return 'Yes, it is still available. You can order directly in the JDMart app.';
    }
    return 'Kushe! Thank you for your message. How can I help you with "${c.productTitle}"?';
  }
}
