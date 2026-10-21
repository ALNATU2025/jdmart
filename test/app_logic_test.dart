import 'package:flutter_test/flutter_test.dart';
import 'package:jdmart/models/models.dart';
import 'package:jdmart/providers/auth_provider.dart';
import 'package:jdmart/providers/cart_provider.dart';
import 'package:jdmart/providers/order_provider.dart';
import 'package:jdmart/providers/product_provider.dart';
import 'package:jdmart/services/storage_service.dart';
import 'package:jdmart/utils/formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('Sierra Leone phone validation', () {
    expect(Fmt.validatePhone('076 123456'), isNull);
    expect(Fmt.validatePhone('+232 77 334455'), isNull);
    expect(Fmt.validatePhone('12345'), isNotNull);
    expect(Fmt.normalizePhone('076123456'), '+232 76 123456');
  });

  test('Leone price formatting', () {
    expect(Fmt.price(3850), 'Le 3,850');
    expect(Fmt.price(12.5), 'Le 12.50');
  });

  test('register, add to cart, checkout reduces stock and creates sale for seller', () async {
    final auth = AuthProvider()..load();
    final products = ProductProvider()..load();
    final cart = CartProvider()..load();
    final orders = OrderProvider()..load();

    expect(await auth.register(
        name: 'Test Buyer', phone: '+232 75 111222', email: '', password: 'secret1', city: 'Bo'), isNull);

    final phone = products.byId('p1')!;
    final startStock = phone.stock;
    expect(cart.add(phone, qty: 2), isTrue);
    expect(cart.add(phone, qty: 999), isFalse); // more than stock
    expect(cart.subtotal(products), phone.price * 2);

    final order = await orders.placeOrder(
      buyer: auth.user!,
      cart: cart,
      products: products,
      paymentMethod: 'orange',
      address: 'Tikonko Road',
      city: 'Bo',
      phone: auth.user!.phone,
    );

    expect(order.deliveryFee, 100);
    expect(order.total, phone.price * 2 + 100);
    expect(order.status, OrderStatus.confirmed);
    expect(products.byId('p1')!.stock, startStock - 2);
    expect(cart.isEmpty, isTrue);
    expect(orders.forSeller('seller_kamara').length, 1);
    expect(orders.forBuyer(auth.user!.id).length, 1);
  });

  test('login works with local phone format', () async {
    final auth = AuthProvider()..load();
    expect(await auth.login('076123456', 'seller123'), isNull);
    expect(auth.user!.id, 'seller_kamara');
    expect(await auth.login('076123456', 'wrong'), isNotNull);
  });
}
