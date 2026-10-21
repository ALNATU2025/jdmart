import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/delivery.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/motion.dart';
import 'live_tracking_screen.dart';

/// "Delivery tracking" card on the order page (buyer and seller).
/// Gets the tracking code the first time and shows the rider's progress.
class DeliveryCard extends StatefulWidget {
  final String orderId;
  final bool sellerView;
  const DeliveryCard({super.key, required this.orderId, required this.sellerView});

  @override
  State<DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<DeliveryCard> {
  late Future<String> _open = context.read<DeliveryRepository>().open(widget.orderId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _open,
      builder: (context, snap) {
        if (snap.hasError) {
          return _shell(
            child: Row(
              children: [
                const Expanded(
                  child: Text("Couldn't load delivery tracking.", style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () => setState(() => _open = context.read<DeliveryRepository>().open(widget.orderId)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return _shell(
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
            ),
          );
        }
        return StreamView<Delivery?>(
          id: widget.orderId,
          create: () => context.read<DeliveryRepository>().watch(widget.orderId),
          loading: const SizedBox(height: 120),
          builder: (context, d) => d == null ? const SizedBox.shrink() : FadeSlideIn(child: _content(context, d)),
        );
      },
    );
  }

  Widget _shell({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.navy, Color(0xFF1E3A8A), AppColors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: child,
      );

  Widget _content(BuildContext context, Delivery d) {
    final hint = widget.sellerView
        ? (d.riderId == null
            ? 'Send this code to your dispatch rider. They enter it in Account → Deliveries & tracking.'
            : '${d.riderName} is delivering this order.')
        : (d.riderId == null
            ? 'The seller will send this code to a rider. You can follow them live once they accept.'
            : '${d.riderName} is delivering your order.');
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Floating(
                distance: 3,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(gradient: AppColors.orangeGradient, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delivery_dining_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery tracking',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      child: Text(d.status.label,
                          key: ValueKey(d.status), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(d.code,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: d.code));
                    showSnack(context, 'Code copied');
                  },
                  icon: const Icon(Icons.copy_rounded, color: Colors.white),
                ),
                if (widget.sellerView && d.riderId == null)
                  IconButton(
                    tooltip: 'Send to rider on WhatsApp',
                    onPressed: () => openExternal('https://wa.me/?text=${Uri.encodeComponent(
                        'JDMart delivery job. Open JDMart > Account > Deliveries & tracking and enter code ${d.code}')}'),
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF4ADE80)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 14),
          Pressable(
            haptic: true,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => LiveTrackingScreen(orderId: widget.orderId))),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded, color: AppColors.blue),
                  SizedBox(width: 8),
                  Text('Open live map', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
