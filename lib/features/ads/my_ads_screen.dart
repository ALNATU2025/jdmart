import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ad_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';
import 'promote_product_screen.dart';

Color adStatusColor(SponsoredAd a) {
  if (a.isLive) return AppColors.success;
  if (a.status == 'pending') return AppColors.orange;
  if (a.status == 'rejected') return AppColors.danger;
  return AppColors.grey;
}

/// The seller's ads: waiting, live (with time left) and past.
class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({super.key});

  Future<void> _pickListing(BuildContext context, String uid) async {
    final products = await context.read<ProductRepository>().mine(uid).first.catchError((Object _) => <Product>[]);
    if (!context.mounted) return;
    final active = products.where((p) => p.status == ProductStatus.active).toList();
    if (active.isEmpty) {
      showSnack(context, 'List an item first, then you can advertise it.', error: true);
      return;
    }
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text('Which item do you want to advertise?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final p in active)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: p.cover == null
                        ? Container(color: ctx.blueTint)
                        : NetImage(url: p.cover!, error: () => Container(color: ctx.blueTint)),
                  ),
                ),
                title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(Fmt.price(p.price)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (picked != null && context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PromoteProductScreen(product: picked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.uid);
    if (uid == null) return const Scaffold(body: SizedBox.shrink());
    final repo = context.read<AdRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('My ads')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-ad',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _pickListing(context, uid),
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('Advertise an item'),
      ),
      body: StreamView<List<SponsoredAd>>(
        id: uid,
        create: () => repo.mine(uid),
        loading: const ListSkeleton(),
        builder: (context, ads) {
          if (ads.isEmpty) {
            return EmptyState(
              icon: Icons.campaign_rounded,
              title: 'Reach every JDMart user',
              message: 'Advertise a listing and it shows first in the pop-up for everyone, '
                  'plus a phone notification every few hours while your ad runs.',
              actionLabel: 'Advertise an item',
              onAction: () => _pickListing(context, uid),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: ads.length,
            itemBuilder: (_, i) => FadeSlideIn(
              delay: Motion.stagger(i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AdTile(
                  ad: ads[i],
                  trailing: ads[i].status == 'pending'
                      ? TextButton(
                          onPressed: () async {
                            if (await confirmDialog(context,
                                    title: 'Cancel this ad request?',
                                    message: 'If you already paid, contact support for a refund.',
                                    confirm: 'Cancel request') &&
                                context.mounted) {
                              await repo.cancel(ads[i].id);
                            }
                          },
                          child: const Text('Cancel'),
                        )
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ad summary card (used by sellers and admins).
class AdTile extends StatelessWidget {
  final SponsoredAd ad;
  final Widget? trailing;
  final Widget? extra;
  const AdTile({super.key, required this.ad, this.trailing, this.extra});

  String _timeLeft(DateTime end) {
    final d = end.difference(DateTime.now());
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h left';
    if (d.inHours >= 1) return '${d.inHours}h left';
    return '${d.inMinutes.clamp(1, 59)} min left';
  }

  @override
  Widget build(BuildContext context) {
    final a = ad;
    final color = adStatusColor(a);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: a.imageUrl == null
                      ? Container(color: context.blueTint)
                      : NetImage(url: a.imageUrl!, error: () => Container(color: context.blueTint)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('${a.days == 1 ? '1 day' : '${a.days} days'} • ${Fmt.price(a.amount)}',
                        style: TextStyle(color: context.muted, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(a.statusLabel,
                              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                        if (a.isLive && a.endsAt != null) ...[
                          const SizedBox(width: 8),
                          Text(_timeLeft(a.endsAt!), style: TextStyle(color: context.muted, fontSize: 11.5)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (a.status == 'rejected' && a.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(a.note, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ],
          if (extra != null) ...[const SizedBox(height: 10), extra!],
        ],
      ),
    );
  }
}
