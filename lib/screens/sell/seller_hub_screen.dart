import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../order_detail_screen.dart';
import '../orders_screen.dart';
import 'add_product_screen.dart';
import 'my_listings_screen.dart';

class SellerHubScreen extends StatelessWidget {
  const SellerHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user!;
    final orders = context.watch<OrderProvider>();
    final products = context.watch<ProductProvider>();
    final listings = products.bySeller(me.id);
    final sales = orders.forSeller(me.id);
    final pending = sales.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.confirmed).length;
    final revenue = orders.sellerRevenue(me.id);
    final views = listings.fold(0, (s, p) => s + p.views);
    final lowStock = listings.where((p) => !p.isSold && p.stock <= 2).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Seller Hub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.orangeGradient, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total earnings', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(Fmt.price(revenue),
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Paid out to your Orange Money / Afrimoney wallet ${me.phone}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              _stat(Icons.receipt_long_rounded, '${sales.length}', 'Total orders', AppColors.blue),
              _stat(Icons.pending_actions_rounded, '$pending', 'To fulfil', const Color(0xFFD97706)),
              _stat(Icons.inventory_2_rounded, '${listings.where((p) => !p.isSold).length}', 'Active listings',
                  AppColors.success),
              _stat(Icons.visibility_rounded, '$views', 'Listing views', const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, minimumSize: const Size(0, 52)),
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New listing'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen())),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('Listings'),
                ),
              ),
            ],
          ),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.orangeLight, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${lowStock.length} ${lowStock.length == 1 ? 'item is' : 'items are'} running low on stock: '
                      '${lowStock.map((p) => p.title).take(2).join(', ')}${lowStock.length > 2 ? '…' : ''}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 22, bottom: 10),
                  child: Text('Recent orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              if (sales.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const OrdersScreen(sellerView: true))),
                  child: const Text('See all'),
                ),
            ],
          ),
          if (sales.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Text(
                'No orders yet. Tip: listings with 3+ clear photos and a detailed description sell up to 2× faster.',
                style: TextStyle(color: AppColors.grey),
              ),
            )
          else
            ...sales.take(5).map((o) {
              final mine = o.items.where((i) => i.sellerId == me.id);
              final amount = mine.fold(0.0, (s, i) => s + i.total);
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id, sellerView: true))),
                  title: Text('#${o.id} • ${o.buyerName}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${mine.length} item(s) • ${o.city} • ${Fmt.ago(o.createdAt)}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.price(amount),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.blue)),
                      const SizedBox(height: 4),
                      StatusChip(o.status),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.grey, fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
