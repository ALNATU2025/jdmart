import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import 'product_provider.dart';

class CartProvider extends ChangeNotifier {
  static const _key = 'cart';
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get count => _items.fold(0, (s, i) => s + i.quantity);
  bool get isEmpty => _items.isEmpty;

  void load() {
    _items
      ..clear()
      ..addAll(StorageService.readList(_key).map(CartItem.fromJson));
  }

  void _save() => StorageService.writeList(_key, _items.map((i) => i.toJson()).toList());

  int quantityOf(String productId) {
    for (final i in _items) {
      if (i.productId == productId) return i.quantity;
    }
    return 0;
  }

  /// Returns false when the requested quantity exceeds stock.
  bool add(Product p, {int qty = 1}) {
    final existing = _items.where((i) => i.productId == p.id).toList();
    final current = existing.isEmpty ? 0 : existing.first.quantity;
    if (current + qty > p.stock) return false;
    if (existing.isEmpty) {
      _items.add(CartItem(productId: p.id, quantity: qty));
    } else {
      existing.first.quantity += qty;
    }
    _save();
    notifyListeners();
    return true;
  }

  void setQuantity(String productId, int qty) {
    final i = _items.indexWhere((x) => x.productId == productId);
    if (i < 0) return;
    if (qty <= 0) {
      _items.removeAt(i);
    } else {
      _items[i].quantity = qty;
    }
    _save();
    notifyListeners();
  }

  void remove(String productId) => setQuantity(productId, 0);

  void clear() {
    _items.clear();
    _save();
    notifyListeners();
  }

  /// Drops items whose product was deleted or sold out.
  void prune(ProductProvider products) {
    final before = _items.length;
    _items.removeWhere((i) {
      final p = products.byId(i.productId);
      return p == null || !p.available;
    });
    if (_items.length != before) {
      _save();
      notifyListeners();
    }
  }

  double subtotal(ProductProvider products) => _items.fold(0.0, (s, i) {
        final p = products.byId(i.productId);
        return p == null ? s : s + p.price * i.quantity;
      });

  double savings(ProductProvider products) => _items.fold(0.0, (s, i) {
        final p = products.byId(i.productId);
        if (p == null || p.oldPrice == null) return s;
        return s + (p.oldPrice! - p.price) * i.quantity;
      });
}
