import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';
import 'order_detail_screen.dart';

/// My purchases (sellerView = false) or incoming sales (sellerView = true).
class OrdersScreen extends StatelessWidget {
  final bool sellerView;
  const OrdersScreen({super.key, this.sellerView = false});

  static const _tabs = ['All', 'Active', 'Delivered', 'Cancelled'];

  List<Order> _filter(List<Order> all, int t) => switch (t) {
        1 => all.where((o) => o.isOpen).toList(),
        2 => all.where((o) => o.status == OrderStatus.delivered).toList(),
        3 => all.where((o) => o.status == OrderStatus.cancelled).toList(),
        _ => all,
      };

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.uid);
    if (uid == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.lock_outline, title: 'Please sign in', message: ''));
    }
    final repo = context.read<OrderRepository>();

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(sellerView ? 'Sales orders' : 'My orders'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.blue,
            unselectedLabelColor: AppColors.grey,
            indicatorColor: AppColors.orange,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: StreamView<List<Order>>(
          loading: const ListSkeleton(),
          id: '$uid-$sellerView',
          create: () => sellerView ? repo.forSeller(uid) : repo.forBuyer(uid),
          builder: (_, all) => TabBarView(
            children: List.generate(_tabs.length, (t) {
              final list = _filter(all, t);
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: sellerView ? 'No sales here' : 'No orders here',
                  message: sellerView
                      ? 'When buyers order your items, they appear here.'
                      : 'Your orders appear here after checkout.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => FadeSlideIn(
                  delay: Motion.stagger(i),
                  child: OrderTile(order: list[i], sellerView: sellerView),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class OrderTile extends StatelessWidget {
  final Order order;
  final bool sellerView;
  const OrderTile({super.key, required this.order, required this.sellerView});

  @override
  Widget build(BuildContext context) {
    final first = order.items.isNotEmpty ? order.items.first : null;
    final unpaid = order.paymentMethod == 'online' && order.paymentStatus == PaymentStatus.unpaid;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id, sellerView: sellerView))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            ProductImage(
              url: first?.image,
              categoryId: first?.categoryId ?? 'other',
              width: 64,
              height: 64,
              iconSize: 26,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${order.shortId}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(
                    first == null
                        ? ''
                        : order.items.length > 1
                            ? '${first.title} +${order.items.length - 1} more'
                            : first.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.grey, fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sellerView ? '${order.buyerName} • ${order.city}' : '${order.sellerName} • ${Fmt.date(order.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.grey, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.price(order.total), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.blue)),
                const SizedBox(height: 8),
                unpaid && order.isOpen
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration:
                            BoxDecoration(color: AppColors.orangeLight, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Awaiting payment',
                            style: TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                      )
                    : StatusChip(order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
