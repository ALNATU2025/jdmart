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
