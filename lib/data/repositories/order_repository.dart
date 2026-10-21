import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import '../models/cart_item.dart';
import '../models/order.dart';

class PlaceOrderResult {
  final String checkoutId;
  final List<String> orderIds;
  final double total;
  final String? paymentUrl; // Monime checkout page for online payments
  const PlaceOrderResult({required this.checkoutId, required this.orderIds, required this.total, this.paymentUrl});
}

/// Orders are created and changed only through Cloud Functions, which check
/// stock and prices on the server. The app just reads them.
class OrderRepository {
  OrderRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('orders');

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final r = await _functions.httpsCallable(name).call<dynamic>(data);
      return Map<String, dynamic>.from((r.data as Map?) ?? const {});
    } on FirebaseFunctionsException catch (e) {
      throw OrderException(e.message ?? 'Something went wrong (${e.code}).');
    }
  }

  Future<PlaceOrderResult> placeOrder({
    required List<CartItem> items,
    required String paymentMethod, // 'online' | 'cod'
    required String address,
    required String city,
    required String phone,
    String note = '',
  }) async {
    final r = await _call('placeOrder', {
      'items': items.map((i) => {'productId': i.productId, 'quantity': i.quantity}).toList(),
      'paymentMethod': paymentMethod,
      'address': address,
      'city': city,
      'phone': phone,
      'note': note,
    });
    return PlaceOrderResult(
      checkoutId: r['checkoutId'] as String,
      orderIds: ((r['orderIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
      total: (r['total'] as num?)?.toDouble() ?? 0,
      paymentUrl: r['paymentUrl'] as String?,
    );
  }

  /// Asks the server to check the payment with Monime. Returns the checkout status.
  Future<String> confirmPayment(String checkoutId) async =>
      (await _call('confirmPayment', {'checkoutId': checkoutId}))['status'] as String? ?? 'awaiting_payment';

  Future<void> cancelOrder(String orderId, {String reason = ''}) =>
      _call('cancelOrder', {'orderId': orderId, 'reason': reason});

  Future<void> updateStatus(String orderId, OrderStatus status) =>
      _call('updateOrderStatus', {'orderId': orderId, 'status': status.name});

  Stream<List<Order>> forBuyer(String uid) => _col
      .where('buyerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Order.fromDoc).toList());

  Stream<List<Order>> forSeller(String uid) => _col
      .where('sellerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Order.fromDoc).toList());

  Stream<Order?> watch(String id) => _col.doc(id).snapshots().map((d) => d.exists ? Order.fromDoc(d) : null);

  Stream<Checkout?> watchCheckout(String id) =>
      _db.collection('checkouts').doc(id).snapshots().map((d) => d.exists ? Checkout.fromDoc(d) : null);

  /// Delivered-order earnings, maintained by Cloud Functions.
  Stream<Map<String, dynamic>> sellerStats(String uid) =>
      _db.collection('sellerStats').doc(uid).snapshots().map((d) => d.data() ?? const {});
}

class OrderException implements Exception {
  final String message;
  OrderException(this.message);
  @override
  String toString() => message;
}
