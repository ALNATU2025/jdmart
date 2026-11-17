import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/sponsored_ad.dart';

/// Paid ads ("sponsored" listings) and their settings.
class AdRepository {
  AdRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _ads => _db.collection('ads');
  DocumentReference<Map<String, dynamic>> get _settings => _db.collection('config').doc('ads');

  Stream<AdSettings> settings() =>
      _settings.snapshots().map((d) => AdSettings.fromMap(d.data())).handleError((Object _) => AdSettings.defaults);

  Future<AdSettings> settingsOnce() async {
    try {
      return AdSettings.fromMap((await _settings.get()).data());
    } catch (_) {
      return AdSettings.defaults;
    }
  }

  Future<void> saveSettings(AdSettings s) => _settings.set(s.toMap());

  static List<SponsoredAd> _liveOnly(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(SponsoredAd.fromDoc).where((a) => a.isLive).toList()
      ..sort((a, b) => (b.startsAt ?? b.createdAt).compareTo(a.startsAt ?? a.createdAt));
    return list;
  }

  /// Ads running right now — every user sees the same ones.
  Stream<List<SponsoredAd>> live() => _ads.where('status', isEqualTo: 'active').limit(60).snapshots().map(_liveOnly);

  Future<List<SponsoredAd>> liveOnce() async {
    try {
      return _liveOnly(await _ads.where('status', isEqualTo: 'active').limit(60).get());
    } catch (_) {
      return const [];
    }
  }

  Stream<List<SponsoredAd>> mine(String uid) => _ads.where('sellerId', isEqualTo: uid).limit(100).snapshots().map(
      (s) => s.docs.map(SponsoredAd.fromDoc).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// Seller asks to advertise [p]; an admin approves it after checking payment.
  Future<void> request({
    required Product p,
    required AdPackage package,
    required String payMethod,
    required String payPhone,
    required String payRef,
  }) =>
      _ads.add({
        'productId': p.id,
        'sellerId': p.sellerId,
        'sellerName': p.sellerName,
        'title': p.title,
        'imageUrl': p.cover,
        'price': p.price,
        'oldPrice': p.oldPrice,
        'city': p.city,
        'days': package.days,
        'amount': package.price,
        'payMethod': payMethod,
        'payPhone': payPhone,
        'payRef': payRef.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> cancel(String id) => _ads.doc(id).update({'status': 'cancelled'});

  // ---- Admins ----------------------------------------------------------------
  Stream<List<SponsoredAd>> all({int limit = 150}) => _ads
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(SponsoredAd.fromDoc).toList());

  /// Starts the ad now (or right after the same listing's current ad ends).
  Future<void> approve(SponsoredAd ad, String adminUid) async {
    final now = DateTime.now();
    var start = now;
    final running = await _ads.where('status', isEqualTo: 'active').where('productId', isEqualTo: ad.productId).get();
    for (final d in running.docs) {
      final other = SponsoredAd.fromDoc(d);
      if (other.id != ad.id && other.endsAt != null && other.endsAt!.isAfter(start)) start = other.endsAt!;
    }
    await _ads.doc(ad.id).update({
      'status': 'active',
      'startsAt': Timestamp.fromDate(start),
      'endsAt': Timestamp.fromDate(start.add(Duration(days: ad.days))),
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'note': '',
    });
  }

  Future<void> reject(SponsoredAd ad, String note) => _ads.doc(ad.id).update({'status': 'rejected', 'note': note.trim()});

  Future<void> stop(SponsoredAd ad) => _ads.doc(ad.id).update({'status': 'ended', 'endsAt': Timestamp.now()});
}
