import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';
import '../product_detail_screen.dart';
import 'add_product_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user!;
    final all = context.watch<ProductProvider>().bySeller(me.id);
    final active = all.where((p) => !p.isSold).toList();
    final sold = all.where((p) => p.isSold).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My listings'),
          bottom: TabBar(
            labelColor: AppColors.blue,
            unselectedLabelColor: AppColors.grey,
            indicatorColor: AppColors.orange,
            tabs: [Tab(text: 'Active (${active.length})'), Tab(text: 'Sold (${sold.length})')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New listing'),
        ),
        body: TabBarView(
          children: [_list(context, active, true), _list(context, sold, false)],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<Product> items, bool active) {
    if (items.isEmpty) {
      return EmptyState(
        icon: active ? Icons.storefront_outlined : Icons.sell_outlined,
        title: active ? 'No active listings' : 'Nothing sold yet',
        message: active ? 'Post your first item — it takes less than a minute.' : 'Sold items will show here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                ProductImage(
                  path: p.images.isEmpty ? null : p.images.first,
                  categoryId: p.categoryId,
                  width: 76,
                  height: 76,
                  iconSize: 30,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(Fmt.price(p.price),
                          style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined, size: 14, color: AppColors.grey),
                          Text(' ${p.views}', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                          const SizedBox(width: 10),
                          const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.grey),
                          Text(' ${p.stock} left', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                          const SizedBox(width: 10),
                          Text(Fmt.ago(p.createdAt), style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    final provider = context.read<ProductProvider>();
                    switch (v) {
                      case 'edit':
                        Navigator.push(
                            context, MaterialPageRoute(builder: (_) => AddProductScreen(existing: p)));
                      case 'sold':
                        provider.toggleSold(p.id);
                      case 'delete':
                        if (await confirmDialog(context,
                            title: 'Delete listing?', message: 'This cannot be undone.', confirm: 'Delete', danger: true)) {
                          provider.deleteProduct(p.id);
                        }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'sold', child: Text(p.isSold ? 'Relist' : 'Mark as sold')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
