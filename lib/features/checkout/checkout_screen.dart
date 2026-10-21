import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/cart_item.dart';
import '../../data/repositories/order_repository.dart';
import '../../shared/widgets/common.dart';
import '../../state/cart_provider.dart';
import '../../state/session_provider.dart';
import 'order_success_screen.dart';
import 'payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _address = TextEditingController();
  final _note = TextEditingController();
  late String _city;
  PaymentOption _payment = AppConfig.onlinePaymentsEnabled ? PaymentOption.online : PaymentOption.cashOnDelivery;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionProvider>();
    _name = TextEditingController(text: s.profile?.name ?? '');
    _phone = TextEditingController(text: Fmt.display(s.phone));
    _city = Catalog.safeCity(s.profile?.city);
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  /// One delivery fee per seller: each seller ships their own items.
  Map<String, List<CartItem>> _bySeller(List<CartItem> items) {
    final m = <String, List<CartItem>>{};
    for (final i in items) {
      m.putIfAbsent(i.sellerId, () => []).add(i);
    }
    return m;
  }

  Future<void> _place(List<CartItem> items) async {
    if (!_form.currentState!.validate()) {
      showSnack(context, 'Please complete the delivery details', error: true);
      return;
    }
    setState(() => _placing = true);
    try {
      final r = await context.read<OrderRepository>().placeOrder(
            items: items,
            paymentMethod: _payment.id,
            address: _address.text.trim(),
            city: _city,
            phone: Fmt.display(_phone.text),
            note: [if (_name.text.trim().isNotEmpty) 'Receiver: ${_name.text.trim()}', _note.text.trim()]
                .where((e) => e.isNotEmpty)
                .join(' — '),
          );
      if (!mounted) return;
      context.read<CartProvider>().removeAll(items.map((i) => i.productId));
      final next = r.paymentUrl != null
          ? PaymentScreen(checkoutId: r.checkoutId, paymentUrl: r.paymentUrl!, total: r.total)
          : OrderSuccessScreen(checkoutId: r.checkoutId, orderIds: r.orderIds, total: r.total, paidOnline: false);
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => next), (route) => route.isFirst);
    } on OrderException catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      showSnack(context, e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      showSnack(context, "Couldn't place your order. Check your internet connection and try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.availableItems;
    final groups = _bySeller(items);
    final subtotal = cart.subtotal;
    final delivery = Catalog.deliveryFee(_city) * groups.length;
    final total = subtotal + delivery;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              icon: Icons.local_shipping_outlined,
              title: 'Delivery details',
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Receiver name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone number for delivery'),
                    validator: Fmt.validatePhone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _city,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Town'),
                    items: Catalog.cities
                        .map((c) => DropdownMenuItem(value: c, child: Text('$c  •  ${Fmt.price(Catalog.deliveryFee(c))}')))
                        .toList(),
                    onChanged: (v) => setState(() => _city = v ?? _city),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Address & landmark',
                      hintText: 'e.g. 12 Wilkinson Road, near Lumley roundabout',
                    ),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Enter a delivery address' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Note for the seller (optional)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Payment method',
              child: Column(
                children: Catalog.paymentOptions.map((m) {
                  final enabled = m != PaymentOption.online || AppConfig.onlinePaymentsEnabled;
                  final selected = _payment == m;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: enabled ? () => setState(() => _payment = m) : null,
                      child: Opacity(
                        opacity: enabled ? 1 : 0.45,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: selected ? AppColors.blueLight : Colors.white,
                            border: Border.all(color: selected ? AppColors.blue : AppColors.border, width: selected ? 1.6 : 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration:
                                    BoxDecoration(color: m.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                child: Icon(m.icon, color: m.color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(enabled ? m.hint : 'Coming soon',
                                        style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                  color: selected ? AppColors.blue : AppColors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            _card(
              icon: Icons.receipt_long_outlined,
              title: 'Order summary',
              child: Column(
                children: [
                  for (final entry in groups.entries) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('From ${entry.value.first.sellerName}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                    ...entry.value.map((i) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${i.quantity} × ${i.title}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                              ),
                              const SizedBox(width: 8),
                              Text(Fmt.price(i.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 6),
                  ],
                  const Divider(height: 20),
                  _row('Subtotal', Fmt.price(subtotal)),
                  _row(
                      groups.length > 1 ? 'Delivery to $_city (${groups.length} sellers)' : 'Delivery to $_city',
                      Fmt.price(delivery)),
                  const Divider(height: 20),
                  _row('Total', Fmt.price(total), bold: true),
                  if (groups.length > 1)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Each seller delivers their own items, so you will get one order per seller.',
                          style: TextStyle(color: AppColors.grey, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
        color: Colors.white,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
          onPressed: _placing || items.isEmpty ? null : () => _place(items),
          child: _placing
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
                    SizedBox(width: 12),
                    Text('Placing order…'),
                  ],
                )
              : Text(_payment == PaymentOption.online
                  ? 'Continue to payment • ${Fmt.price(total)}'
                  : 'Place order • ${Fmt.price(total)}'),
        ),
      ),
    );
  }

  Widget _card({required IconData icon, required String title, required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.blue, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: bold ? AppColors.navy : AppColors.grey,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      fontSize: bold ? 16 : 14)),
            ),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    fontSize: bold ? 18 : 14,
                    color: bold ? AppColors.blue : AppColors.navy)),
          ],
        ),
      );
}
