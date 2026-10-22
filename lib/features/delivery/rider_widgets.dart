import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../data/models/rider.dart';
import '../../data/repositories/rider_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';

/// Round rider photo with a small verified tick.
class RiderAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool verified;
  const RiderAvatar({super.key, required this.name, this.photoUrl, this.radius = 24, this.verified = true});

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.orange.withValues(alpha: 0.15),
          backgroundImage: (url != null && url.isNotEmpty) ? netImageProvider(url) : null,
          child: (url == null || url.isEmpty)
              ? Icon(Icons.delivery_dining_rounded, color: AppColors.orange, size: radius)
              : null,
        ),
        if (verified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: context.surface, shape: BoxShape.circle),
              child: Icon(Icons.verified_rounded, color: AppColors.blue, size: radius * 0.6),
            ),
          ),
      ],
    );
  }
}

/// Seller: choose a verified rider for an order. Riders in [city] are listed first.
Future<void> showRiderPicker(BuildContext context, {required String orderId, required String city}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, scroll) => StreamView<List<Rider>>(
        create: () => context.read<RiderRepository>().approved(),
        loading: const ListSkeleton(),
        builder: (ctx, riders) {
          final list = [...riders]..sort((a, b) {
              final ca = a.city == city ? 0 : 1;
              final cb = b.city == city ? 0 : 1;
              return ca != cb ? ca.compareTo(cb) : 0;
            });
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const Text('Choose a verified rider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('All riders are checked by JDMart. Riders near $city are shown first.',
                  style: TextStyle(color: ctx.muted, fontSize: 12.5)),
              const SizedBox(height: 14),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No verified riders yet. You can still share the delivery code with a rider.',
                      textAlign: TextAlign.center, style: TextStyle(color: ctx.muted)),
                ),
              for (var i = 0; i < list.length; i++)
                FadeSlideIn(
                  key: ValueKey(list[i].id),
                  delay: Motion.stagger(i),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RiderOption(
                      rider: list[i],
                      nearby: list[i].city == city,
                      onChoose: () async {
                        final r = list[i];
                        final ok = await confirmDialog(ctx,
                            title: 'Choose ${r.name}?',
                            message: '${r.vehicleLabel} • ${r.city}\nThey will be notified to pick up this order.',
                            confirm: 'Choose');
                        if (!ok || !ctx.mounted) return;
                        final err = await runWithProgress(ctx, () => ctx.read<RiderRepository>().assign(orderId, r.id));
                        if (!ctx.mounted) return;
                        if (err != null) {
                          showSnack(ctx, err, error: true);
                        } else {
                          Navigator.pop(sheet);
                          showSnack(context, '${r.name} is now delivering this order 🛵');
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _RiderOption extends StatelessWidget {
  final Rider rider;
  final bool nearby;
  final VoidCallback onChoose;
  const _RiderOption({required this.rider, required this.nearby, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final r = rider;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.line),
      ),
      child: Row(
        children: [
          RiderAvatar(name: r.name, photoUrl: r.photoUrl, radius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(r.vehicleLabel, style: TextStyle(color: context.muted, fontSize: 12.5)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.circle, size: 9, color: r.available ? AppColors.success : context.muted),
                  const SizedBox(width: 4),
                  Text(r.available ? 'Available' : 'Busy', style: TextStyle(fontSize: 11.5, color: context.muted)),
                  const SizedBox(width: 10),
                  Text('${r.deliveries} deliveries • ${r.city}${nearby ? ' (near you)' : ''}',
                      style: TextStyle(fontSize: 11.5, color: context.muted)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: onChoose,
            haptic: true,
            scale: 0.92,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(gradient: AppColors.orangeGradient, borderRadius: BorderRadius.circular(20)),
              child: const Text('Choose', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
