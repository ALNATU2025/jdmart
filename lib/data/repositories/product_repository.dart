import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/keywords.dart';
import '../models/product.dart';
import '../models/review.dart';

enum SortBy { newest, priceLow, priceHigh, popular }

class SearchFilters {
  final String query;
  final String? categoryId;
  final String? city;
  final String? condition;
  final double? minPrice;
  final double? maxPrice;
  final SortBy sort;

  const SearchFilters({
    this.query = '',
    this.categoryId,
    this.city,
    this.condition,
    this.minPrice,
    this.maxPrice,
    this.sort = SortBy.newest,
  });
}

/// products/{id} and products/{id}/reviews/{uid}
class ProductRepository {
  ProductRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('products');
  Query<Map<String, dynamic>> get _active => _col.where('status', isEqualTo: 'active');

  List<Product> _map(QuerySnapshot<Map<String, dynamic>> s) => s.docs.map(Product.fromDoc).toList();

  /// A new document id, so photos can be uploaded before the listing is saved.
  String newId() => _col.doc().id;

  // ---- Feeds ------------------------------------------------------------------
  Stream<List<Product>> newest({int limit = 20}) =>
      _active.orderBy('createdAt', descending: true).limit(limit).snapshots().map(_map);

  Stream<List<Product>> featured({int limit = 10}) => _active
      .where('featured', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_map);

  Stream<List<Product>> deals({int limit = 10}) => _active
      .where('discountPercent', isGreaterThan: 0)
      .orderBy('discountPercent', descending: true)
      .limit(limit)
      .snapshots()
      .map(_map);

  Stream<List<Product>> byCategory(String categoryId, {int limit = 8}) => _active
      .where('categoryId', isEqualTo: categoryId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_map);

  /// Public listings of a seller.
  Stream<List<Product>> activeBySeller(String sellerId) => _active
      .where('sellerId', isEqualTo: sellerId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(_map);

  /// All of my own listings, including sold and hidden ones.
  Stream<List<Product>> mine(String uid) => _col
      .where('sellerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map(_map);

  Stream<Product?> watch(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? Product.fromDoc(d) : null);

  Future<Product?> get(String id) async {
    try {
      final d = await _col.doc(id).get();
      return d.exists ? Product.fromDoc(d) : null;
    } on FirebaseException {
      return null; // hidden listing of another seller
    }
  }

  Future<Map<String, Product>> getMany(Iterable<String> ids) async {
    final list = await Future.wait(ids.toSet().map(get));
    return {for (final p in list.whereType<Product>()) p.id: p};
  }

  /// Firestore can't do full-text search: we fetch candidates by one keyword
  /// (or category) and apply the remaining filters on the device.
  Future<List<Product>> search(SearchFilters f) async {
    final words = Keywords.tokens(f.query);
    Query<Map<String, dynamic>> q = _active;
    if (words.isNotEmpty) {
      final longest = words.reduce((a, b) => a.length >= b.length ? a : b);
      q = q.where('keywords', arrayContains: longest.length > 15 ? longest.substring(0, 15) : longest);
    } else if (f.categoryId != null) {
      q = q.where('categoryId', isEqualTo: f.categoryId);
    }
    final snap = await q.orderBy('createdAt', descending: true).limit(150).get();
    var list = _map(snap).where((p) {
      if (f.categoryId != null && p.categoryId != f.categoryId) return false;
      if (f.city != null && p.city != f.city) return false;
      if (f.condition != null && p.condition != f.condition) return false;
      if (f.minPrice != null && p.price < f.minPrice!) return false;
      if (f.maxPrice != null && p.price > f.maxPrice!) return false;
      final hay = '${p.title} ${p.description}'.toLowerCase();
      return words.every((w) => hay.contains(w));
    }).toList();
    switch (f.sort) {
      case SortBy.newest:
        break; // already ordered by the query
      case SortBy.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case SortBy.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case SortBy.popular:
        list.sort((a, b) => b.views.compareTo(a.views));
    }
    return list;
  }

  // ---- Seller actions -----------------------------------------------------------
  Future<void> create({
    required String id,
    required String sellerId,
    required String sellerName,
    required bool sellerVerified,
    required ProductDraft draft,
  }) =>
      _col.doc(id).set({
        ...draft.toMap(),
        'sellerId': sellerId,
        'sellerName': sellerName,
        'sellerVerified': sellerVerified,
        'status': 'active',
        'featured': false,
        'views': 0,
        'ratingAvg': 0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> update(String id, ProductDraft draft, {bool reactivate = false}) => _col.doc(id).update({
        ...draft.toMap(),
        if (reactivate) 'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setStatus(String id, ProductStatus status) =>
      _col.doc(id).update({'status': status.name, 'updatedAt': FieldValue.serverTimestamp()});

  /// Photos are removed by the onProductDeleted Cloud Function.
  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> registerView(String id) async {
    try {
      await _col.doc(id).update({'views': FieldValue.increment(1)});
    } catch (_) {
      // Non-critical (e.g. offline or not signed in).
    }
  }

  // ---- Reviews ------------------------------------------------------------------
  Stream<List<Review>> reviews(String productId, {int limit = 20}) => _col
      .doc(productId)
      .collection('reviews')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Review.fromDoc).toList());

  /// Only buyers with a delivered order may review (recorded by Cloud Functions).
  Future<bool> canReview(String uid, String productId) async {
    final d = await _db.collection('users').doc(uid).collection('purchases').doc(productId).get();
    return d.exists;
  }

  Future<void> submitReview({
    required String productId,
    required String uid,
    required String userName,
    required int rating,
    required String comment,
  }) =>
      _col.doc(productId).collection('reviews').doc(uid).set({
        'userName': userName,
        'rating': rating,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  // ---- Safety -------------------------------------------------------------------
  Future<void> report({required String productId, required String uid, required String reason}) =>
      _db.collection('reports').add({
        'productId': productId,
        'reporterId': uid,
        'reason': reason,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
}
