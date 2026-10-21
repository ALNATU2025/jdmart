import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

/// banners/{id} — promotional slides on the home screen, managed by admins in
/// the Firebase console. The carousel is hidden when there are none.
class PromoBanner {
  final String id;
  final String title;
  final String subtitle;
  final String? categoryId;
  final String? imageUrl;
  final int order;

  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    this.categoryId,
    this.imageUrl,
    required this.order,
  });

  factory PromoBanner.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return PromoBanner(
      id: doc.id,
      title: (j['title'] ?? '') as String,
      subtitle: (j['subtitle'] ?? '') as String,
      categoryId: j['categoryId'] as String?,
      imageUrl: j['imageUrl'] as String?,
      order: toInt(j['order']),
    );
  }
}
