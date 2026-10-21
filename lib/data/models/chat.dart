import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

/// chats/{productId_buyerId}
class Conversation {
  final String id;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final String productId;
  final String productTitle;
  final String? productImage;
  final String lastMessage;
  final String lastSenderId;
  final DateTime lastAt;
  final Map<String, int> unread;

  const Conversation({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.productId,
    required this.productTitle,
    this.productImage,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastAt,
    required this.unread,
  });

  String otherName(String myId) => myId == buyerId ? sellerName : buyerName;
  String otherId(String myId) => myId == buyerId ? sellerId : buyerId;
  int unreadFor(String uid) => unread[uid] ?? 0;

  static String idFor(String productId, String buyerId) => '${productId}_$buyerId';

  factory Conversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    final u = (j['unread'] as Map?) ?? const {};
    return Conversation(
      id: doc.id,
      buyerId: (j['buyerId'] ?? '') as String,
      buyerName: (j['buyerName'] ?? '') as String,
      sellerId: (j['sellerId'] ?? '') as String,
      sellerName: (j['sellerName'] ?? '') as String,
      productId: (j['productId'] ?? '') as String,
      productTitle: (j['productTitle'] ?? '') as String,
      productImage: j['productImage'] as String?,
      lastMessage: (j['lastMessage'] ?? '') as String,
      lastSenderId: (j['lastSenderId'] ?? '') as String,
      lastAt: tsToDate(j['lastAt']),
      unread: u.map((k, v) => MapEntry(k.toString(), toInt(v))),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime at;
  const ChatMessage({required this.id, required this.senderId, required this.text, required this.at});

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return ChatMessage(
      id: doc.id,
      senderId: (j['senderId'] ?? '') as String,
      text: (j['text'] ?? '') as String,
      // serverTimestamp is null in the local echo before the write lands.
      at: tsToDate(j['createdAt']),
    );
  }
}
