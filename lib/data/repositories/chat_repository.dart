import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat.dart';
import '../models/product.dart';

/// chats/{productId_buyerId} and chats/{id}/messages/{msgId}
class ChatRepository {
  ChatRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('chats');

  Stream<List<Conversation>> forUser(String uid) => _col
      .where('participants', arrayContains: uid)
      .orderBy('lastAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Conversation.fromDoc).toList());

  Stream<int> unreadCount(String uid) => forUser(uid).map((list) => list.where((c) => c.unreadFor(uid) > 0).length);

  Stream<Conversation?> watch(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? Conversation.fromDoc(d) : null);

  Stream<List<ChatMessage>> messages(String id, {int limit = 200}) => _col
      .doc(id)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  /// Creates the conversation document if it doesn't exist yet.
  Future<String> open({required String buyerId, required String buyerName, required Product product}) async {
    final id = Conversation.idFor(product.id, buyerId);
    final ref = _col.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [buyerId, product.sellerId],
        'buyerId': buyerId,
        'buyerName': buyerName,
        'sellerId': product.sellerId,
        'sellerName': product.sellerName,
        'productId': product.id,
        'productTitle': product.title,
        'productImage': product.cover,
        'lastMessage': '',
        'lastSenderId': '',
        'lastAt': FieldValue.serverTimestamp(),
        'unread': {buyerId: 0, product.sellerId: 0},
      });
    }
    return id;
  }

  Future<void> send(Conversation c, String senderId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final other = c.otherId(senderId);
    final batch = _db.batch();
    batch.set(_col.doc(c.id).collection('messages').doc(), {
      'senderId': senderId,
      'text': t.length > 2000 ? t.substring(0, 2000) : t,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_col.doc(c.id), {
      'lastMessage': t.length > 120 ? '${t.substring(0, 120)}…' : t,
      'lastSenderId': senderId,
      'lastAt': FieldValue.serverTimestamp(),
      'unread.$other': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> markRead(String convoId, String uid) async {
    try {
      await _col.doc(convoId).update({'unread.$uid': 0});
    } catch (_) {}
  }
}
