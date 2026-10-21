import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import 'category_products_screen.dart';
import 'main_shell.dart';
import 'search_screen.dart';
import 'wishlist_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: () async => Future.delayed(const Duration(milliseconds: 600)),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              titleSpacing: 12,
              title: const JDWordmark(size: 22),
              actions: [
                IconButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
                  icon: const Icon(Icons.favorite_border_rounded),
                  tooltip: 'Saved items',
                ),
                const CartIconButton(),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(child: _Greeting(name: user?.name)),
            SliverToBoxAdapter(child: _SearchBar()),
            const SliverToBoxAdapter(child: _BannerCarousel()),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Categories',
                action: 'See all',
                onAction: () => MainShell.goTo(context, 1),
              ),
            ),
            const SliverToBoxAdapter(child: _CategoryStrip()),
            if (products.deals.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _FlashDealsHeader()),
              SliverToBoxAdapter(child: _HorizontalProducts(products.deals)),
            ],
            SliverToBoxAdapter(child: SectionHeader(title: 'Featured for you')),
            SliverToBoxAdapter(child: _HorizontalProducts(products.featured)),
            const SliverToBoxAdapter(child: _SellPromo()),
            const SliverToBoxAdapter(child: SectionHeader(title: 'Just listed')),
            ProductSliverGrid(products: products.newest),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String? name;
  const _Greeting({this.name});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$greet${name == null ? '' : ', ${name!.split(' ').first}'} 👋',
              style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(height: 2),
          const Text('What are you buying today?',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.grey),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Search phones, Gara, rice, cars…',
                    style: TextStyle(color: AppColors.grey, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _pc = PageController(viewportFraction: 0.92);
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pc.hasClients) return;
      final next = (_i + 1) % SeedData.banners.length;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gradients = [AppColors.brandGradient, AppColors.orangeGradient,
      LinearGradient(colors: [Color(0xFF15803D), Color(0xFF22C55E)])];
    return Column(
      children: [
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pc,
            itemCount: SeedData.banners.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) {
              final (title, sub, cat) = SeedData.banners[i];
              final c = SeedData.category(cat);
              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CategoryProductsScreen(categoryId: cat))),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    gradient: gradients[i % gradients.length],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        bottom: -24,
                        child: Icon(c.icon, size: 150, color: Colors.white.withOpacity(0.16)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 13)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Text('Shop now',
                                  style: TextStyle(
                                      color: gradients[i % gradients.length].colors.first,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            SeedData.banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _i == i ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _i == i ? AppColors.blue : AppColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: SeedData.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = SeedData.categories[i];
          return GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(categoryId: c.id))),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: c.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(c.icon, color: c.color, size: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(c.name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FlashDealsHeader extends StatelessWidget {
  const _FlashDealsHeader();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final left = end.difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.flash_on_rounded, color: AppColors.orange),
          const SizedBox(width: 4),
          const Text('Flash Deals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)),
            child: Text(
              'Ends in ${two(left.inHours)}:${two(left.inMinutes % 60)}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalProducts extends StatelessWidget {
  final List<Product> items;
  const _HorizontalProducts(this.items);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 278,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => ProductCard(product: items[i], width: 160),
      ),
    );
  }
}

class _SellPromo extends StatelessWidget {
  const _SellPromo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Got something to sell?',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Post it free in under a minute and reach buyers across all 16 districts.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                minimumSize: const Size(90, 44),
              ),
              onPressed: () => MainShell.goTo(context, -1),
              child: const Text('Sell'),
            ),
          ],
        ),
      ),
    );
  }
}
