import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

/// users/{uid}/notifications/{id} and adminFeed/{id}
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // order | chat | job | delivery | product | report | talent | user | welcome | admin | info
  final Map<String, String> data;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    final raw = j['data'];
    return AppNotification(
      id: doc.id,
      title: (j['title'] ?? '') as String,
      body: (j['body'] ?? '') as String,
      type: (j['type'] ?? 'info') as String,
      data: raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
      read: j['read'] == true,
      createdAt: tsToDate(j['createdAt']),
    );
  }
}

/// broadcasts/{id} — "Send notification" messages from admins.
class Broadcast {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String audience; // all | city
  final String city;
  final String? productId;
  final String byName;
  final DateTime createdAt;
  final bool pushed; // sent to phones by the server

  const Broadcast({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.audience,
    required this.city,
    this.productId,
    required this.byName,
    required this.createdAt,
    required this.pushed,
  });

  bool reaches(String? userCity) => audience != 'city' || city.isEmpty || city == userCity;

  factory Broadcast.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    final img = j['imageUrl'];
    final pid = j['productId'];
    return Broadcast(
      id: doc.id,
      title: (j['title'] ?? '') as String,
      body: (j['body'] ?? '') as String,
      imageUrl: img is String && img.isNotEmpty ? img : null,
      audience: (j['audience'] ?? 'all') as String,
      city: (j['city'] ?? '') as String,
      productId: pid is String && pid.isNotEmpty ? pid : null,
      byName: (j['byName'] ?? '') as String,
      createdAt: tsToDate(j['createdAt']),
      pushed: j['sentAt'] != null,
    );
  }
}
