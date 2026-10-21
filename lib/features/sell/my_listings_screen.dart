import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';
import '../catalog/product_detail_screen.dart';
import 'add_product_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.uid);
    if (uid == null) return Scaffold(appBar: AppBar());
    final repo = context.read<ProductRepository>();

    return StreamView<List<Product>>(
      id: uid,
      create: () => repo.mine(uid),
      loading: Scaffold(appBar: AppBar(title: const Text('My listings')), body: const LoadingView()),
      builder: (context, all) {
        final active = all.where((p) => p.status == ProductStatus.active && p.stock > 0).toList();
        final other = all.where((p) => !(p.status == ProductStatus.active && p.stock > 0)).toList();
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('My listings'),
              bottom: TabBar(
                labelColor: AppColors.blue,
                unselectedLabelColor: AppColors.grey,
                indicatorColor: AppColors.orange,
                tabs: [Tab(text: 'Active (${active.length})'), Tab(text: 'Sold / hidden (${other.length})')],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New listing'),
            ),
            body: TabBarView(children: [_list(context, repo, active, true), _list(context, repo, other, false)]),
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context, ProductRepository repo, List<Product> items, bool active) {
    if (items.isEmpty) {
      return EmptyState(
        icon: active ? Icons.storefront_outlined : Icons.sell_outlined,
        title: active ? 'No active listings' : 'Nothing here yet',
        message: active ? 'Post your first item — it takes about a minute.' : 'Sold and hidden items show here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = items[i];
        final label = p.status == ProductStatus.hidden
            ? 'Hidden'
            : p.isSold
                ? 'Sold'
                : '${p.stock} left';
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                ProductImage(
                  url: p.cover,
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
                      Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(Fmt.price(p.price), style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        children: [
                          Text('👁 ${p.views}', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                          Text(Fmt.ago(p.createdAt), style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'edit':
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(existing: p)));
                      case 'sold':
                        repo.setStatus(p.id, ProductStatus.sold);
                      case 'relist':
                        if (p.stock <= 0) {
                          showSnack(context, 'Set a quantity above 0 to relist (Edit).', error: true);
                        } else {
                          repo.setStatus(p.id, ProductStatus.active);
                        }
                      case 'hide':
                        repo.setStatus(p.id, ProductStatus.hidden);
                      case 'delete':
                        if (await confirmDialog(context,
                            title: 'Delete listing?', message: 'This cannot be undone.', confirm: 'Delete', danger: true)) {
                          repo.delete(p.id);
                        }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (active) const PopupMenuItem(value: 'sold', child: Text('Mark as sold')),
                    if (active) const PopupMenuItem(value: 'hide', child: Text('Hide from buyers')),
                    if (!active) const PopupMenuItem(value: 'relist', child: Text('Relist')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
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
