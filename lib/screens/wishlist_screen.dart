import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ProductProvider>().wishlist;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved items'), actions: const [CartIconButton()]),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Nothing saved yet',
              message: 'Tap the heart on any product to save it for later.',
              actionLabel: 'Start shopping',
              onAction: () => Navigator.pop(context),
            )
          : CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ProductSliverGrid(products: items),
              ],
            ),
    );
  }
}
