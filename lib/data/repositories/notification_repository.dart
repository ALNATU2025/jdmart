import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';

/// In-app notifications for a user, and the admin activity feed.
class NotificationRepository {
  NotificationRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watch(String uid) => _col(uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  Stream<int> unreadCount(String uid) =>
      _col(uid).where('read', isEqualTo: false).limit(99).snapshots().map((s) => s.size);

  Future<void> markRead(String uid, String id) => _col(uid).doc(id).update({'read': true});

  Future<void> markAllRead(String uid) async {
    final unread = await _col(uid).where('read', isEqualTo: false).limit(400).get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();

  Future<void> clearAll(String uid) async {
    final all = await _col(uid).limit(400).get();
    final batch = _db.batch();
    for (final d in all.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /// Admins: everything happening in the app.
  Stream<List<AppNotification>> adminFeed({int limit = 200}) => _db
      .collection('adminFeed')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());
}
