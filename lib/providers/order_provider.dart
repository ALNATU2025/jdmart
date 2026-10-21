import 'package:flutter/foundation.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import 'cart_provider.dart';
import 'product_provider.dart';

class OrderProvider extends ChangeNotifier {
  static const _key = 'orders';
  final List<Order> _orders = [];

  void load() {
    _orders
      ..clear()
      ..addAll(StorageService.readList(_key).map(Order.fromJson));
  }

  Future<void> _save() => StorageService.writeList(_key, _orders.map((o) => o.toJson()).toList());

  Order? byId(String id) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  List<Order> forBuyer(String userId) =>
      _orders.where((o) => o.buyerId == userId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Orders that contain at least one item sold by [sellerId].
  List<Order> forSeller(String sellerId) =>
      _orders.where((o) => o.items.any((i) => i.sellerId == sellerId)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  double sellerRevenue(String sellerId) => _orders
      .where((o) => o.status != OrderStatus.cancelled)
      .expand((o) => o.items)
      .where((i) => i.sellerId == sellerId)
      .fold(0.0, (s, i) => s + i.total);

  Future<Order> placeOrder({
    required AppUser buyer,
    required CartProvider cart,
    required ProductProvider products,
    required String paymentMethod,
    required String address,
    required String city,
    required String phone,
    String note = '',
  }) async {
    // Simulate a payment gateway round-trip (Orange Money / Afrimoney / card).
    await Future.delayed(const Duration(milliseconds: 1400));

    final items = <OrderItem>[];
    final qty = <String, int>{};
    for (final c in cart.items) {
      final p = products.byId(c.productId);
      if (p == null) continue;
      items.add(OrderItem(
        productId: p.id,
        title: p.title,
        price: p.price,
        quantity: c.quantity,
        sellerId: p.sellerId,
        sellerName: p.sellerName,
        categoryId: p.categoryId,
        image: p.images.isEmpty ? null : p.images.first,
      ));
      qty[p.id] = c.quantity;
    }
    final subtotal = items.fold(0.0, (s, i) => s + i.total);
    final order = Order(
      id: 'JD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      buyerId: buyer.id,
      buyerName: buyer.name,
      items: items,
      subtotal: subtotal,
      deliveryFee: SeedData.deliveryFees[city] ?? 100.0,
      paymentMethod: paymentMethod,
      address: address,
      city: city,
      phone: phone,
      note: note,
      status: paymentMethod == 'cod' ? OrderStatus.pending : OrderStatus.confirmed,
    );
    _orders.add(order);
    await products.reduceStock(qty);
    cart.clear();
    await _save();
    notifyListeners();
    return order;
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    final o = byId(orderId);
    if (o == null) return;
    o.status = status;
    await _save();
    notifyListeners();
  }
}
