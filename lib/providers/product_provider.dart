import 'package:flutter/foundation.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

enum SortBy { newest, priceLow, priceHigh, popular }

class ProductProvider extends ChangeNotifier {
  static const _productsKey = 'products';
  static const _wishKey = 'wishlist';
  static const _recentKey = 'recent_searches';

  final List<Product> _products = [];
  final Set<String> _wishlist = {};
  final List<String> _recentSearches = [];

  List<Product> get all => List.unmodifiable(_products);
  List<Product> get active => _products.where((p) => !p.isSold).toList();
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  void load() {
    final stored = StorageService.readList(_productsKey).map(Product.fromJson).toList();
    _products
      ..clear()
      ..addAll(StorageService.has(_productsKey) ? stored : SeedData.products());
    _wishlist
      ..clear()
      ..addAll(StorageService.getStringList(_wishKey));
    _recentSearches
      ..clear()
      ..addAll(StorageService.getStringList(_recentKey));
    _save();
  }

  Future<void> _save() =>
      StorageService.writeList(_productsKey, _products.map((p) => p.toJson()).toList());

  Product? byId(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Product> get featured => active.where((p) => p.featured).toList();

  List<Product> get deals =>
      active.where((p) => p.discountPercent > 0).toList()..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));

  List<Product> get newest => active.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Product> get popular => active.toList()..sort((a, b) => b.views.compareTo(a.views));

  List<Product> byCategory(String id) => active.where((p) => p.categoryId == id).toList();

  List<Product> bySeller(String sellerId, {bool includeSold = true}) =>
      _products.where((p) => p.sellerId == sellerId && (includeSold || !p.isSold)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Product> similar(Product p) =>
      active.where((x) => x.categoryId == p.categoryId && x.id != p.id).take(8).toList();

  List<Product> search({
    String query = '',
    String? categoryId,
    String? city,
    String? condition,
    double? minPrice,
    double? maxPrice,
    SortBy sort = SortBy.newest,
  }) {
    final q = query.trim().toLowerCase();
    var list = active.where((p) {
      if (q.isNotEmpty &&
          !p.title.toLowerCase().contains(q) &&
          !p.description.toLowerCase().contains(q) &&
          !SeedData.category(p.categoryId).name.toLowerCase().contains(q) &&
          !p.sellerName.toLowerCase().contains(q)) {
        return false;
      }
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (city != null && p.city != city) return false;
      if (condition != null && p.condition != condition) return false;
      if (minPrice != null && p.price < minPrice) return false;
      if (maxPrice != null && p.price > maxPrice) return false;
      return true;
    }).toList();
    switch (sort) {
      case SortBy.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortBy.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case SortBy.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case SortBy.popular:
        list.sort((a, b) => b.views.compareTo(a.views));
    }
    return list;
  }

  void addRecentSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    _recentSearches
      ..remove(t)
      ..insert(0, t);
    if (_recentSearches.length > 8) _recentSearches.removeLast();
    StorageService.setStringList(_recentKey, _recentSearches);
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    StorageService.setStringList(_recentKey, []);
    notifyListeners();
  }

  // ---- Seller actions ---------------------------------------------------------
  Future<Product> addProduct(Product p) async {
    _products.insert(0, p);
    await _save();
    notifyListeners();
    return p;
  }

  Future<void> updateProduct(Product p) async {
    final i = _products.indexWhere((x) => x.id == p.id);
    if (i >= 0) _products[i] = p;
    await _save();
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    _wishlist.remove(id);
    await StorageService.setStringList(_wishKey, _wishlist.toList());
    await _save();
    notifyListeners();
  }

  Future<void> toggleSold(String id) async {
    final p = byId(id);
    if (p == null) return;
    p.isSold = !p.isSold;
    await _save();
    notifyListeners();
  }

  void registerView(String id) {
    final p = byId(id);
    if (p == null) return;
    p.views++;
    _save();
  }

  Future<void> reduceStock(Map<String, int> qtyById) async {
    qtyById.forEach((id, q) {
      final p = byId(id);
      if (p != null) {
        p.stock = p.stock - q < 0 ? 0 : p.stock - q;
        if (p.stock == 0) p.isSold = true;
      }
    });
    await _save();
    notifyListeners();
  }

  Future<void> addReview(String productId, Review r) async {
    byId(productId)?.reviews.insert(0, r);
    await _save();
    notifyListeners();
  }

  // ---- Wishlist ---------------------------------------------------------------
  bool isWished(String id) => _wishlist.contains(id);

  List<Product> get wishlist => _products.where((p) => _wishlist.contains(p.id)).toList();

  void toggleWish(String id) {
    if (!_wishlist.remove(id)) _wishlist.add(id);
    StorageService.setStringList(_wishKey, _wishlist.toList());
    notifyListeners();
  }
}
