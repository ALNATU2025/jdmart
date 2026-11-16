import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/upload_service.dart';
import 'package:image_picker/image_picker.dart';
import '../models/promo_banner.dart';

/// users/{uid}/wishlist/{productId}
class WishlistRepository {
  WishlistRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('wishlist');

  Stream<Set<String>> ids(String uid) => _col(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());

  Future<void> set(String uid, String productId, bool saved) => saved
      ? _col(uid).doc(productId).set({'createdAt': FieldValue.serverTimestamp()})
      : _col(uid).doc(productId).delete();
}

/// banners — home screen promos managed by admins in the Firebase console.
class BannerRepository {
  BannerRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<PromoBanner>> active() => _db
      .collection('banners')
      .where('active', isEqualTo: true)
      .orderBy('order')
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map(PromoBanner.fromDoc).toList());
}

/// Photo uploads (Cloudinary or Firebase Storage, see UploadService).
///   products/{uid}/{productId}/{timestamp}.jpg
///   avatars/{uid}/{timestamp}.jpg
class MediaRepository {
  MediaRepository(this._storage);
  final UploadService _storage;

  Future<String> _upload(String path, XFile file) async {
    final Uint8List bytes = await file.readAsBytes(); // works on mobile and web
    return _storage.upload(path: path, bytes: bytes);
  }

  String _stamp() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<String> uploadProductPhoto(String uid, String productId, XFile file) =>
      _upload('products/$uid/$productId/${_stamp()}.jpg', file);

  Future<String> uploadAvatar(String uid, XFile file) => _upload('avatars/$uid/${_stamp()}.jpg', file);

  Future<void> deleteByUrl(String url) => _storage.deleteByUrl(url);
}
