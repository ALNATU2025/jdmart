import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ad_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/services/local_store.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../catalog/product_detail_screen.dart';

/// One deal shown in the reward-style pop-up.
class DealOffer {
  final String productId;
  final String title;
  final String? imageUrl;
  final double price;
  final double? oldPrice;
  final String sellerName;
  final String city;
  final bool sponsored; // paid ad (otherwise a free spot for an active seller)

  const DealOffer({
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.oldPrice,
    required this.sellerName,
    required this.city,
    required this.sponsored,
  });

  double get saving => (oldPrice != null && oldPrice! > price) ? oldPrice! - price : 0;
  int get discount => (oldPrice != null && oldPrice! > price && oldPrice! > 0) ? ((saving / oldPrice!) * 100).round() : 0;

  factory DealOffer.fromAd(SponsoredAd a) => DealOffer(
        productId: a.productId,
        title: a.title,
        imageUrl: a.imageUrl,
        price: a.price,
        oldPrice: a.oldPrice,
        sellerName: a.sellerName,
        city: a.city,
        sponsored: true,
      );

  factory DealOffer.fromProduct(Product p) => DealOffer(
        productId: p.id,
        title: p.title,
        imageUrl: p.cover,
        price: p.price,
        oldPrice: p.oldPrice,
        sellerName: p.sellerName,
        city: p.city,
        sponsored: false,
      );
}

/// Decides when the deal pop-up appears while someone is browsing:
///  • paid ads: every [AdSettings.dealEveryMinutes] minutes of use, rotating;
///  • free spots: discounted items from active sellers (listed in the last
///    2 weeks, with a photo), up to [AdSettings.freePerDay] times a day, for
///    a share of users each day ([AdSettings.freeSharePercent]).
class DealPopups {
  static final _rand = math.Random();
  static DateTime? _lastShown;
  static DateTime _sessionStart = DateTime.now();

  static String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static void newSession() => _sessionStart = DateTime.now();

  static void markShown() => _lastShown = DateTime.now();

  /// The deals to show now (3–5 when there are enough), or an empty list.
  static Future<List<DealOffer>> next(BuildContext context) async {
    final now = DateTime.now();
    if (now.difference(_sessionStart) < const Duration(seconds: 50)) return const []; // let them settle in first
    final last = _lastShown;
    final adsRepo = context.read<AdRepository>();
    final products = context.read<ProductRepository>();
    final s = await adsRepo.settingsOnce();
    if (!s.enabled) return const [];

    // Free spots for active sellers come first when due (only a couple a day),
    // otherwise paid ads would always take the slot.
    if (last == null || now.difference(last) >= const Duration(minutes: 2)) {
      final free = await _freeDeals(products, s, now, count: 3, countsAsSlot: true);
      if (free.isNotEmpty) return free;
    }

    // Paid ads: throughout the session, rotating through every live ad.
    if (last == null || now.difference(last) >= Duration(minutes: s.dealEveryMinutes)) {
      final ads = (await adsRepo.liveOnce()).where((a) => (a.imageUrl ?? '').isNotEmpty).toList();
      if (ads.isNotEmpty) {
        // Start with a different paid ad each time, show up to 5.
        final turn = (int.tryParse(LocalStore.getString('deal_turn') ?? '') ?? 0) % ads.length;
        await LocalStore.setString('deal_turn', '${turn + 1}');
        final paid = [for (var i = 0; i < math.min(ads.length, 5); i++) DealOffer.fromAd(ads[(turn + i) % ads.length])];
        if (paid.length >= 3) return paid;
        // Fewer than 3 paid ads: fill up with top-seller discounts.
        final taken = paid.map((o) => o.productId).toSet();
        final extra = await _freeDeals(products, s, now, count: 5 - paid.length, exclude: taken, countsAsSlot: false);
        return [...paid, ...extra];
      }
    }
    return const [];
  }

  /// Discounted items from active sellers. As its own pop-up ([countsAsSlot])
  /// it's limited to a share of users and a few times a day; as filler next to
  /// paid ads it isn't.
  static Future<List<DealOffer>> _freeDeals(
    ProductRepository products,
    AdSettings s,
    DateTime now, {
    required int count,
    Set<String> exclude = const {},
    required bool countsAsSlot,
  }) async {
    var used = 0;
    if (countsAsSlot) {
      final day = _today;
      if (LocalStore.getString('free_deal_day') != day) {
        await LocalStore.setString('free_deal_day', day);
        await LocalStore.setString('free_deal_count', '0');
        await LocalStore.setBool('free_deal_lucky', _rand.nextInt(100) < s.freeSharePercent);
        await LocalStore.setString('free_deal_last', '0');
      }
      if (!LocalStore.getBool('free_deal_lucky')) return const [];
      used = int.tryParse(LocalStore.getString('free_deal_count') ?? '') ?? 0;
      if (used >= s.freePerDay) return const [];
      final lastFree = int.tryParse(LocalStore.getString('free_deal_last') ?? '') ?? 0;
      if (now.millisecondsSinceEpoch - lastFree < const Duration(hours: 2).inMilliseconds) return const [];
    }

    List<Product> deals;
    try {
      deals = await products.deals(limit: 30).first.timeout(const Duration(seconds: 8));
    } catch (_) {
      return const [];
    }
    final fresh = now.subtract(const Duration(days: 14));
    final pool = deals
        .where((p) => p.available && p.cover != null && p.createdAt.isAfter(fresh) && !exclude.contains(p.id))
        .toList();
    if (pool.isEmpty) return const [];
    // Verified / well-rated sellers first, with some variety.
    pool.sort((a, b) => _score(b).compareTo(_score(a)));
    final top = pool.take(math.max(count * 2, 6)).toList()..shuffle(_rand);
    final picks = top.take(count).map(DealOffer.fromProduct).toList();
    if (countsAsSlot && picks.isNotEmpty) {
      await LocalStore.setString('free_deal_count', '${used + 1}');
      await LocalStore.setString('free_deal_last', '${now.millisecondsSinceEpoch}');
    }
    return picks;
  }

  static double _score(Product p) =>
      (p.sellerVerified ? 2 : 0) + p.ratingAvg / 2.5 + p.discountPercent / 25 + _rand.nextDouble();
}

/// Reward-style pop-up: big headline, glowing deal card with floating coins,
/// shiny "Shop now" button and a round close button.
Future<void> showDealPopup(BuildContext context, List<DealOffer> offers) async {
  if (offers.isEmpty) return;
  final img = offers.first.imageUrl;
  if (img != null) {
    try {
      await precacheImage(netImageProvider(img), context).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
  if (!context.mounted) return;
  DealPopups.markShown();
  final go = await showGeneralDialog<DealOffer>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => _DealPopup(offers: offers),
    transitionBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.elasticOut, reverseCurve: Curves.easeInCubic);
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4 * a.value, sigmaY: 4 * a.value),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(c), child: child),
        ),
      );
    },
  );
  if (go != null && context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: go.productId)));
  }
}

const _gold = Color(0xFFFFD84D);
const _goldDeep = Color(0xFFF5A300);

class _DealPopup extends StatefulWidget {
  final List<DealOffer> offers;
  const _DealPopup({required this.offers});

  @override
  State<_DealPopup> createState() => _DealPopupState();
}

class _DealPopupState extends State<_DealPopup> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  final _pager = PageController();
  Timer? _auto;
  int _index = 0;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    if (widget.offers.length > 1) {
      _auto = Timer.periodic(const Duration(milliseconds: 3800), (_) {
        if (_touched || !_pager.hasClients) return;
        _pager.animateToPage((_index + 1) % widget.offers.length,
            duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final o in widget.offers.skip(1)) {
          final u = o.imageUrl;
          if (u != null && mounted) precacheImage(netImageProvider(u), context).catchError((Object _) {});
        }
      });
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pager.dispose();
    _c.dispose();
    super.dispose();
  }

  (String, String, String) _headline(DealOffer o) {
    if (o.saving > 0) return ('Save ', Fmt.price(o.saving), ' On This Deal!');
    if (o.discount > 0) return ('', '${o.discount}% OFF', ' Is Waiting For You!');
    return ('Hot Deal ', 'Just For You', '!');
  }

  @override
  Widget build(BuildContext context) {
    final offers = widget.offers;
    final o = offers[_index.clamp(0, offers.length - 1)];
    final (a, highlight, b) = offers.length > 1 && _index == 0 && offers.first.saving == 0 && offers.first.discount == 0
        ? ('', '${offers.length} Hot Deals', ' Picked For You!')
        : _headline(o);
    final width = math.min(MediaQuery.sizeOf(context).width - 32, 400.0);
    final headline = TextStyle(
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 14)],
    );

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glow behind the headline
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (c, an) => FadeTransition(
                    opacity: an,
                    child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(an), child: c),
                  ),
                  child: Text.rich(
                    key: ValueKey('h$_index'),
                    TextSpan(children: [
                      TextSpan(text: a),
                      TextSpan(text: highlight, style: const TextStyle(color: _gold)),
                      TextSpan(text: b),
                    ]),
                    textAlign: TextAlign.center,
                    style: headline,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: width * 0.92,
                  child: Listener(
                    onPointerDown: (_) => _touched = true,
                    child: PageView.builder(
                      controller: _pager,
                      itemCount: offers.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) => AnimatedBuilder(
                        animation: _c,
                        builder: (_, __) => _scene(width, offers[i]),
                      ),
                    ),
                  ),
                ),
                if (offers.length > 1) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < offers.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _index ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _index ? _gold : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _ShinyButton(
                  label: o.discount > 0 ? 'Shop Now' : 'View Deal',
                  progress: _c,
                  onTap: () => Navigator.pop(context, o),
                ),
                const SizedBox(height: 26),
                Pressable(
                  onTap: () => Navigator.pop(context),
                  scale: 0.85,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scene(double w, DealOffer o) {
    final t = _c.value * 2 * math.pi;
    final cardW = w * 0.68;
    final cardH = cardW * 1.08;

    Widget coin(double size, double dx, double dy, double phase) {
      final y = math.sin(t + phase) * 8;
      final r = math.sin(t * 0.8 + phase) * 0.5;
      return Positioned(
        left: w / 2 + dx - size / 2,
        top: w * 0.46 + dy + y - size / 2,
        child: Transform.rotate(
          angle: r,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFFFFE680), _goldDeep], center: Alignment(-0.3, -0.4)),
              boxShadow: [BoxShadow(color: _goldDeep.withValues(alpha: 0.6), blurRadius: 10)],
              border: Border.all(color: const Color(0xFFFFF3B0), width: 2),
            ),
            alignment: Alignment.center,
            child: Text('Le',
                style: TextStyle(color: const Color(0xFF9A5B00), fontWeight: FontWeight.w900, fontSize: size * 0.36)),
          ),
        ),
      );
    }

    Widget sparkle(double dx, double dy, double phase, double size) {
      final s = (math.sin(t * 2 + phase) + 1) / 2;
      return Positioned(
        left: w / 2 + dx,
        top: w * 0.46 + dy,
        child: Opacity(
          opacity: 0.3 + 0.7 * s,
          child: Transform.scale(scale: 0.6 + 0.6 * s, child: Icon(Icons.auto_awesome, color: Colors.white, size: size)),
        ),
      );
    }

    final tilt = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..translateByDouble(0, math.sin(t) * 6, 0, 1)
      ..rotateX(0.10 + math.cos(t) * 0.04)
      ..rotateY(math.sin(t) * 0.18)
      ..rotateZ(-0.05);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Soft golden glow
        Positioned.fill(
          child: Center(
            child: Container(
              width: w * 0.9,
              height: w * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _gold.withValues(alpha: 0.35 + 0.1 * math.sin(t)),
                  _gold.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),
        ),
        // Light rays
        Positioned.fill(
          child: Center(
            child: Transform.rotate(
              angle: _c.value * math.pi / 2,
              child: CustomPaint(size: Size(w * 0.95, w * 0.95), painter: _RaysPainter()),
            ),
          ),
        ),
        coin(46, -cardW * 0.55, -cardH * 0.42, 0),
        coin(38, cardW * 0.52, -cardH * 0.30, 1.4),
        coin(30, -cardW * 0.62, cardH * 0.18, 2.6),
        coin(52, cardW * 0.42, cardH * 0.36, 3.7),
        // The deal card
        Center(
          child: Transform(
            alignment: Alignment.center,
            transform: tilt,
            child: Container(
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B3D2E), Color(0xFF14704F), Color(0xFF0F5A40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: _gold.withValues(alpha: 0.9), width: 2.5),
                boxShadow: [
                  BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 2),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 16)),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              color: Colors.white,
                              child: o.imageUrl == null
                                  ? const Icon(Icons.shopping_bag_rounded, size: 64, color: Color(0xFF14704F))
                                  : NetImage(
                                      url: o.imageUrl!,
                                      error: () =>
                                          const Icon(Icons.shopping_bag_rounded, size: 64, color: Color(0xFF14704F))),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(o.sponsored ? 'SPONSORED' : 'TOP SELLER DEAL',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(o.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.price(o.price),
                          style: const TextStyle(color: _gold, fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
                      if (o.oldPrice != null && o.oldPrice! > o.price) ...[
                        const SizedBox(width: 8),
                        Text(Fmt.price(o.oldPrice!),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 13, decoration: TextDecoration.lineThrough)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [o.sellerName, if (o.city.isNotEmpty) o.city].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Discount sticker
        if (o.discount > 0)
          Positioned(
            right: (w - cardW) / 2 - 18,
            top: w * 0.46 - cardH / 2 - 14,
            child: Transform.rotate(
              angle: 0.25 + math.sin(t * 2) * 0.06,
              child: Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE11D48),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10)],
                ),
                child: Text('-${o.discount}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            ),
          ),
        sparkle(-cardW * 0.62, -cardH * 0.10, 0.5, 18),
        sparkle(cardW * 0.50, cardH * 0.05, 2.0, 22),
        sparkle(-cardW * 0.25, -cardH * 0.62, 3.3, 14),
        sparkle(cardW * 0.18, cardH * 0.55, 4.4, 16),
      ],
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [_gold.withValues(alpha: 0.22), _gold.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.09), c.dy + r * math.sin(a - 0.09))
        ..lineTo(c.dx + r * math.cos(a + 0.09), c.dy + r * math.sin(a + 0.09))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glossy yellow pill with a moving shine.
class _ShinyButton extends StatelessWidget {
  final String label;
  final Animation<double> progress;
  final VoidCallback onTap;
  const _ShinyButton({required this.label, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      haptic: true,
      scale: 0.95,
      onTap: onTap,
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, __) {
          final pulse = 1 + math.sin(progress.value * 4 * math.pi) * 0.025;
          final shine = -1.5 + progress.value * 4;
          return Transform.scale(
            scale: pulse,
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(33),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF27A), _gold, _goldDeep],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: const Color(0xFFFFF8C9), width: 2.5),
                boxShadow: [
                  BoxShadow(color: _goldDeep.withValues(alpha: 0.55), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(33),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(shine - 0.4, -1),
                            end: Alignment(shine + 0.4, 1),
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(label,
                        style: const TextStyle(color: Color(0xFF5A2D00), fontSize: 24, fontWeight: FontWeight.w900)),
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
