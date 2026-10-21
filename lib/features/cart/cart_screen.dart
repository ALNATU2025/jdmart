import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/cart_item.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../../shared/widgets/qty_stepper.dart';
import '../../state/cart_provider.dart';
import '../auth/auth_guard.dart';
import '../catalog/product_detail_screen.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _refreshing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<CartProvider>().refresh();
      } catch (_) {
        // Offline: show the saved cart; the server re-checks at checkout.
      }
      if (mounted) setState(() => _refreshing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final unavailable = cart.items.where((i) => !i.available || i.stock <= 0).toList();

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
        bottom: _refreshing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2, color: AppColors.orange))
            : null,
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Browse products from sellers across Sierra Leone.',
              actionLabel: 'Start shopping',
              onAction: () => Navigator.popUntil(context, (r) => r.isFirst),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (unavailable.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.orangeLight, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              '${unavailable.length} ${unavailable.length == 1 ? 'item is' : 'items are'} no longer available.',
                              style: const TextStyle(fontSize: 13)),
                        ),
                        TextButton(
                          onPressed: () => cart.removeAll(unavailable.map((i) => i.productId)),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ),
                for (final (i, item) in cart.items.indexed)
                  FadeSlideIn(
                    key: ValueKey(item.productId),
                    delay: Motion.stagger(i),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CartTile(item: item),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: cart.availableItems.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Subtotal', style: TextStyle(color: AppColors.grey)),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: Motion.medium,
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                            child: c,
                          ),
                        ),
                        child: Text(Fmt.price(cart.subtotal),
                            key: ValueKey(cart.subtotal),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  if (cart.savings > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('You save ${Fmt.price(cart.savings)}',
                          style: const TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Delivery is added at checkout', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                    onPressed: _refreshing
                        ? null
                        : () async {
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

class _CartTile extends StatelessWidget {
  final CartItem item;
  const _CartTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final ok = item.available && item.stock > 0;
    return Dismissible(
      key: ValueKey(item.productId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        cart.remove(item.productId);
        showSnack(context, '${item.title} removed');
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: item.productId))),
        child: Opacity(
          opacity: ok ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                ProductImage(
                  url: item.image,
                  categoryId: item.categoryId,
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
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(ok ? item.sellerName : 'No longer available',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: ok ? AppColors.grey : AppColors.danger, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(Fmt.price(item.total),
                                style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          if (ok)
                            QtyStepper(
                              value: item.quantity,
                              max: item.stock,
                              onChanged: (v) => cart.setQuantity(item.productId, v),
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
      ),
    );
  }
}
