import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/app_user.dart';

/// users/{uid}                 public profile (readable by everyone)
/// Phone numbers are stored in E.164 format (+23276123456); the security rules
/// only accept the user's own verified number as `contactPhone`.
/// users/{uid}/private/account phone, email, push tokens (owner + server only)
class UserRepository {
  UserRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _private(String uid) => _user(uid).collection('private').doc('account');

  Stream<AppUser?> watch(String uid) =>
      _user(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<AppUser?> get(String uid) async {
    final d = await _user(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  Future<Map<String, dynamic>> getPrivate(String uid) async =>
      (await _private(uid).get()).data() ?? const {};

  Future<void> createProfile({
    required String uid,
    required String name,
    required String city,
    required String phone,
    String email = '',
    bool showPhone = true,
  }) async {
    final batch = _db.batch();
    batch.set(_user(uid), {
      'name': name.trim(),
      'city': city,
      'bio': '',
      'avatarUrl': null,
      'contactPhone': showPhone ? phone : null,
      'verified': false,
      'ratingAvg': 0,
      'ratingCount': 0,
      'salesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_private(uid), {
      'phone': phone,
      'email': email.trim(),
      'showPhone': showPhone,
      'pushTokens': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    required String city,
    required String bio,
    required String email,
    required bool showPhone,
    required String phone,
    String? avatarUrl,
  }) async {
    final batch = _db.batch();
    batch.update(_user(uid), {
      'name': name.trim(),
      'city': city,
      'bio': bio.trim(),
      'contactPhone': showPhone ? phone : null,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    batch.set(_private(uid), {'email': email.trim(), 'showPhone': showPhone}, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> addPushToken(String uid, String token) => _private(uid).set({
        'pushTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));

  Future<void> removePushToken(String uid, String token) => _private(uid).set({
        'pushTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));

  /// Deletes the account and its data on the server (required by Google Play
  /// and the App Store for apps with sign-up).
  Future<void> deleteAccount() => _functions.httpsCallable('deleteAccount').call<dynamic>();
}
