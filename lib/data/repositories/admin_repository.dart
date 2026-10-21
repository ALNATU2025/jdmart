import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/firestore_helpers.dart';
import '../models/models.dart';

/// A reported listing (reports/{id}).
class Report {
  final String id;
  final String productId;
  final String reporterId;
  final String reason;
  final String status;
  final DateTime createdAt;
  const Report(this.id, this.productId, this.reporterId, this.reason, this.status, this.createdAt);

  bool get isOpen => status != 'closed';

  factory Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data() ?? const {};
    return Report(
      d.id,
      (j['productId'] ?? '') as String,
      (j['reporterId'] ?? '') as String,
      (j['reason'] ?? '') as String,
      (j['status'] ?? 'open') as String,
      tsToDate(j['createdAt']),
    );
  }
}

/// A banner as admins see it (including inactive ones).
class AdminBanner {
  final String id;
  final String title;
  final String subtitle;
  final String? categoryId;
  final String? imageUrl;
  final int order;
  final bool active;
  const AdminBanner(this.id, this.title, this.subtitle, this.categoryId, this.imageUrl, this.order, this.active);

  factory AdminBanner.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data() ?? const {};
    return AdminBanner(
      d.id,
      (j['title'] ?? '') as String,
      (j['subtitle'] ?? '') as String,
      j['categoryId'] as String?,
      j['imageUrl'] as String?,
      toInt(j['order']),
      j['active'] == true,
    );
  }
}

/// Dashboard numbers.
class AdminStats {
  final int users;
  final int listings;
  final int orders;
  final int openJobs;
  final int talent;
  final int openReports;
  const AdminStats(this.users, this.listings, this.orders, this.openJobs, this.talent, this.openReports);
}

/// Everything the admin console reads and writes. Firestore rules only allow
/// these operations for accounts with the `admin` claim (set at sign-in by the
/// verifyLoginCode function for the super admin and for emails in admins/).
class AdminRepository {
  AdminRepository(this._db, this._functions, this._storage);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  Future<int> _count(Query<Map<String, dynamic>> q) async => (await q.count().get()).count ?? 0;

  Future<AdminStats> stats() async {
    final r = await Future.wait([
      _count(_db.collection('users')),
      _count(_db.collection('products')),
      _count(_db.collection('orders')),
      _count(_db.collection('jobs').where('status', isEqualTo: 'open')),
      _count(_db.collection('talent').where('visible', isEqualTo: true)),
      _count(_db.collection('reports').where('status', isEqualTo: 'open')),
    ]);
    return AdminStats(r[0], r[1], r[2], r[3], r[4], r[5]);
  }

  // ---- Listings ------------------------------------------------------------------
  Stream<List<Product>> products() => _db
      .collection('products')
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(Product.fromDoc).toList());

  Future<Product?> product(String id) async {
    final d = await _db.collection('products').doc(id).get();
    return d.exists ? Product.fromDoc(d) : null;
  }

  Future<void> setProductStatus(String id, String status) =>
      _db.collection('products').doc(id).update({'status': status});

  Future<void> setFeatured(String id, bool featured) =>
      _db.collection('products').doc(id).update({'featured': featured});

  Future<void> deleteProduct(String id) => _db.collection('products').doc(id).delete();

  // ---- Reports ---------------------------------------------------------------------
  Stream<List<Report>> reports() => _db
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Report.fromDoc).toList());

  Future<void> closeReport(String id) => _db.collection('reports').doc(id).update({'status': 'closed'});

  // ---- Users --------------------------------------------------------------------------
  Stream<List<AppUser>> users() => _db
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  /// Phone and email of a user (admins may read private data).
  Future<Map<String, dynamic>> privateOf(String uid) async =>
      (await _db.collection('users').doc(uid).collection('private').doc('account').get()).data() ?? const {};

  Future<bool> isSuspended(String uid) async =>
      (await _db.collection('users').doc(uid).get()).data()?['suspended'] == true;

  Future<void> setVerified(String uid, bool verified) =>
      _db.collection('users').doc(uid).update({'verified': verified});

  /// Suspends (disables sign-in) or restores a user. Done on the server.
  Future<void> setSuspended(String uid, bool suspended) =>
      _call('adminSetUserDisabled', {'uid': uid, 'disabled': suspended});

  // ---- Orders -----------------------------------------------------------------------------
  Stream<List<Order>> orders() => _db
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Order.fromDoc).toList());

  // ---- Jobs and talent --------------------------------------------------------------------
  Stream<List<Job>> jobs() => _db
      .collection('jobs')
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(Job.fromDoc).toList());

  Future<void> setJobStatus(String id, String status) => _db.collection('jobs').doc(id).update({'status': status});

  Future<void> deleteJob(String id) => _db.collection('jobs').doc(id).delete();

  Stream<List<TalentProfile>> talent() => _db
      .collection('talent')
      .orderBy('updatedAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(TalentProfile.fromDoc).toList());

  Future<void> deleteTalent(String uid) => _db.collection('talent').doc(uid).delete();

  // ---- Banners ----------------------------------------------------------------------------
  Stream<List<AdminBanner>> banners() => _db
      .collection('banners')
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(AdminBanner.fromDoc).toList());

  Future<void> addBanner({
    required String title,
    required String subtitle,
    String? categoryId,
    String? imageUrl,
    required int order,
  }) =>
      _db.collection('banners').add({
        'title': title.trim(),
        'subtitle': subtitle.trim(),
        'categoryId': categoryId,
        'imageUrl': imageUrl,
        'order': order,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> setBannerActive(String id, bool active) =>
      _db.collection('banners').doc(id).update({'active': active});

  Future<void> deleteBanner(String id) => _db.collection('banners').doc(id).delete();

  Future<String> uploadBannerImage(Uint8List bytes) async {
    final ref = _storage.ref().child('banners/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg', cacheControl: 'public,max-age=604800'));
    return ref.getDownloadURL();
  }

  // ---- Admin team (super admin only) --------------------------------------------------------
  Stream<List<String>> adminEmails() =>
      _db.collection('admins').snapshots().map((s) => s.docs.map((d) => d.id).toList()..sort());

  Future<void> setAdmin(String email, bool admin) =>
      _call('adminSetRole', {'email': email.trim().toLowerCase(), 'admin': admin});

  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(name).call<dynamic>(data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Something went wrong (${e.code}).');
    }
  }
}
