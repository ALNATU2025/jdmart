import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_image.dart';
import '../catalog/product_detail_screen.dart';
import '../../core/theme/palette.dart';
import '../delivery/delivery_card.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  /// True when the viewer is the seller managing this order.
  final bool sellerView;
  const OrderDetailScreen({super.key, required this.orderId, this.sellerView = false});

  static const _steps = [OrderStatus.pending, OrderStatus.confirmed, OrderStatus.shipped, OrderStatus.delivered];

  @override
  Widget build(BuildContext context) {
    final repo = context.read<OrderRepository>();
    return StreamView<Order?>(
      id: orderId,
      create: () => repo.watch(orderId),
      loading: Scaffold(appBar: AppBar(), body: const LoadingView()),
      builder: (context, o) {
        if (o == null) {
          return Scaffold(
              appBar: AppBar(), body: const EmptyState(icon: Icons.receipt_long, title: 'Order not found', message: ''));
        }
        return _page(context, o, repo);
      },
    );
  }

  Widget _page(BuildContext context, Order o, OrderRepository repo) {
    final current = _steps.indexOf(o.status);
    final next = o.status.next;
    final awaitingPayment = o.paymentMethod == 'online' && o.paymentStatus == PaymentStatus.unpaid && o.isOpen;
    final buyerCanCancel = !sellerView && (o.status == OrderStatus.pending || o.status == OrderStatus.confirmed);
    final sellerCanAdvance = sellerView && next != null && !awaitingPayment;

    return Scaffold(
      appBar: AppBar(title: Text('Order #${o.shortId}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _box(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(Fmt.dateTime(o.createdAt), style: TextStyle(color: context.muted, fontSize: 13))),
                  StatusChip(o.status),
                ],
              ),
              if (awaitingPayment) ...[
                const SizedBox(height: 12),
                const Text('Waiting for the buyer to complete payment. Unpaid orders are cancelled after 30 minutes.',
                    style: TextStyle(color: AppColors.orange, fontSize: 13)),
              ],
              const SizedBox(height: 18),
              if (o.status == OrderStatus.cancelled)
                Text(
                  o.paymentStatus == PaymentStatus.refundDue
                      ? 'This order was cancelled. The payment will be refunded to the buyer.'
                      : 'This order was cancelled.',
                  style: const TextStyle(color: AppColors.danger),
                )
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
                              color: done ? AppColors.blue : context.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: done ? AppColors.blue : context.line, width: 2),
                            ),
                            child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                          ),
                          if (!last) Container(width: 2, height: 30, color: i < current ? AppColors.blue : context.line),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _steps[i].label,
                          style: TextStyle(
                            fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                            color: done ? context.ink : context.muted,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
            ],
          )),
          const SizedBox(height: 14),
          if (o.status == OrderStatus.confirmed || o.status == OrderStatus.shipped || o.status == OrderStatus.delivered)
            DeliveryCard(orderId: o.id, sellerView: sellerView),
          _box(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sellerView ? 'Items (${o.itemCount})' : 'From ${o.sellerName}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              ...o.items.map((i) => InkWell(
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: i.productId))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ProductImage(
                            url: i.image,
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
                                Text('${i.quantity} × ${Fmt.price(i.price)}',
                                    style: TextStyle(color: context.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(Fmt.price(i.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  )),
            ],
          )),
          const SizedBox(height: 14),
          _box(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              _line(Icons.person_outline, o.buyerName),
              InkWell(
                onTap: () => launchUrl(Uri.parse('tel:${o.phone.replaceAll(' ', '')}')),
                child: _line(Icons.phone_outlined, o.phone),
              ),
              _line(Icons.location_on_outlined, '${o.address}, ${o.city}'),
              if (o.note.isNotEmpty) _line(Icons.sticky_note_2_outlined, o.note),
              _line(
                o.paymentMethod == 'online' ? Icons.account_balance_wallet_outlined : Icons.payments_outlined,
                switch (o.paymentStatus) {
                  PaymentStatus.paid => o.paymentMethod == 'online' ? 'Paid online' : 'Paid in cash',
                  PaymentStatus.cod => 'Cash on delivery — collect ${Fmt.price(o.total)}',
                  PaymentStatus.refundDue => 'Refund due',
                  PaymentStatus.unpaid => 'Awaiting online payment',
                },
              ),
              const Divider(height: 24),
              _kv('Subtotal', Fmt.price(o.subtotal)),
              _kv('Delivery', Fmt.price(o.deliveryFee)),
              _kv('Total', Fmt.price(o.total), bold: true),
            ],
          )),
          const SizedBox(height: 20),
          if (sellerCanAdvance)
            ElevatedButton(
              onPressed: () => _act(context, () => repo.updateStatus(o.id, next!), 'Order marked as ${next!.label}'),
              child: Text('Mark as ${next!.label}'),
            ),
          if (sellerView && (o.status == OrderStatus.pending || o.status == OrderStatus.confirmed)) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                if (await confirmDialog(context,
                    title: 'Decline this order?',
                    message: 'The buyer will be notified and the items go back into stock.',
                    confirm: 'Decline',
                    danger: true)) {
                  if (context.mounted) await _act(context, () => repo.updateStatus(o.id, OrderStatus.cancelled), 'Order declined');
                }
              },
              child: const Text('Decline order', style: TextStyle(color: AppColors.danger)),
            ),
          ],
          if (buyerCanCancel)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              onPressed: () async {
                if (await confirmDialog(context,
                    title: 'Cancel order?',
                    message: o.paymentStatus == PaymentStatus.paid
                        ? 'Your payment will be refunded to the account you paid with.'
                        : 'This cannot be undone.',
                    confirm: 'Cancel order',
                    danger: true)) {
                  if (context.mounted) await _act(context, () => repo.cancelOrder(o.id), 'Order cancelled');
                }
              },
              child: const Text('Cancel order'),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, Future<void> Function() task, String success) async {
    final err = await runWithProgress(context, task);
    if (context.mounted) showSnack(context, err ?? success, error: err != null);
  }

  Widget _box(Widget child) => Builder(builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(20)),
        child: child,)
      );

  Widget _line(IconData icon, String text) => Builder(builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: context.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
          ],
        ),)
      );

  Widget _kv(String k, String v, {bool bold = false}) => Builder(builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(k, style: TextStyle(color: bold ? context.ink : context.muted, fontWeight: bold ? FontWeight.w700 : null)),
            const Spacer(),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: bold ? AppColors.blue : AppColors.navy,
                    fontSize: bold ? 17 : 14)),
          ],
        ),)
      );
}
