import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/misc_repositories.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/category_icon.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';
import '../account/wishlist_screen.dart';
import '../catalog/search_screen.dart';
import '../jobs/jobs_home_screen.dart';
import '../shell/main_shell.dart';
import '../../core/theme/palette.dart';
import '../../shared/widgets/theme_toggle.dart';

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
              backgroundColor: context.surface,
              titleSpacing: 12,
              title: const JDWordmark(size: 22),
              actions: [
                const ThemeToggleButton(),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
                  icon: const Icon(Icons.favorite_border_rounded),
                  tooltip: 'Saved items',
                ),
                const CartIconButton(),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(child: FadeSlideIn(child: _Greeting(name: name))),
            const SliverToBoxAdapter(
              child: FadeSlideIn(delay: Duration(milliseconds: 60), child: _SearchBar()),
            ),
            SliverToBoxAdapter(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: StreamBuilder<List<PromoBanner>>(
                  stream: _banners,
                  builder: (_, s) => _BannerCarousel([
                    ..._builtInSlides,
                    for (final b in s.data ?? const <PromoBanner>[])
                      _Slide(
                        banner: b,
                        glow: AppColors.blue,
                        onTap: (c) => _openCategory(c, b.categoryId),
                      ),
                  ]),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: SectionHeader(title: 'Categories', action: 'See all', onAction: () => MainShell.goTo(context, 1)),
              ),
            ),
            const SliverToBoxAdapter(child: _CategoryStrip()),
            const SliverToBoxAdapter(
              child: FadeSlideIn(delay: Duration(milliseconds: 260), child: _JobsPromo()),
            ),
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
                if (!s.hasData) return const ProductGridSkeleton();
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
            return FadeSlideIn(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, ProductStrip(items)]),
            );
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
          Text('$greet${name == null ? '' : ', $name'} 👋', style: TextStyle(color: context.muted, fontSize: 14)),
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
      child: Pressable(
        scale: 0.98,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: softShadow(),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: context.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Search phones, Gara, rice, cars…', style: TextStyle(color: context.muted, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One slide of the home carousel: a built-in banner image or a banner from Firestore.
class _Slide {
  final String? asset;
  final PromoBanner? banner;
  final Color glow;
  final void Function(BuildContext context) onTap;
  const _Slide({this.asset, this.banner, required this.glow, required this.onTap});
}

void _openCategory(BuildContext context, String? categoryId) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => SearchScreen(categoryId: categoryId, autofocus: false)));

/// Built-in promo banners shipped with the app (assets/images/banner1-3.png).
final List<_Slide> _builtInSlides = [
  _Slide(
    asset: 'assets/images/banner1.png',
    glow: const Color(0xFF1A2DB8),
    onTap: (c) => _openCategory(c, 'electronics'),
  ),
  _Slide(
    asset: 'assets/images/banner2.png',
    glow: const Color(0xFFF26A0A),
    onTap: (c) => _openCategory(c, 'fashion'),
  ),
  _Slide(
    asset: 'assets/images/banner3.png',
    glow: const Color(0xFF5B2BC0),
    onTap: (c) => MainShell.goTo(c, 1),
  ),
];

class _BannerCarousel extends StatefulWidget {
  final List<_Slide> slides;
  const _BannerCarousel(this.slides);

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  /// Width / height of the banner artwork.
  static const _aspect = 1440 / 316;
  final _pc = PageController(viewportFraction: 0.92);
  int _i = 0;
  bool _touching = false;
  Timer? _t;

  static const _gradients = [
    AppColors.brandGradient,
    AppColors.orangeGradient,
    LinearGradient(colors: [Color(0xFF5B2BC0), Color(0xFF8B5CF6)]),
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      final n = widget.slides.length;
      if (_touching || !_pc.hasClients || n < 2) return;
      _pc.animateToPage((_i + 1) % n, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final s in _builtInSlides) {
      precacheImage(AssetImage(s.asset!), context);
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    return LayoutBuilder(builder: (context, box) {
      // Keep banners a sensible size on wide screens (web / tablets).
      final width = box.maxWidth > 1100 ? 1100.0 : box.maxWidth;
      final height = (width * 0.92 - 12) / _aspect;
      return Center(
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Listener(
                onPointerDown: (_) => _touching = true,
                onPointerUp: (_) => _touching = false,
                onPointerCancel: (_) => _touching = false,
                child: SizedBox(
                  height: height + 14, // room for the glow shadow
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: slides.length,
                    onPageChanged: (i) => setState(() => _i = i),
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: _pc,
                      builder: (_, child) {
                        // Neighbouring slides shrink slightly for a depth effect.
                        final page = _pc.hasClients && _pc.position.haveDimensions ? (_pc.page ?? _i.toDouble()) : _i.toDouble();
                        final d = (page - i).abs().clamp(0.0, 1.0).toDouble();
                        return Transform.scale(scale: 1 - d * 0.06, child: Opacity(opacity: 1 - d * 0.35, child: child));
                      },
                      child: _slide(slides[i], i, height),
                    ),
                  ),
                ),
              ),
              if (slides.length > 1) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    slides.length,
                    (i) => GestureDetector(
                      onTap: () => _pc.animateToPage(i, duration: Motion.slow, curve: Curves.easeInOutCubic),
                      child: AnimatedContainer(
                        duration: Motion.medium,
                        curve: Motion.curve,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _i == i ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: _i == i ? AppColors.orangeGradient : null,
                          color: _i == i ? null : context.line,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _slide(_Slide s, int i, double height) {
    final Widget content;
    if (s.asset != null) {
      content = Image.asset(s.asset!, fit: BoxFit.cover, filterQuality: FilterQuality.medium, gaplessPlayback: true);
    } else {
      final b = s.banner!;
      final g = _gradients[i % _gradients.length];
      final cat = b.categoryId == null ? null : Catalog.category(b.categoryId!);
      content = DecoratedBox(
        decoration: BoxDecoration(gradient: g),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (b.imageUrl != null)
              NetImage(url: b.imageUrl!, error: () => const SizedBox.shrink())
            else if (cat != null)
              Positioned(right: -10, bottom: -14, child: CategoryIcon(category: cat, size: height, opacity: 0.22)),
            if (b.imageUrl == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(b.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(20)),
                        child: Text('Shop now',
                            style: TextStyle(color: g.colors.first, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
      child: Pressable(
        scale: 0.98,
        onTap: () => s.onTap(context),
        child: Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: s.glow.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 7))],
          ),
          child: content,
        ),
      ),
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
          return FadeSlideIn(
            delay: const Duration(milliseconds: 200) + Motion.stagger(i, stepMs: 35, maxSteps: 10),
            offset: const Offset(0.25, 0),
            child: Pressable(
            scale: 0.9,
            onTap: () => _openCategory(context, c.id),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [c.color.withValues(alpha: 0.16), c.color.withValues(alpha: 0.06)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
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
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.navy, Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8))],
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
                  Text('Post it free and reach buyers across Sierra Leone.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Pressable(
              scale: 0.92,
              haptic: true,
              onTap: () => MainShell.goTo(context, -1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.orangeGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Text('Sell', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entry to JDMart Jobs: find work, hire, share a CV.
class _JobsPromo extends StatelessWidget {
  const _JobsPromo();

  @override
  Widget build(BuildContext context) {
    void open(int tab) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => JobsHomeScreen(initialTab: tab)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Pressable(
        scale: 0.98,
        onTap: () => open(0),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF022A95), AppColors.blue, Color(0xFF3B5BDB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Floating(
                  distance: 5,
                  child: Icon(Icons.work_rounded, size: 120, color: Colors.white.withValues(alpha: 0.10)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(gradient: AppColors.orangeGradient, borderRadius: BorderRadius.circular(20)),
                      child: const Text('NEW • JDMart Jobs',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 10),
                    const Text('Find work. Hire talent.',
                        style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Post jobs, apply in minutes or share your CV with employers.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _pill(Icons.search_rounded, 'Find jobs', () => open(0)),
                        const SizedBox(width: 8),
                        _pill(Icons.groups_rounded, 'Find talent', () => open(1)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) => Pressable(
        scale: 0.92,
        onTap: onTap,
        child: Builder(builder: (context) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: context.brand),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: context.brand, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),)
      );
}
