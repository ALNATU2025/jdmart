import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  /// When true the viewer is a seller managing this order.
  final bool sellerView;
  const OrderDetailScreen({super.key, required this.orderId, this.sellerView = false});

  static const _steps = [OrderStatus.pending, OrderStatus.confirmed, OrderStatus.shipped, OrderStatus.delivered];

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final o = orders.byId(orderId);
    final me = context.watch<AuthProvider>().user;
    if (o == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(icon: Icons.receipt_long, title: 'Order not found', message: ''));
    }
    final items = sellerView ? o.items.where((i) => i.sellerId == me?.id).toList() : o.items;
    final current = _steps.indexOf(o.status);

    return Scaffold(
      appBar: AppBar(title: Text('Order #${o.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(Fmt.dateTime(o.createdAt), style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                    ),
                    StatusChip(o.status),
                  ],
                ),
                const SizedBox(height: 18),
                if (o.status == OrderStatus.cancelled)
                  const Text('This order was cancelled.', style: TextStyle(color: AppColors.danger))
                else
                  ...List.generate(_steps.length, (i) {
                    final done = i <= current;
                    final last = i == _steps.length - 1;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: done ? AppColors.blue : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: done ? AppColors.blue : AppColors.border, width: 2),
                              ),
                              child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                            ),
                            if (!last)
                              Container(
                                width: 2,
                                height: 30,
                                color: i < current ? AppColors.blue : AppColors.border,
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _steps[i].label,
                            style: TextStyle(
                              fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                              color: done ? AppColors.navy : AppColors.grey,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Items (${items.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                ...items.map((i) => InkWell(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: i.productId))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            ProductImage(
                              path: i.image,
                              categoryId: i.categoryId,
                              width: 56,
                              height: 56,
                              iconSize: 24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                  Text('${i.quantity} × ${Fmt.price(i.price)} • ${i.sellerName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(Fmt.price(i.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                _line(Icons.person_outline, o.buyerName),
                _line(Icons.phone_outlined, o.phone),
                _line(Icons.location_on_outlined, '${o.address}, ${o.city}'),
                if (o.note.isNotEmpty) _line(Icons.sticky_note_2_outlined, o.note),
                _line(SeedData.payment(o.paymentMethod).icon, SeedData.payment(o.paymentMethod).name),
                const Divider(height: 24),
                if (!sellerView) ...[
                  _kv('Subtotal', Fmt.price(o.subtotal)),
                  _kv('Delivery', Fmt.price(o.deliveryFee)),
                  _kv('Total', Fmt.price(o.total), bold: true),
                ] else
                  _kv('Your earnings', Fmt.price(items.fold(0.0, (s, i) => s + i.total)), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (sellerView && o.status != OrderStatus.cancelled && o.status != OrderStatus.delivered)
            ElevatedButton(
              onPressed: () {
                final next = _steps[current + 1 >= _steps.length ? _steps.length - 1 : current + 1];
                orders.updateStatus(o.id, next);
                showSnack(context, 'Order marked as ${next.label}');
              },
              child: Text('Mark as ${_steps[current + 1 >= _steps.length ? _steps.length - 1 : current + 1].label}'),
            ),
          if (o.status == OrderStatus.pending && !sellerView)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              onPressed: () async {
                if (await confirmDialog(context,
                    title: 'Cancel order?', message: 'This cannot be undone.', confirm: 'Cancel order', danger: true)) {
                  orders.updateStatus(o.id, OrderStatus.cancelled);
                }
              },
              child: const Text('Cancel order'),
            ),
          if (sellerView && o.status == OrderStatus.pending) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => orders.updateStatus(o.id, OrderStatus.cancelled),
              child: const Text('Decline order', style: TextStyle(color: AppColors.danger)),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _box(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: child,
      );

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
          ],
        ),
      );

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(k, style: TextStyle(color: bold ? AppColors.navy : AppColors.grey, fontWeight: bold ? FontWeight.w700 : null)),
            const Spacer(),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: bold ? AppColors.blue : AppColors.navy,
                    fontSize: bold ? 17 : 14)),
          ],
        ),
      );
}
