import 'package:flutter/foundation.dart';
import '../data/models/cart_item.dart';
import '../data/models/product.dart';
import '../data/repositories/product_repository.dart';
import '../data/services/local_store.dart';

/// The shopping cart, stored on the device per user (guests have their own
/// cart, which is merged into the account cart when they sign in).
class CartProvider extends ChangeNotifier {
  CartProvider(this._products);
  final ProductRepository _products;

  static const _guestKey = 'cart_guest';
  String _key = _guestKey;
  String? _uid;
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  List<CartItem> get availableItems => _items.where((i) => i.available && i.stock > 0).toList();
  int get count => _items.fold(0, (s, i) => s + i.quantity);
  bool get isEmpty => _items.isEmpty;

  double get subtotal => availableItems.fold(0.0, (s, i) => s + i.total);
  double get savings => availableItems.fold(0.0, (s, i) {
        final old = i.oldPrice;
        return (old == null || old <= i.price) ? s : s + (old - i.price) * i.quantity;
      });

  /// Called whenever the signed-in user changes.
  bool _bound = false;

  void bindUser(String? uid) {
    if (_bound && uid == _uid) return;
    _bound = true;
    final guest = uid != null && _uid == null
        ? LocalStore.readList(_guestKey).map(CartItem.fromJson).toList()
        : <CartItem>[];
    _uid = uid;
    _key = uid == null ? _guestKey : 'cart_$uid';
    _items
      ..clear()
      ..addAll(LocalStore.readList(_key).map(CartItem.fromJson));
    if (guest.isNotEmpty) {
      for (final g in guest) {
        final i = _items.indexWhere((x) => x.productId == g.productId);
        if (i < 0) _items.add(g);
      }
      LocalStore.remove(_guestKey);
      _save();
    }
    // Your own listings can't be in your cart.
    if (uid != null) _items.removeWhere((i) => i.sellerId == uid);
    notifyListeners();
  }

  void _save() => LocalStore.writeList(_key, _items.map((i) => i.toJson()).toList());

  int quantityOf(String productId) {
    for (final i in _items) {
      if (i.productId == productId) return i.quantity;
    }
    return 0;
  }

  /// Returns an error message, or null when added.
  String? add(Product p, {int qty = 1}) {
    if (p.sellerId == _uid) return "You can't buy your own listing";
    if (!p.available) return 'This item is no longer available';
    final current = quantityOf(p.id);
    if (current + qty > p.stock) return 'Only ${p.stock} in stock';
    final i = _items.indexWhere((x) => x.productId == p.id);
    if (i < 0) {
      _items.add(CartItem.fromProduct(p, qty));
    } else {
      _items[i]
        ..refreshFrom(p)
        ..quantity += qty;
    }
    _save();
    notifyListeners();
    return null;
  }

  void setQuantity(String productId, int qty) {
    final i = _items.indexWhere((x) => x.productId == productId);
    if (i < 0) return;
    if (qty <= 0) {
      _items.removeAt(i);
    } else {
      _items[i].quantity = qty > _items[i].stock ? _items[i].stock : qty;
    }
    _save();
    notifyListeners();
  }

  void remove(String productId) => setQuantity(productId, 0);

  void removeAll(Iterable<String> productIds) {
    final ids = productIds.toSet();
    _items.removeWhere((i) => ids.contains(i.productId));
    _save();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _save();
    notifyListeners();
  }

  /// Re-reads prices and stock from the server (when the cart opens).
  Future<void> refresh() async {
    if (_items.isEmpty) return;
    final latest = await _products.getMany(_items.map((i) => i.productId));
    for (final i in _items) {
      final p = latest[i.productId];
      if (p == null) {
        i.available = false;
      } else {
        i.refreshFrom(p);
      }
    }
    _save();
    notifyListeners();
  }
}
