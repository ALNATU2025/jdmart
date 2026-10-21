import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

class SellerProfileScreen extends StatelessWidget {
  final String sellerId;
  const SellerProfileScreen({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {
    final seller = context.watch<AuthProvider>().findById(sellerId);
    final products = context.watch<ProductProvider>().bySeller(sellerId, includeSold: false);
    final reviews = products.expand((p) => p.reviews).toList();
    final rating = reviews.isEmpty ? 0.0 : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    final name = seller?.name ?? (products.isNotEmpty ? products.first.sellerName : 'Seller');
    final phone = seller?.phone ?? (products.isNotEmpty ? products.first.sellerPhone : '');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            title: Text(name),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 64, 20, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: UserAvatar(user: seller, name: name, radius: 34),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        if (seller?.verified ?? false) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${seller?.city ?? ''}${seller != null ? ' • Since ${Fmt.date(seller.joinedAt)}' : ''}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (reviews.isNotEmpty) ...[
                          RatingStars(rating: rating, size: 16),
                          Text('  ${rating.toStringAsFixed(1)} (${reviews.length})',
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                          const SizedBox(width: 12),
                        ],
                        Text('${products.length} listings',
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if ((seller?.bio ?? '').isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(seller!.bio, style: const TextStyle(color: AppColors.grey, height: 1.5)),
              ),
            ),
          if (phone.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    showSnack(context, 'Phone number $phone copied');
                  },
                  icon: const Icon(Icons.phone_outlined),
                  label: Text('Show contact: $phone'),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SectionHeader(title: 'Items for sale')),
          if (products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                  icon: Icons.storefront_outlined, title: 'No items', message: 'This seller has no active listings.'),
            )
          else
            ProductSliverGrid(products: products),
        ],
      ),
    );
  }
}
