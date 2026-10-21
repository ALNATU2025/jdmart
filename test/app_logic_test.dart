import 'package:flutter_test/flutter_test.dart';
import 'package:jdmart/core/constants/catalog.dart';
import 'package:jdmart/core/utils/formatters.dart';
import 'package:jdmart/core/utils/keywords.dart';
import 'package:jdmart/data/models/cart_item.dart';
import 'package:jdmart/data/models/order.dart';
import 'package:jdmart/data/models/product.dart';

void main() {
  group('Sierra Leone phone numbers', () {
    test('validates local and international formats', () {
      expect(Fmt.validatePhone('076 123456'), isNull);
      expect(Fmt.validatePhone('+232 77 334455'), isNull);
      expect(Fmt.validatePhone('12345'), isNotNull);
      expect(Fmt.validatePhone(''), isNotNull);
    });

    test('formats for Firebase and for display', () {
      expect(Fmt.e164('076 123456'), '+23276123456');
      expect(Fmt.display('+23276123456'), '+232 76 123456');
    });
  });

  test('Leone price formatting', () {
    expect(Fmt.price(3850), 'Le 3,850');
    expect(Fmt.price(12.5), 'Le 12.50');
  });

  test('search keywords include word prefixes', () {
    final k = Keywords.build(['Tecno Spark 20', 'Phones & Tablets']);
    expect(k, containsAll(['te', 'tec', 'tecno', 'spark', '20', 'phone', 'tablets']));
    expect(Keywords.tokens('Hand-dyed GARA!'), ['hand', 'dyed', 'gara']);
  });

  test('discount percent', () {
    expect(Product.discountOf(3850, 4300), 10);
    expect(Product.discountOf(100, null), 0);
    expect(Product.discountOf(100, 90), 0);
  });

  test('cart item survives a JSON round trip', () {
    final i = CartItem(
      productId: 'p1',
      quantity: 2,
      title: 'Rice 50kg',
      price: 1150,
      categoryId: 'groceries',
      sellerId: 's1',
      sellerName: 'Shop',
      stock: 10,
    );
    final back = CartItem.fromJson(i.toJson());
    expect(back.total, 2300);
    expect(back.sellerId, 's1');
  });

  test('order status moves forward in order', () {
    expect(OrderStatus.pending.next, OrderStatus.confirmed);
    expect(OrderStatus.shipped.next, OrderStatus.delivered);
    expect(OrderStatus.delivered.next, isNull);
    expect(paymentStatusFrom('refund_due'), PaymentStatus.refundDue);
  });

  test('delivery fees cover every town', () {
    for (final c in Catalog.cities) {
      expect(Catalog.deliveryFee(c), greaterThan(0));
    }
    expect(Catalog.safeCity('Atlantis'), 'Freetown');
  });
}
