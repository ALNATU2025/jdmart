import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product.dart';
import '../../features/auth/auth_guard.dart';
import '../../features/catalog/product_detail_screen.dart';
import '../../state/cart_provider.dart';
import '../../state/session_provider.dart';
import '../../state/wishlist_provider.dart';
import 'common.dart';
import 'motion.dart';
import 'product_image.dart';
import '../../core/theme/palette.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final double? width;
  const ProductCard({super.key, required this.product, this.width});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final saved = context.select<WishlistProvider, bool>((w) => w.isSaved(p.id));
    final isMine = context.select<SessionProvider, bool>((s) => s.uid == p.sellerId);

    return Pressable(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: softShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.05,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(
                    url: p.cover,
                    categoryId: p.categoryId,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  if (p.discountPercent > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(8)),
                        child: Text('-${p.discountPercent}%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (p.isSold)
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('SOLD',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 2)),
                    ),
                  if (!isMine)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Material(
                        color: context.surface,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () async {
                            if (!await ensureLoggedIn(context)) return;
                            HapticFeedback.lightImpact();
                            if (context.mounted) context.read<WishlistProvider>().toggle(p.id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: PopOnChange(
                              value: saved,
                              child: Icon(
                                saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 18,
                                color: saved ? AppColors.danger : context.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.25)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(Fmt.price(p.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.brand)),
                      ),
                      const Spacer(),
                      if (p.available && !isMine)
                        Pressable(
                          scale: 0.85,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final err = context.read<CartProvider>().add(p);
                            showSnack(context, err ?? 'Added to cart', error: err != null);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration:
                                BoxDecoration(gradient: AppColors.orangeGradient, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: context.muted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(p.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: context.muted)),
                      ),
                      if (p.ratingCount > 0) ...[
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB400)),
                        Text(p.ratingAvg.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: context.muted)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive 2–5 column product grid for use inside a CustomScrollView.
class ProductSliverGrid extends StatelessWidget {
  final List<Product> products;
  const ProductSliverGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w > 1100 ? 5 : w > 800 ? 4 : w > 560 ? 3 : 2;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.6,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => FadeSlideIn(
            key: ValueKey(products[i].id),
            delay: Motion.stagger(i % (cols * 2)),
            child: ProductCard(product: products[i]),
          ),
          childCount: products.length,
        ),
      ),
    );
  }
}

/// Horizontal strip of product cards.
class ProductStrip extends StatelessWidget {
  final List<Product> items;
  const ProductStrip(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 278,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => FadeSlideIn(
          delay: Motion.stagger(i),
          offset: const Offset(0.12, 0),
          child: ProductCard(product: items[i], width: 160),
        ),
      ),
    );
  }
}
