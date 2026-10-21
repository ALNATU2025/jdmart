import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/product_image.dart';
import '../../shared/widgets/qty_stepper.dart';
import '../../state/cart_provider.dart';
import '../../state/session_provider.dart';
import '../../state/wishlist_provider.dart';
import '../auth/auth_guard.dart';
import '../cart/cart_screen.dart';
import '../chat/chat_screen.dart';
import '../sell/add_product_screen.dart';
import 'seller_profile_screen.dart';
import '../../core/theme/palette.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductRepository _repo = context.read<ProductRepository>();
  late final Stream<Product?> _product = _repo.watch(widget.productId);
  late final Stream<List<Review>> _reviews = _repo.reviews(widget.productId);
  Stream<List<Product>>? _similar;
  Stream<AppUser?>? _seller;
  int _img = 0;
  int _qty = 1;
  bool _viewCounted = false;

  void _countView(Product p) {
    if (_viewCounted) return;
    _viewCounted = true;
    if (context.read<SessionProvider>().uid != p.sellerId) _repo.registerView(p.id);
  }

  @override
  Widget build(BuildContext context) {
    // Provider selects must run in this build method, not inside the stream builder.
    final uid = context.select<SessionProvider, String?>((s) => s.uid);
    final saved = context.select<WishlistProvider, bool>((w) => w.isSaved(widget.productId));
    final myCity = Catalog.safeCity(context.select<SessionProvider, String?>((s) => s.profile?.city));
    return StreamBuilder<Product?>(
      stream: _product,
      builder: (_, snap) {
        final removed = snap.hasError && snap.error.toString().contains('permission-denied');
        if (snap.hasError && !removed) return Scaffold(appBar: AppBar(), body: ErrorView(error: snap.error));
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const LoadingView());
        }
        final p = snap.data;
        if (removed || p == null || (p.status == ProductStatus.hidden && uid != p.sellerId)) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
                icon: Icons.inventory_2_outlined, title: 'Listing removed', message: 'This item is no longer available.'),
          );
        }
        _countView(p);
        _similar ??= _repo.byCategory(p.categoryId, limit: 9);
        _seller ??= context.read<UserRepository>().watch(p.sellerId);
        return _page(p, uid: uid, saved: saved, myCity: myCity);
      },
    );
  }

  Widget _page(Product p, {required String? uid, required bool saved, required String myCity}) {
    final isMine = uid == p.sellerId;
    final cat = Catalog.category(p.categoryId);
    final images = p.images.isEmpty ? <String?>[null] : p.images.cast<String?>();
    if (_qty > p.stock && p.stock > 0) _qty = p.stock;

    return Scaffold(
      backgroundColor: context.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.width.clamp(280.0, 460.0).toDouble(),
            pinned: true,
            backgroundColor: context.surface,
            leading: _circleBtn(Icons.arrow_back_rounded, () => Navigator.pop(context), 'Back'),
            actions: [
              _circleBtn(Icons.share_outlined, () {
                Clipboard.setData(ClipboardData(text: '${p.title} — ${Fmt.price(p.price)} on JDMart (${p.city})'));
                showSnack(context, 'Listing details copied — paste them into WhatsApp to share');
              }, 'Share'),
              if (!isMine)
                _circleBtn(
                  saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  () async {
                    if (!await ensureLoggedIn(context)) return;
                    if (mounted) context.read<WishlistProvider>().toggle(p.id);
                  },
                  'Save',
                  color: saved ? AppColors.danger : AppColors.navy,
                ),
              if (!isMine)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (_) => _report(p),
                  itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report this listing'))],
                ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _img = i),
                    itemBuilder: (_, i) => ProductImage(url: images[i], categoryId: p.categoryId, iconSize: 110),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 14,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _img == i ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _img == i ? AppColors.orange : Colors.white70,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _tag(cat.name, cat.color),
                      _tag(p.condition, AppColors.navy),
                      if (p.negotiable) _tag('Negotiable', AppColors.success),
                      if (p.isSold) _tag('Sold', AppColors.danger),
                      if (p.status == ProductStatus.hidden) _tag('Hidden', context.muted),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(p.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (p.ratingCount > 0) ...[
                        RatingStars(rating: p.ratingAvg, size: 17),
                        const SizedBox(width: 6),
                        Text('${p.ratingAvg.toStringAsFixed(1)} (${p.ratingCount})',
                            style: TextStyle(color: context.muted, fontSize: 13)),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.schedule_rounded, size: 15, color: context.muted),
                      const SizedBox(width: 4),
                      Text('Listed ${Fmt.ago(p.createdAt)}', style: TextStyle(color: context.muted, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 10,
                    children: [
                      Text(Fmt.price(p.price),
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.brand)),
                      if (p.oldPrice != null && p.discountPercent > 0) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(Fmt.price(p.oldPrice!),
                              style: TextStyle(
                                  color: context.muted, decoration: TextDecoration.lineThrough, fontSize: 14)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _tag('-${p.discountPercent}%', AppColors.orange),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.available ? '${p.stock} available' : 'Out of stock',
                    style: TextStyle(
                        color: p.available ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  if (p.available && !isMine && p.stock > 1) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        QtyStepper(value: _qty, max: p.stock, onChanged: (v) => setState(() => _qty = v)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  _deliveryInfo(p, myCity),
                  const SizedBox(height: 22),
                  const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SelectableText(p.description,
                      style: TextStyle(color: context.muted, height: 1.6, fontSize: 14)),
                  const SizedBox(height: 22),
                  _sellerCard(p),
                  const SizedBox(height: 22),
                  _reviewsSection(p, isMine),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<Product>>(
              stream: _similar,
              builder: (_, s) {
                final items = (s.data ?? const <Product>[]).where((x) => x.id != p.id).take(8).toList();
                if (items.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [const SectionHeader(title: 'You may also like'), ProductStrip(items)],
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
      bottomNavigationBar: _bottomBar(p, isMine),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, String tooltip, {Color color = AppColors.navy}) => Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: context.surface,
          shape: const CircleBorder(),
          elevation: 1,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Tooltip(
              message: tooltip,
              child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 21, color: color)),
            ),
          ),
        ),
      );

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _deliveryInfo(Product p, String city) {
    final sameCity = city == p.city;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.soft, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _infoRow(Icons.location_on_outlined, 'Item location', p.city),
          const Divider(height: 18),
          _infoRow(Icons.local_shipping_outlined, 'Delivery to $city',
              '${Fmt.price(Catalog.deliveryFee(city))} • ${sameCity ? 'usually 1 day' : 'usually 1–3 days'}'),
          const Divider(height: 18),
          _infoRow(Icons.verified_user_outlined, 'Payment', 'Mobile money, card or cash on delivery'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 20, color: context.brand),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: context.muted, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      );

  Widget _sellerCard(Product p) {
    return StreamBuilder<AppUser?>(
      stream: _seller,
      builder: (_, s) {
        final seller = s.data;
        final name = seller?.name ?? p.sellerName;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => SellerProfileScreen(sellerId: p.sellerId))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: context.line)),
            child: Row(
              children: [
                UserAvatar(name: name, imageUrl: seller?.avatarUrl, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          if (seller?.verified ?? p.sellerVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified_rounded, color: context.brand, size: 17),
                          ],
                        ],
                      ),
                      Text(
                        [
                          if (seller != null && seller.ratingCount > 0)
                            '★ ${seller.ratingAvg.toStringAsFixed(1)} (${seller.ratingCount})',
                          if (seller != null) 'Joined ${Fmt.date(seller.joinedAt)}',
                        ].join(' • '),
                        style: TextStyle(color: context.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.muted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reviewsSection(Product p, bool isMine) {
    return StreamBuilder<List<Review>>(
      stream: _reviews,
      builder: (_, s) {
        final reviews = s.data ?? const <Review>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Reviews${p.ratingCount > 0 ? ' (${p.ratingCount})' : ''}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (!isMine)
                  TextButton.icon(
                    onPressed: () => _writeReview(p),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Write review'),
                  ),
              ],
            ),
            if (reviews.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No reviews yet. Buyers can review after delivery.', style: TextStyle(color: context.muted)),
              ),
            ...reviews.map((r) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(name: r.userName, radius: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(r.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const Spacer(),
                                Text(Fmt.ago(r.at), style: TextStyle(color: context.muted, fontSize: 11)),
                              ],
                            ),
                            RatingStars(rating: r.rating.toDouble(), size: 13),
                            if (r.comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(r.comment, style: const TextStyle(fontSize: 13, height: 1.4)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }

  Future<void> _writeReview(Product p) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final session = context.read<SessionProvider>();
    if (!await _repo.canReview(session.uid!, p.id)) {
      if (mounted) showSnack(context, 'You can review this item after it has been delivered to you.', error: true);
      return;
    }
    if (!mounted) return;
    int rating = 5;
    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Rate this item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: () => setS(() => rating = i + 1),
                    icon: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFFFB400), size: 36),
                  ),
                ),
              ),
              TextField(
                controller: ctrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(hintText: 'Share your experience (optional)'),
              ),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit review')),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final me = session.profile!;
    final parts = me.name.trim().split(RegExp(r'\s+'));
    final short = parts.length > 1 ? '${parts.first} ${parts[1][0]}.' : parts.first;
    final err = await runWithProgress(context, () => _repo.submitReview(
          productId: p.id,
          uid: me.id,
          userName: short,
          rating: rating,
          comment: ctrl.text,
        ));
    if (mounted) showSnack(context, err ?? 'Thanks for your review!', error: err != null);
  }

  Future<void> _report(Product p) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    const reasons = ['Scam or fraud', 'Counterfeit item', 'Prohibited item', 'Wrong category or details', 'Other'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Why are you reporting this?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            ...reasons.map((r) => ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r))),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    final uid = context.read<SessionProvider>().uid!;
    await _repo.report(productId: p.id, uid: uid, reason: reason);
    if (mounted) showSnack(context, 'Thanks — our team will review this listing.');
  }

  Widget _bottomBar(Product p, bool isMine) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: isMine
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    onPressed: () => _repo.setStatus(
                        p.id, p.status == ProductStatus.active ? ProductStatus.sold : ProductStatus.active),
                    icon: Icon(p.status == ProductStatus.active ? Icons.check_circle_outline : Icons.replay_rounded),
                    label: Text(p.status == ProductStatus.active ? 'Mark sold' : 'Relist'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(existing: p))),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(52, 52)),
                    onPressed: () => _chat(p),
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    onPressed: p.available ? () => _addToCart(p) : null,
                    child: const Text('Add to cart'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, minimumSize: const Size(0, 52)),
                    onPressed: p.available ? () => _buyNow(p) : null,
                    child: const Text('Buy now'),
                  ),
                ),
              ],
            ),
    );
  }

  bool _addToCart(Product p, {bool quiet = false}) {
    final err = context.read<CartProvider>().add(p, qty: _qty);
    if (err != null) {
      showSnack(context, err, error: true);
    } else if (!quiet) {
      showSnack(context, 'Added to cart');
    }
    return err == null;
  }

  void _buyNow(Product p) {
    if (context.read<CartProvider>().quantityOf(p.id) == 0 && !_addToCart(p, quiet: true)) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  Future<void> _chat(Product p) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final me = context.read<SessionProvider>().profile!;
    String? id;
    final err = await runWithProgress(context, () async {
      id = await context.read<ChatRepository>().open(buyerId: me.id, buyerName: me.name, product: p);
    }, label: 'Opening chat…');
    if (!mounted) return;
    if (err != null || id == null) {
      showSnack(context, "Couldn't open the chat. Check your connection.", error: true);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id!)));
  }
}
