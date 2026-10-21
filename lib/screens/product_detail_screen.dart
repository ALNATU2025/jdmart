import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import 'auth/login_screen.dart';
import 'cart_screen.dart';
import 'chat_screen.dart';
import 'sell/add_product_screen.dart';
import 'seller_profile_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _img = 0;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    context.read<ProductProvider>().registerView(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final p = products.byId(widget.productId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.inventory_2_outlined, title: 'Product removed', message: 'This listing is no longer available.'),
      );
    }
    final me = context.watch<AuthProvider>().user;
    final isMine = me?.id == p.sellerId;
    final cat = SeedData.category(p.categoryId);
    final wished = products.isWished(p.id);
    final similar = products.similar(p);
    final images = p.images.isEmpty ? <String?>[null] : p.images.cast<String?>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.width.clamp(280.0, 460.0).toDouble(),
            pinned: true,
            backgroundColor: Colors.white,
            leading: _circleBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
            actions: [
              _circleBtn(Icons.share_outlined, () {
                Clipboard.setData(ClipboardData(text: '${p.title} — ${Fmt.price(p.price)} on JDMart'));
                showSnack(context, 'Listing details copied — paste to share on WhatsApp');
              }),
              _circleBtn(
                wished ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                () => products.toggleWish(p.id),
                color: wished ? AppColors.danger : AppColors.navy,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _img = i),
                    itemBuilder: (_, i) =>
                        ProductImage(path: images[i], categoryId: p.categoryId, iconSize: 110),
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(p.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (p.reviews.isNotEmpty) ...[
                        RatingStars(rating: p.rating, size: 17),
                        const SizedBox(width: 6),
                        Text('${p.rating.toStringAsFixed(1)} (${p.reviews.length})',
                            style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                        const SizedBox(width: 12),
                      ],
                      const Icon(Icons.visibility_outlined, size: 15, color: AppColors.grey),
                      const SizedBox(width: 4),
                      Text('${p.views} views', style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.price(p.price),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.blue)),
                      const SizedBox(width: 10),
                      if (p.oldPrice != null && p.discountPercent > 0) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(Fmt.price(p.oldPrice!),
                              style: const TextStyle(
                                  color: AppColors.grey,
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _tag('-${p.discountPercent}%', AppColors.orange),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.available ? '${p.stock} in stock' : 'Out of stock',
                    style: TextStyle(
                        color: p.available ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  if (p.available && !isMine) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        _QtyStepper(
                          value: _qty,
                          max: p.stock,
                          onChanged: (v) => setState(() => _qty = v),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  _deliveryInfo(p),
                  const SizedBox(height: 22),
                  const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(p.description, style: const TextStyle(color: AppColors.grey, height: 1.6, fontSize: 14)),
                  const SizedBox(height: 22),
                  _sellerCard(context, p),
                  const SizedBox(height: 22),
                  _reviews(context, p, me),
                ],
              ),
            ),
          ),
          if (similar.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader(title: 'You may also like')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 278,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: similar.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => ProductCard(product: similar[i], width: 160),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
      bottomNavigationBar: _bottomBar(context, p, isMine),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color color = AppColors.navy}) => Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 1,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 21, color: color)),
          ),
        ),
      );

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _deliveryInfo(Product p) {
    final me = context.read<AuthProvider>().user;
    final city = me?.city ?? 'Freetown';
    final fee = SeedData.deliveryFees[city] ?? 100.0;
    final sameCity = city == p.city;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.greyLight, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _infoRow(Icons.location_on_outlined, 'Item location', p.city),
          const Divider(height: 18),
          _infoRow(Icons.local_shipping_outlined, 'Delivery to $city',
              '${Fmt.price(fee)} • ${sameCity ? 'Same day' : '1–3 days'}'),
          const Divider(height: 18),
          _infoRow(Icons.verified_user_outlined, 'Buyer protection', 'Pay on delivery available'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 20, color: AppColors.blue),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      );

  Widget _sellerCard(BuildContext context, Product p) {
    final seller = context.read<AuthProvider>().findById(p.sellerId);
    final listings = context.read<ProductProvider>().bySeller(p.sellerId, includeSold: false).length;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => SellerProfileScreen(sellerId: p.sellerId))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            UserAvatar(user: seller, name: p.sellerName, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(p.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (seller?.verified ?? false) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: AppColors.blue, size: 17),
                      ],
                    ],
                  ),
                  Text('$listings active listings • ${p.city}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
          ],
        ),
      ),
    );
  }

  Widget _reviews(BuildContext context, Product p, AppUser? me) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Reviews (${p.reviews.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (me?.id != p.sellerId)
              TextButton.icon(
                onPressed: () => _writeReview(p),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('Write review'),
              ),
          ],
        ),
        if (p.reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No reviews yet. Be the first!', style: TextStyle(color: AppColors.grey)),
          ),
        ...p.reviews.take(5).map((r) => Padding(
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
                            Text(Fmt.ago(r.at), style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                          ],
                        ),
                        RatingStars(rating: r.rating.toDouble(), size: 13),
                        const SizedBox(height: 4),
                        Text(r.comment, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Future<void> _writeReview(Product p) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    int rating = 5;
    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Rate this product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                decoration: const InputDecoration(hintText: 'Share your experience…'),
              ),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit review')),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted && ctrl.text.trim().isNotEmpty) {
      final me = context.read<AuthProvider>().user!;
      final parts = me.name.split(' ');
      final short = parts.length > 1 ? '${parts.first} ${parts[1][0]}.' : parts.first;
      await context.read<ProductProvider>().addReview(
            p.id,
            Review(userName: short, rating: rating, comment: ctrl.text.trim()),
          );
      if (mounted) showSnack(context, 'Thanks for your review!');
    }
  }

  Widget _bottomBar(BuildContext context, Product p, bool isMine) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: isMine
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<ProductProvider>().toggleSold(p.id),
                    icon: Icon(p.isSold ? Icons.replay_rounded : Icons.check_circle_outline),
                    label: Text(p.isSold ? 'Relist' : 'Mark sold'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => AddProductScreen(existing: p))),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit listing'),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: p.available ? () => _buyNow(p) : null,
                    child: const Text('Buy now'),
                  ),
                ),
              ],
            ),
    );
  }

  bool _addToCart(Product p, {bool quiet = false}) {
    final ok = context.read<CartProvider>().add(p, qty: _qty);
    if (!ok) {
      showSnack(context, 'Only ${p.stock} available — check your cart', error: true);
    } else if (!quiet) {
      showSnack(context, 'Added $_qty to cart');
    }
    return ok;
  }

  void _buyNow(Product p) {
    final cart = context.read<CartProvider>();
    if (cart.quantityOf(p.id) == 0) {
      if (!_addToCart(p, quiet: true)) return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  Future<void> _chat(Product p) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final me = context.read<AuthProvider>().user!;
    final c = context.read<ChatProvider>().openFor(buyer: me, product: p);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: c.id)));
  }
}

class _QtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.value, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 28,
            child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Re-exported so other screens can use the same stepper.
class QtyStepper extends _QtyStepper {
  const QtyStepper({required super.value, required super.max, required super.onChanged});
}
