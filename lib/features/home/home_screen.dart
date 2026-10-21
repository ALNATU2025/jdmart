import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/misc_repositories.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/category_icon.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_card.dart';
import '../../state/session_provider.dart';
import '../account/wishlist_screen.dart';
import '../catalog/search_screen.dart';
import '../shell/main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Stream<List<Product>> _newest;
  late Stream<List<Product>> _featured;
  late Stream<List<Product>> _deals;
  late Stream<List<PromoBanner>> _banners;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<ProductRepository>();
    _newest = repo.newest(limit: 40);
    _featured = repo.featured();
    _deals = repo.deals();
    _banners = context.read<BannerRepository>().active();
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<SessionProvider, String?>((s) => s.profile?.firstName);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: () async {
          setState(_load);
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              titleSpacing: 12,
              title: const JDWordmark(size: 22),
              actions: [
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
                  icon: const Icon(Icons.favorite_border_rounded),
                  tooltip: 'Saved items',
                ),
                const CartIconButton(),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(child: _Greeting(name: name)),
            const SliverToBoxAdapter(child: _SearchBar()),
            SliverToBoxAdapter(
              child: StreamBuilder<List<PromoBanner>>(
                stream: _banners,
                builder: (_, s) => (s.data?.isNotEmpty ?? false) ? _BannerCarousel(s.data!) : const SizedBox(height: 4),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(title: 'Categories', action: 'See all', onAction: () => MainShell.goTo(context, 1)),
            ),
            const SliverToBoxAdapter(child: _CategoryStrip()),
            _strip(_deals, const _FlashDealsHeader()),
            _strip(_featured, const SectionHeader(title: 'Featured')),
            const SliverToBoxAdapter(child: _SellPromo()),
            const SliverToBoxAdapter(child: SectionHeader(title: 'Just listed')),
            StreamBuilder<List<Product>>(
              stream: _newest,
              builder: (_, s) {
                if (s.hasError) {
                  return SliverToBoxAdapter(child: ErrorView(error: s.error, onRetry: () => setState(_load)));
                }
                if (!s.hasData) return const SliverToBoxAdapter(child: LoadingView());
                if (s.data!.isEmpty) {
                  return SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No listings yet',
                      message: 'Be one of the first sellers on JDMart. It only takes a minute.',
                      actionLabel: 'Post an item',
                      onAction: () => MainShell.goTo(context, -1),
                    ),
                  );
                }
                return ProductSliverGrid(products: s.data!);
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  /// A titled horizontal strip that disappears when it has nothing to show.
  Widget _strip(Stream<List<Product>> stream, Widget header) => SliverToBoxAdapter(
        child: StreamBuilder<List<Product>>(
          stream: stream,
          builder: (_, s) {
            final items = s.data ?? const <Product>[];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, ProductStrip(items)]);
          },
        ),
      );
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
          Text('$greet${name == null ? '' : ', $name'} 👋', style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(height: 2),
          const Text('What are you buying today?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

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
                child: Text('Search phones, Gara, rice, cars…', style: TextStyle(color: AppColors.grey, fontSize: 14)),
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
  final List<PromoBanner> banners;
  const _BannerCarousel(this.banners);

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _pc = PageController(viewportFraction: 0.92);
  int _i = 0;
  Timer? _t;

  static const _gradients = [
    AppColors.brandGradient,
    AppColors.orangeGradient,
    LinearGradient(colors: [Color(0xFF15803D), Color(0xFF22C55E)]),
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pc.hasClients || widget.banners.length < 2) return;
      _pc.animateToPage((_i + 1) % widget.banners.length,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
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
    final banners = widget.banners;
    return Column(
      children: [
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pc,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) {
              final b = banners[i];
              final g = _gradients[i % _gradients.length];
              final cat = b.categoryId == null ? null : Catalog.category(b.categoryId!);
              return GestureDetector(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => SearchScreen(categoryId: b.categoryId, autofocus: false))),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(20)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (b.imageUrl != null)
                        CachedNetworkImage(imageUrl: b.imageUrl!, fit: BoxFit.cover)
                      else if (cat != null)
                        Positioned(right: -20, bottom: -24, child: CategoryIcon(category: cat, size: 150, opacity: 0.22)),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(b.title,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(b.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Text('Shop now',
                                  style: TextStyle(color: g.colors.first, fontWeight: FontWeight.w700, fontSize: 12)),
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
        if (banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              banners.length,
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
        itemCount: Catalog.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = Catalog.categories[i];
          return GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => SearchScreen(categoryId: c.id, autofocus: false))),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                    child: CategoryIcon(category: c, size: 38),
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Icon(Icons.local_offer_rounded, color: AppColors.orange),
          SizedBox(width: 6),
          Text('Deals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
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
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Got something to sell?',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Post it free and reach buyers across Sierra Leone.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, minimumSize: const Size(90, 44)),
              onPressed: () => MainShell.goTo(context, -1),
              child: const Text('Sell'),
            ),
          ],
        ),
      ),
    );
  }
}
