import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../screens/product_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final double? width;
  const ProductCard({super.key, required this.product, this.width});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final wished = products.isWished(product.id);
    final p = product;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: AppColors.navy.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4)),
          ],
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
                    path: p.images.isEmpty ? null : p.images.first,
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
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('SOLD',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 2)),
                    ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => products.toggleWish(p.id),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            wished ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18,
                            color: wished ? AppColors.danger : AppColors.grey,
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
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.blue)),
                      ),
                      const Spacer(),
                      if (p.available)
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            final ok = context.read<CartProvider>().add(p);
                            showSnack(context, ok ? 'Added to cart' : 'Only ${p.stock} in stock', error: !ok);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                gradient: AppColors.orangeGradient, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(p.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.grey)),
                      ),
                      if (p.reviews.isNotEmpty) ...[
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB400)),
                        Text(p.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 11, color: AppColors.grey)),
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

/// Responsive 2-4 column product grid usable inside a CustomScrollView.
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
          (ctx, i) => ProductCard(product: products[i]),
          childCount: products.length,
        ),
      ),
    );
  }
}
