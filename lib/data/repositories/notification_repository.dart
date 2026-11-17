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

  // ---- "Send notification" (admins) -----------------------------------------
  Stream<List<Broadcast>> broadcasts({int limit = 30}) => _db
      .collection('broadcasts')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Broadcast.fromDoc).toList());

  Future<void> sendBroadcast({
    required String title,
    required String body,
    String? imageUrl,
    required String audience,
    String city = '',
    String? productId,
    required String by,
    required String byName,
  }) =>
      _db.collection('broadcasts').add({
        'title': title.trim(),
        'body': body.trim(),
        'imageUrl': imageUrl,
        'audience': audience,
        'city': city,
        'productId': productId,
        'by': by,
        'byName': byName,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteBroadcast(String id) => _db.collection('broadcasts').doc(id).delete();

  /// True once the server (Cloud Functions) sends pushes; until then the app
  /// itself shows announcements as notifications.
  Stream<bool> serverPush() => _db
      .collection('config')
      .doc('notify')
      .snapshots()
      .map((d) => d.data()?['serverPush'] == true)
      .handleError((Object _) => false);

  Future<void> setServerPush(bool on) =>
      _db.collection('config').doc('notify').set({'serverPush': on}, SetOptions(merge: true));

  /// Admins: everything happening in the app.
  Stream<List<AppNotification>> adminFeed({int limit = 200}) => _db
      .collection('adminFeed')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());
}
