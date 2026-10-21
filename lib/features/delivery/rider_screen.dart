import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/delivery.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import 'live_tracking_screen.dart';

/// Riders accept jobs with a code; anyone on a delivery can track it.
class RiderScreen extends StatefulWidget {
  const RiderScreen({super.key});

  @override
  State<RiderScreen> createState() => _RiderScreenState();
}

class _RiderScreenState extends State<RiderScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      showSnack(context, 'Enter the delivery code', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final orderId = await context.read<DeliveryRepository>().join(code);
      if (!mounted) return;
      _code.clear();
      Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTrackingScreen(orderId: orderId)));
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.uid) ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Deliveries & tracking')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF022A95), AppColors.blue, Color(0xFF3B5BDB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Floating(child: Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 40)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Track or deliver with a code',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dispatch riders: enter the code from the seller to accept the delivery. '
                    'Buyers and sellers: your code is on the order page.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2),
                    decoration: const InputDecoration(
                      hintText: 'JD-XXXX-XXXX',
                      prefixIcon: Icon(Icons.qr_code_2_rounded),
                    ),
                    onSubmitted: (_) => _join(),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                    onPressed: _busy ? null : _join,
                    icon: _busy
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : const Icon(Icons.near_me_rounded),
                    label: const Text('Track / accept delivery'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text('My deliveries', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          StreamView<List<Delivery>>(
            id: uid,
            create: () => context.read<DeliveryRepository>().mine(uid),
            loading: const LoadingView(padding: 24),
            builder: (context, list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Deliveries you are part of will appear here.',
                      textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++)
                    FadeSlideIn(
                      key: ValueKey(list[i].orderId),
                      delay: Motion.stagger(i),
                      child: _tile(context, list[i], uid),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Delivery d, String uid) {
    final role = d.roleOf(uid);
    final color = switch (role) {
      'rider' => AppColors.orange,
      'seller' => AppColors.blue,
      _ => AppColors.success,
    };
    final done = d.status == DeliveryStatus.delivered;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTrackingScreen(orderId: d.orderId))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(done ? Icons.verified_rounded : Icons.delivery_dining_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${d.shortOrderId} • ${d.code}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${role == 'rider' ? 'You are the rider' : role == 'seller' ? 'You are the seller' : 'You are the buyer'}'
                      ' • ${d.status.label}',
                      style: TextStyle(color: context.muted, fontSize: 12),
                    ),
                    Text('Updated ${Fmt.ago(d.updatedAt)}', style: TextStyle(color: context.muted, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.muted),
            ],
          ),
        ),
      ),
    );
  }
}
