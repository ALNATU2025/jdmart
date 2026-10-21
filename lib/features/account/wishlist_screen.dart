import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_card.dart';
import '../../state/session_provider.dart';
import '../../state/wishlist_provider.dart';
import '../auth/auth_guard.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  Set<String> _loadedIds = {};
  Future<Map<String, Product>>? _future;

  Future<Map<String, Product>> _load(Set<String> ids) {
    if (_future == null || !_sameIds(ids)) {
      _loadedIds = ids;
      _future = context.read<ProductRepository>().getMany(ids);
    }
    return _future!;
  }

  bool _sameIds(Set<String> ids) => ids.length == _loadedIds.length && ids.containsAll(_loadedIds);

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<SessionProvider, bool>((s) => s.isLoggedIn);
    final ids = context.select<WishlistProvider, Set<String>>((w) => w.ids);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved items'), actions: const [CartIconButton()]),
      body: !loggedIn
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Save items you like',
              message: 'Sign in to save items and find them on any phone.',
              actionLabel: 'Sign in',
              onAction: () => ensureLoggedIn(context),
            )
          : ids.isEmpty
              ? EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'Nothing saved yet',
                  message: 'Tap the heart on any listing to save it for later.',
                  actionLabel: 'Start shopping',
                  onAction: () => Navigator.pop(context),
                )
              : FutureBuilder<Map<String, Product>>(
                  future: _load(ids),
                  builder: (_, snap) {
                    if (snap.hasError) return ErrorView(error: snap.error);
                    if (!snap.hasData) return const LoadingView();
                    final items = ids.map((id) => snap.data![id]).whereType<Product>().toList();
                    if (items.isEmpty) {
                      return const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Saved items were removed',
                          message: 'The sellers have taken these listings down.');
                    }
                    return CustomScrollView(
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        ProductSliverGrid(products: items),
                      ],
                    );
                  },
                ),
    );
  }
}
