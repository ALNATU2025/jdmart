import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

enum OrderStatus { pending, confirmed, shipped, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.shipped => 'On the way',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  OrderStatus? get next => switch (this) {
        OrderStatus.pending => OrderStatus.confirmed,
        OrderStatus.confirmed => OrderStatus.shipped,
        OrderStatus.shipped => OrderStatus.delivered,
        _ => null,
      };
}

/// unpaid: online payment not completed yet (stock is held for 30 minutes)
/// paid: confirmed by Monime, or cash collected on delivery
/// cod: cash on delivery, not yet collected
/// refund_due: cancelled after payment — refund the buyer from the Monime dashboard
enum PaymentStatus { unpaid, paid, cod, refundDue }

PaymentStatus paymentStatusFrom(String? s) => switch (s) {
      'paid' => PaymentStatus.paid,
      'cod' => PaymentStatus.cod,
      'refund_due' => PaymentStatus.refundDue,
      _ => PaymentStatus.unpaid,
    };

class OrderItem {
  final String productId;
  final String title;
  final double price;
  final int quantity;
  final String categoryId;
  final String? image;

  const OrderItem({
    required this.productId,
    required this.title,
    required this.price,
    required this.quantity,
    required this.categoryId,
    this.image,
  });

  double get total => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> j) => OrderItem(
        productId: (j['productId'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        price: toDouble(j['price']),
        quantity: toInt(j['quantity'], 1),
        categoryId: (j['categoryId'] ?? 'other') as String,
        image: j['image'] as String?,
      );
}

/// orders/{orderId}. One order per seller — a cart with items from two sellers
/// becomes two orders sharing a [checkoutId]. Created and updated only by
/// Cloud Functions, so totals and stock can't be tampered with.
class Order {
  final String id;
  final String checkoutId;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String paymentMethod; // 'online' | 'cod'
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final String address;
  final String city;
  final String phone;
  final String note;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.checkoutId,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.address,
    required this.city,
    required this.phone,
    required this.note,
    required this.createdAt,
  });

  int get itemCount => items.fold(0, (s, i) => s + i.quantity);
  String get shortId => id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  bool get isOpen => status != OrderStatus.delivered && status != OrderStatus.cancelled;

  factory Order.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return Order(
      id: doc.id,
      checkoutId: (j['checkoutId'] ?? '') as String,
      buyerId: (j['buyerId'] ?? '') as String,
      buyerName: (j['buyerName'] ?? '') as String,
      sellerId: (j['sellerId'] ?? '') as String,
      sellerName: (j['sellerName'] ?? '') as String,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: toDouble(j['subtotal']),
      deliveryFee: toDouble(j['deliveryFee']),
      total: toDouble(j['total']),
      paymentMethod: (j['paymentMethod'] ?? 'cod') as String,
      paymentStatus: paymentStatusFrom(j['paymentStatus'] as String?),
      status: OrderStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => OrderStatus.pending),
      address: (j['address'] ?? '') as String,
      city: (j['city'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
      note: (j['note'] ?? '') as String,
      createdAt: tsToDate(j['createdAt']),
    );
  }
}

/// checkouts/{checkoutId} — groups the orders of one checkout and tracks payment.
class Checkout {
  final String id;
  final String status; // awaiting_payment | paid | cod | expired | cancelled
  final double total;
  final List<String> orderIds;
  final String? redirectUrl;

  const Checkout({
    required this.id,
    required this.status,
    required this.total,
    required this.orderIds,
    this.redirectUrl,
  });

  factory Checkout.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return Checkout(
      id: doc.id,
      status: (j['status'] ?? 'awaiting_payment') as String,
      total: toDouble(j['total']),
      orderIds: toStringList(j['orderIds']),
      redirectUrl: j['redirectUrl'] as String?,
    );
  }
}
