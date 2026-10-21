import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

/// products/{productId}/reviews/{userId} — one review per buyer, and only
/// buyers with a delivered order for the product may write one (see rules).
class Review {
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime at;

  const Review({
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.at,
  });

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return Review(
      userId: doc.id,
      userName: (j['userName'] ?? '') as String,
      rating: toInt(j['rating'], 5),
      comment: (j['comment'] ?? '') as String,
      at: tsToDate(j['createdAt']),
    );
  }
}
