import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_card.dart';
import '../../core/theme/palette.dart';

class SellerProfileScreen extends StatefulWidget {
  final String sellerId;
  const SellerProfileScreen({super.key, required this.sellerId});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  late final Stream<AppUser?> _seller = context.read<UserRepository>().watch(widget.sellerId);
  late final Stream<List<Product>> _products = context.read<ProductRepository>().activeBySeller(widget.sellerId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _seller,
      builder: (_, s) {
        if (s.hasError) return Scaffold(appBar: AppBar(), body: ErrorView(error: s.error));
        if (!s.hasData && s.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const LoadingView());
        }
        final seller = s.data;
        if (seller == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.person_off_outlined, title: 'Seller not found', message: ''),
          );
        }
        return _page(seller);
      },
    );
  }

  Widget _page(AppUser seller) {
    final phone = seller.contactPhone;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            title: Text(seller.name),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 64, 20, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: context.surface, shape: BoxShape.circle),
                      child: UserAvatar(name: seller.name, imageUrl: seller.avatarUrl, radius: 34),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(seller.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        if (seller.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${seller.city} • Joined ${Fmt.date(seller.joinedAt)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (seller.ratingCount > 0) ...[
                          RatingStars(rating: seller.ratingAvg, size: 16),
                          Text('  ${seller.ratingAvg.toStringAsFixed(1)} (${seller.ratingCount})',
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                          const SizedBox(width: 12),
                        ],
                        if (seller.salesCount > 0)
                          Text('${seller.salesCount} sales', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (seller.bio.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(seller.bio, style: TextStyle(color: context.muted, height: 1.5)),
              ),
            ),
          if (phone != null && phone.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${phone.replaceAll(' ', '')}')),
                  icon: const Icon(Icons.phone_outlined),
                  label: Text('Call ${Fmt.display(phone)}'),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SectionHeader(title: 'Items for sale')),
          StreamBuilder<List<Product>>(
            stream: _products,
            builder: (_, s) {
              if (s.hasError) return SliverToBoxAdapter(child: ErrorView(error: s.error));
              if (!s.hasData) return const SliverToBoxAdapter(child: LoadingView());
              if (s.data!.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                      icon: Icons.storefront_outlined, title: 'No items', message: 'This seller has no active listings.'),
                );
              }
              return ProductSliverGrid(products: s.data!);
            },
          ),
        ],
      ),
    );
  }
}
