import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/product_image.dart';
import 'order_detail_screen.dart';

/// Buyer's purchases (sellerView = false) or a seller's incoming sales (sellerView = true).
class OrdersScreen extends StatelessWidget {
  final bool sellerView;
  const OrdersScreen({super.key, this.sellerView = false});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user!;
    final provider = context.watch<OrderProvider>();
    final all = sellerView ? provider.forSeller(me.id) : provider.forBuyer(me.id);

    const tabs = ['All', 'Active', 'Delivered', 'Cancelled'];
    List<Order> filter(int t) => switch (t) {
          1 => all
              .where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled)
              .toList(),
          2 => all.where((o) => o.status == OrderStatus.delivered).toList(),
          3 => all.where((o) => o.status == OrderStatus.cancelled).toList(),
          _ => all,
        };

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(sellerView ? 'Sales orders' : 'My orders'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.blue,
            unselectedLabelColor: AppColors.grey,
            indicatorColor: AppColors.orange,
            tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: TabBarView(
          children: List.generate(tabs.length, (t) {
            final list = filter(t);
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.receipt_long_outlined,
                title: sellerView ? 'No sales yet' : 'No orders yet',
                message: sellerView
                    ? 'When buyers order your items, they will appear here.'
                    : 'Your orders will appear here after checkout.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _OrderTile(order: list[i], sellerView: sellerView, myId: me.id),
            );
          }),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final bool sellerView;
  final String myId;
  const _OrderTile({required this.order, required this.sellerView, required this.myId});

  @override
  Widget build(BuildContext context) {
    final items = sellerView ? order.items.where((i) => i.sellerId == myId).toList() : order.items;
    final amount = sellerView ? items.fold(0.0, (s, i) => s + i.total) : order.total;
    final first = items.first;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id, sellerView: sellerView))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            ProductImage(
              path: first.image,
              categoryId: first.categoryId,
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
                  Text('#${order.id}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(
                    items.length > 1 ? '${first.title} +${items.length - 1} more' : first.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.grey, fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sellerView ? '${order.buyerName} • ${order.city}' : Fmt.date(order.createdAt),
                    style: const TextStyle(color: AppColors.grey, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.price(amount), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.blue)),
                const SizedBox(height: 8),
                StatusChip(order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
