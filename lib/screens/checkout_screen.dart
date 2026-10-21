import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'order_success_screen.dart';

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
  final _walletNumber = TextEditingController();
  late String _city;
  String _payment = 'orange';
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user!;
    _name = TextEditingController(text: u.name);
    _phone = TextEditingController(text: u.phone);
    _walletNumber.text = u.phone;
    _city = SeedData.deliveryFees.containsKey(u.city) ? u.city : 'Freetown';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _note, _walletNumber]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isWallet => _payment == 'orange' || _payment == 'afrimoney';

  Future<void> _place() async {
    if (!_form.currentState!.validate()) {
      showSnack(context, 'Please complete the delivery details', error: true);
      return;
    }
    setState(() => _placing = true);
    final order = await context.read<OrderProvider>().placeOrder(
          buyer: context.read<AuthProvider>().user!,
          cart: context.read<CartProvider>(),
          products: context.read<ProductProvider>(),
          paymentMethod: _payment,
          address: _address.text.trim(),
          city: _city,
          phone: _phone.text.trim(),
          note: _note.text.trim(),
        );
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: order.id)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final products = context.watch<ProductProvider>();
    final subtotal = cart.subtotal(products);
    final fee = SeedData.deliveryFees[_city] ?? 100.0;
    final total = subtotal + fee;

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
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone number'),
                    validator: Fmt.validatePhone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _city,
                    decoration: const InputDecoration(labelText: 'City / Town'),
                    items: SeedData.cities
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text('$c  •  ${Fmt.price(SeedData.deliveryFees[c]!)}'),
                            ))
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
                    decoration: const InputDecoration(labelText: 'Note for the rider (optional)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Payment method',
              child: Column(
                children: [
                  ...SeedData.paymentMethods.map((m) {
                    final selected = _payment == m.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _payment = m.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: selected ? AppColors.blueLight : Colors.white,
                            border: Border.all(
                                color: selected ? AppColors.blue : AppColors.border, width: selected ? 1.6 : 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: m.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: Icon(m.icon, color: m.color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(m.hint, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Icon(
                                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: selected ? AppColors.blue : AppColors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_isWallet) ...[
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _walletNumber,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: '${SeedData.payment(_payment).name} number',
                        helperText: 'You will receive a prompt on your phone to approve the payment.',
                      ),
                      validator: _isWallet ? Fmt.validatePhone : null,
                    ),
                  ],
                  if (_payment == 'card')
                    const Text(
                      'You will be redirected to a secure card payment page.',
                      style: TextStyle(color: AppColors.grey, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              icon: Icons.receipt_long_outlined,
              title: 'Order summary',
              child: Column(
                children: [
                  ...cart.items.map((i) {
                    final p = products.byId(i.productId);
                    if (p == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${i.quantity} × ${p.title}',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          Text(Fmt.price(p.price * i.quantity),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),
                  _row('Subtotal', Fmt.price(subtotal)),
                  _row('Delivery to $_city', Fmt.price(fee)),
                  const Divider(height: 20),
                  _row('Total', Fmt.price(total), bold: true),
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
          onPressed: _placing || cart.isEmpty ? null : _place,
          child: _placing
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
                    SizedBox(width: 12),
                    Text('Processing payment…'),
                  ],
                )
              : Text(_payment == 'cod' ? 'Place order • ${Fmt.price(total)}' : 'Pay ${Fmt.price(total)}'),
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
            Text(label,
                style: TextStyle(
                    color: bold ? AppColors.navy : AppColors.grey,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    fontSize: bold ? 16 : 14)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    fontSize: bold ? 18 : 14,
                    color: bold ? AppColors.blue : AppColors.navy)),
          ],
        ),
      );
}
