import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/common.dart';
import '../../state/session_provider.dart';
import '../orders/orders_screen.dart';
import 'add_product_screen.dart';
import 'my_listings_screen.dart';
import '../../core/theme/palette.dart';

class SellerHubScreen extends StatefulWidget {
  const SellerHubScreen({super.key});

  @override
  State<SellerHubScreen> createState() => _SellerHubScreenState();
}

class _SellerHubScreenState extends State<SellerHubScreen> {
  late final String _uid = context.read<SessionProvider>().uid!;
  late final Stream<List<Order>> _sales = context.read<OrderRepository>().forSeller(_uid);
  late final Stream<List<Product>> _listings = context.read<ProductRepository>().mine(_uid);
  late final Stream<Map<String, dynamic>> _stats = context.read<OrderRepository>().sellerStats(_uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Hub')),
      body: StreamBuilder<List<Order>>(
        stream: _sales,
        builder: (_, salesSnap) => StreamBuilder<List<Product>>(
          stream: _listings,
          builder: (_, listSnap) => StreamBuilder<Map<String, dynamic>>(
            stream: _stats,
            builder: (_, statsSnap) {
              if (salesSnap.hasError || listSnap.hasError) {
                return ErrorView(error: salesSnap.error ?? listSnap.error);
              }
              if (!salesSnap.hasData || !listSnap.hasData) return const LoadingView();
              return _body(salesSnap.data!, listSnap.data!, statsSnap.data ?? const {});
            },
          ),
        ),
      ),
    );
  }

  Widget _body(List<Order> sales, List<Product> listings, Map<String, dynamic> stats) {
    final toFulfil = sales.where((o) => o.isOpen && !(o.paymentMethod == 'online' && o.paymentStatus == PaymentStatus.unpaid)).length;
    final earnings = (stats['deliveredRevenue'] as num?)?.toDouble() ?? 0;
    final delivered = (stats['deliveredOrders'] as num?)?.toInt() ?? 0;
    final active = listings.where((p) => p.available).toList();
    final views = listings.fold<int>(0, (s, p) => s + p.views);
    final lowStock = active.where((p) => p.stock <= 2).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.orangeGradient, borderRadius: BorderRadius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings from delivered orders', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(Fmt.price(earnings), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('$delivered delivered ${delivered == 1 ? 'order' : 'orders'}',
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
            _stat(Icons.pending_actions_rounded, '$toFulfil', 'To fulfil', const Color(0xFFD97706)),
            _stat(Icons.inventory_2_rounded, '${active.length}', 'Active listings', AppColors.success),
            _stat(Icons.visibility_rounded, '$views', 'Listing views', const Color(0xFF7C3AED)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, minimumSize: const Size(0, 52)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New listing'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen())),
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
            decoration: BoxDecoration(color: context.orangeTint, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${lowStock.length} ${lowStock.length == 1 ? 'item is' : 'items are'} running low: '
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
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(sellerView: true))),
                child: const Text('See all'),
              ),
          ],
        ),
        if (sales.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16)),
            child: Text(
              'No orders yet. Tip: clear photos, an honest description and a fair price help your items sell.',
              style: TextStyle(color: context.muted),
            ),
          )
        else
          ...sales.take(5).map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OrderTile(order: o, sellerView: true),
              )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
