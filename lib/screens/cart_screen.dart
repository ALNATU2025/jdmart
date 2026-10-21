import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/product_image.dart';
import 'auth/login_screen.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CartProvider>().prune(context.read<ProductProvider>());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final products = context.watch<ProductProvider>();
    final subtotal = cart.subtotal(products);
    final savings = cart.savings(products);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Cart${cart.count > 0 ? ' (${cart.count})' : ''}'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () async {
                if (await confirmDialog(context,
                    title: 'Clear cart?', message: 'Remove all items from your cart?', confirm: 'Clear', danger: true)) {
                  cart.clear();
                }
              },
              child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Browse thousands of products from sellers across Sierra Leone.',
              actionLabel: 'Start shopping',
              onAction: () => Navigator.popUntil(context, (r) => r.isFirst),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final item = cart.items[i];
                final p = products.byId(item.productId);
                if (p == null) return const SizedBox.shrink();
                return Dismissible(
                  key: ValueKey(p.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    cart.remove(p.id);
                    showSnack(context, '${p.title} removed');
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Row(
                        children: [
                          ProductImage(
                            path: p.images.isEmpty ? null : p.images.first,
                            categoryId: p.categoryId,
                            width: 88,
                            height: 88,
                            iconSize: 34,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(p.sellerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(Fmt.price(p.price * item.quantity),
                                          style: const TextStyle(
                                              color: AppColors.blue, fontWeight: FontWeight.w700, fontSize: 15)),
                                    ),
                                    QtyStepper(
                                      value: item.quantity,
                                      max: p.stock,
                                      onChanged: (v) => cart.setQuantity(p.id, v),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Subtotal', style: TextStyle(color: AppColors.grey)),
                      const Spacer(),
                      Text(Fmt.price(subtotal),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  if (savings > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('You save ${Fmt.price(savings)} 🎉',
                          style: const TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Delivery fee is calculated at checkout',
                        style: TextStyle(color: AppColors.grey, fontSize: 12)),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                    onPressed: () async {
                      if (!await ensureLoggedIn(context)) return;
                      if (!context.mounted) return;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                    },
                    child: const Text('Proceed to Checkout'),
                  ),
                ],
              ),
            ),
    );
  }
}
