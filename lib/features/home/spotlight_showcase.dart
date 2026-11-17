import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/constants/jobs_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/job_repository.dart';
import '../../data/repositories/misc_repositories.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/category_icon.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../catalog/product_detail_screen.dart';
import '../catalog/search_screen.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_widgets.dart';

/// One card in the spotlight pop-up.
class SpotlightSlide {
  final String tag; // pill on the hero, e.g. "JUST LISTED", "-25% OFF"
  final String heroTop; // white line on the hero
  final String heroAccent; // yellow line on the hero
  final String title;
  final String body;
  final String cta;
  final List<Color> colors; // hero gradient
  final String? imageUrl;
  final bool wideImage; // banners: fill the hero instead of a floating card
  final Widget fallback; // shown when there's no image or it fails to load
  final Widget? art; // custom floating art (jobs)
  final String? price;
  final String? oldPrice;
  final int discount;
  final void Function(BuildContext context) open;

  const SpotlightSlide({
    required this.tag,
    required this.heroTop,
    required this.heroAccent,
    required this.title,
    required this.body,
    required this.cta,
    required this.colors,
    required this.fallback,
    required this.open,
    this.imageUrl,
    this.wideImage = false,
    this.art,
    this.price,
    this.oldPrice,
    this.discount = 0,
  });
}

const _blueHero = [Color(0xFF0B1B6B), Color(0xFF1A2DB8), Color(0xFF3D5AFE)];
const _orangeHero = [Color(0xFF7A1F00), Color(0xFFD94A00), Color(0xFFFB8B24)];
const _purpleHero = [Color(0xFF2B0A5E), Color(0xFF4A1BA8), Color(0xFF7C3AED)];
const _greenHero = [Color(0xFF053B2A), Color(0xFF0F7A4F), Color(0xFF22B573)];

Future<T?> _first<T>(Stream<T> s) => s.first.timeout(const Duration(seconds: 8)).then<T?>((v) => v).catchError((Object _) => null);

/// Collects the newest listings (at least 5 when there are that many),
/// discounts, admin promos and new jobs, mixed into one deck.
Future<List<SpotlightSlide>> loadSpotlight(BuildContext context) async {
  final products = context.read<ProductRepository>();
  final banners = context.read<BannerRepository>();
  final jobs = context.read<JobRepository>();

  final results = await Future.wait<Object?>([
    _first(products.newest(limit: 16)),
    _first(products.deals(limit: 10)),
    _first(banners.active()),
    _first(jobs.openJobs(limit: 4)),
  ]);
  final newest = ((results[0] as List<Product>?) ?? const <Product>[])
      .where((p) => p.available && p.cover != null)
      .take(6)
      .toList();
  final seen = newest.map((p) => p.id).toSet();
  final deals = ((results[1] as List<Product>?) ?? const <Product>[])
      .where((p) => p.available && p.cover != null && p.discountPercent > 0 && !seen.contains(p.id))
      .take(2)
      .toList();
  final promos = ((results[2] as List<PromoBanner>?) ?? const <PromoBanner>[])
      .where((b) => (b.imageUrl ?? '').isNotEmpty)
      .take(2)
      .toList();
  final openJobs = ((results[3] as List<Job>?) ?? const <Job>[]).take(2).toList();

  final productSlides = [for (final p in newest) _productSlide(p, deal: false)];
  final dealSlides = [for (final p in deals) _productSlide(p, deal: true)];
  final promoSlides = [for (final b in promos) _bannerSlide(b)];
  final jobSlides = [for (final j in openJobs) _jobSlide(j)];

  // Mix: new, new, deal, job, new, promo, new, deal, job, new, promo, new...
  final out = <SpotlightSlide>[];
  final queues = [productSlides, productSlides, dealSlides, jobSlides, productSlides, promoSlides];
  var guard = 0;
  while ((productSlides.isNotEmpty || dealSlides.isNotEmpty || jobSlides.isNotEmpty || promoSlides.isNotEmpty) &&
      guard++ < 60) {
    final q = queues[guard % queues.length];
    if (q.isNotEmpty) out.add(q.removeAt(0));
  }
  return out;
}

SpotlightSlide _productSlide(Product p, {required bool deal}) {
  final cat = Catalog.category(p.categoryId);
  final off = p.discountPercent;
  final hasOld = p.oldPrice != null && p.oldPrice! > p.price;
  final emoji = off > 0 ? '🔥' : (p.condition == 'New' ? '✨' : '🛍️');
  return SpotlightSlide(
    tag: off > 0 ? '-$off% OFF' : (deal ? 'HOT DEAL' : 'JUST LISTED'),
    heroTop: off > 0 ? 'Save $off%' : 'Fresh on',
    heroAccent: off > 0 ? 'Today only' : 'JDMart',
    title: '${p.title} $emoji',
    body: [
      if (p.condition.isNotEmpty) p.condition,
      p.city,
      if (p.negotiable) 'Price negotiable',
      'Sold by ${p.sellerName}${p.sellerVerified ? ' ✔' : ''}',
    ].join(' • '),
    cta: off > 0 ? 'Grab the deal' : 'View item',
    colors: off > 0 ? _orangeHero : _blueHero,
    imageUrl: p.cover,
    fallback: Center(child: CategoryIcon(category: cat, size: 72)),
    price: Fmt.price(p.price),
    oldPrice: hasOld ? Fmt.price(p.oldPrice!) : null,
    discount: off,
    open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
  );
}

SpotlightSlide _bannerSlide(PromoBanner b) => SpotlightSlide(
      tag: 'PROMO',
      heroTop: '',
      heroAccent: '',
      title: b.title.isEmpty ? 'Special offer 🎁' : '${b.title} 🎁',
      body: b.subtitle.isEmpty ? 'Limited-time offers from sellers across Sierra Leone.' : b.subtitle,
      cta: 'See offers',
      colors: _purpleHero,
      imageUrl: b.imageUrl,
      wideImage: true,
      fallback: const Center(child: Icon(Icons.local_offer_rounded, color: Colors.white, size: 72)),
      open: (c) => Navigator.push(
          c, MaterialPageRoute(builder: (_) => SearchScreen(categoryId: b.categoryId, autofocus: false))),
    );

SpotlightSlide _jobSlide(Job j) {
  final cat = JobsCatalog.category(j.categoryId);
  return SpotlightSlide(
    tag: 'NEW JOB',
    heroTop: 'Now hiring',
    heroAccent: j.city,
    title: '${j.title} 💼',
    body: '${j.company} is hiring in ${j.city} • ${j.type}. Apply in the app — it only takes a minute.',
    cta: 'Apply now',
    colors: _greenHero,
    art: _JobArt(job: j, color: cat.color),
    fallback: const SizedBox.shrink(),
    price: j.salary.isEmpty ? null : j.salary,
    open: (c) => Navigator.push(c, MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: j.id))),
  );
}

/// Shows the deck. Returns when it is closed.
Future<void> showSpotlight(BuildContext context, List<SpotlightSlide> slides) async {
  if (slides.isEmpty) return;
  final first = slides.first.imageUrl;
  if (first != null) {
    try {
      await precacheImage(netImageProvider(first), context).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
  if (!context.mounted) return;
  final picked = await showGeneralDialog<SpotlightSlide>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (_, __, ___) => _SpotlightDeck(slides: slides),
    transitionBuilder: (_, a, __, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6 * a.value, sigmaY: 6 * a.value),
        child: FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curved),
            child: ScaleTransition(scale: Tween(begin: 0.86, end: 1.0).animate(curved), child: child),
          ),
        ),
      );
    },
  );
  if (picked != null && context.mounted) picked.open(context);
}

class _SpotlightDeck extends StatefulWidget {
  final List<SpotlightSlide> slides;
  const _SpotlightDeck({required this.slides});

  @override
  State<_SpotlightDeck> createState() => _SpotlightDeckState();
}

class _SpotlightDeckState extends State<_SpotlightDeck> {
  final _pager = PageController();
  Timer? _auto;
  int _index = 0;
  bool _userTook = false;

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(milliseconds: 4200), (_) {
      if (_userTook || !_pager.hasClients) return;
      final next = (_index + 1) % widget.slides.length;
      _pager.animateToPage(next, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
    // Warm the next images so swiping feels instant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in widget.slides.skip(1).take(4)) {
        final u = s.imageUrl;
        if (u != null && mounted) precacheImage(netImageProvider(u), context).catchError((Object _) {});
      }
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = math.min(size.height * 0.8, 640.0);
    final slides = widget.slides;
    return Center(
      child: SizedBox(
        width: math.min(size.width - 32, 420),
        height: height,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Expanded(
                child: Listener(
                  onPointerDown: (_) => _userTook = true,
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: _pager,
                      builder: (_, child) {
                        var d = 0.0;
                        if (_pager.hasClients && _pager.position.haveDimensions) {
                          d = ((_pager.page ?? 0) - i).clamp(-1.0, 1.0);
                        }
                        return Transform.scale(
                          scale: 1 - d.abs() * 0.08,
                          child: Opacity(opacity: 1 - d.abs() * 0.4, child: child),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _SlideCard(slide: slides[i], index: i, count: slides.length),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.orange : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  final SpotlightSlide slide;
  final int index;
  final int count;
  const _SlideCard({required this.slide, required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    final s = slide;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 11, child: _Hero(slide: s, index: index, count: count)),
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
                  if (s.price != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(s.price!,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.brand)),
                        if (s.oldPrice != null)
                          Text(s.oldPrice!,
                              style: TextStyle(
                                  fontSize: 14, color: context.muted, decoration: TextDecoration.lineThrough)),
                        if (s.discount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('-${s.discount}%',
                                style: const TextStyle(
                                    color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(s.body,
                        maxLines: 4,
                        overflow: TextOverflow.fade,
                        style: TextStyle(color: context.muted, fontSize: 13.5, height: 1.45)),
                  ),
                  Pressable(
                    haptic: true,
                    scale: 0.96,
                    onTap: () => Navigator.pop(context, s),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [s.colors[0], s.colors[1]]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: s.colors[1].withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))
                        ],
                      ),
                      child: Text(s.cta,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final SpotlightSlide slide;
  final int index;
  final int count;
  const _Hero({required this.slide, required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    final s = slide;
    final image = s.imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: s.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        // Soft glowing circles, like the sample.
        Positioned(right: -40, top: -50, child: _Glow(size: 200, color: Colors.white.withValues(alpha: 0.10))),
        Positioned(left: -30, bottom: -60, child: _Glow(size: 160, color: Colors.white.withValues(alpha: 0.07))),
        if (s.wideImage && image != null)
          _SlowZoom(child: NetImage(url: image, error: () => s.fallback))
        else
          Row(
            children: [
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 46, 4, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.heroTop,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.05)),
                      Text(s.heroAccent,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFFFFE14D), fontSize: 22, fontWeight: FontWeight.w900, height: 1.15)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE14D),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.cta,
                                style: const TextStyle(
                                    color: Color(0xFF1B1B1B), fontSize: 11.5, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Color(0xFF1B1B1B), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 11,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 40, 18, 18),
                  child: _FloatingTilt(
                    child: s.art ??
                        AspectRatio(
                          aspectRatio: 0.9,
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 22,
                                    offset: const Offset(0, 14))
                              ],
                            ),
                            child: image == null ? s.fallback : NetImage(url: image, error: () => s.fallback),
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
        Positioned(
          left: 16,
          top: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: s.discount > 0 ? AppColors.danger : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: softShadow(2),
            ),
            child: Text(s.tag,
                style: TextStyle(
                  color: s.discount > 0 ? Colors.white : AppColors.orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.8,
                )),
          ),
        ),
        Positioned(
          right: 52,
          top: 18,
          child: Text('${index + 1}/$count',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Pressable(
            onTap: () => Navigator.pop(context),
            scale: 0.85,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

/// Floats up and down and slowly tilts in 3D (like the card in the sample).
class _FloatingTilt extends StatefulWidget {
  final Widget child;
  const _FloatingTilt({required this.child});

  @override
  State<_FloatingTilt> createState() => _FloatingTiltState();
}

class _FloatingTiltState extends State<_FloatingTilt> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value * 2 * math.pi;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..translateByDouble(0, math.sin(t) * 7, 0, 1)
          ..rotateY(math.sin(t) * 0.32)
          ..rotateX(math.cos(t) * 0.08)
          ..rotateZ(-0.06 + math.sin(t) * 0.03);
        return Transform(alignment: Alignment.center, transform: m, child: child);
      },
      child: Center(child: widget.child),
    );
  }
}

class _SlowZoom extends StatelessWidget {
  final Widget child;
  const _SlowZoom({required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.18, end: 1.0),
        duration: const Duration(milliseconds: 5000),
        curve: Curves.easeOutCubic,
        builder: (_, s, c) => Transform.scale(scale: s, child: c),
        child: child,
      );
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Floating "job card" art: company logo, title and salary.
class _JobArt extends StatelessWidget {
  final Job job;
  final Color color;
  const _JobArt({required this.job, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 14))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JobLogo(company: job.company, categoryId: job.categoryId, size: 44),
            const SizedBox(height: 10),
            Text(job.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF142237), fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(job.company,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6B7385), fontSize: 11.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(job.type, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ],
        ),
      );
}
