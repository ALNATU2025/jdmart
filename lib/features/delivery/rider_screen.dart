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
import '../../data/models/rider.dart';
import '../../data/repositories/rider_repository.dart';
import 'rider_apply_screen.dart';
import 'rider_widgets.dart';

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
          _RiderStatusCard(uid: uid),
          const SizedBox(height: 14),
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

/// Shows whether I'm a verified rider, and lets me apply or go online/offline.
class _RiderStatusCard extends StatelessWidget {
  final String uid;
  const _RiderStatusCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<RiderRepository>();
    return StreamView<Rider?>(
      id: uid,
      create: () => repo.watch(uid),
      loading: const SizedBox(height: 80),
      builder: (context, r) {
        void openForm() =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => RiderApplyScreen(existing: r)));
        if (r == null) {
          return FadeSlideIn(
            child: Pressable(
              onTap: openForm,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.orangeGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Colors.white, size: 34),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Become a verified rider',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          Text('Deliver JDMart orders and earn. Apply with your photo, ID and plate number.',
                              style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          );
        }
        final (color, label, note) = switch (r.status) {
          RiderStatus.approved => (AppColors.success, 'Verified rider', '${r.deliveries} deliveries completed'),
          RiderStatus.pending => (AppColors.orange, 'Application under review', 'We\'ll notify you when an admin has checked it.'),
          RiderStatus.rejected => (AppColors.danger, 'Not approved', r.reviewNote.isEmpty ? 'Update your details and apply again.' : r.reviewNote),
          RiderStatus.suspended => (AppColors.danger, 'Rider account suspended', r.reviewNote.isEmpty ? 'Contact JDMart support.' : r.reviewNote),
        };
        return FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(20), boxShadow: softShadow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RiderAvatar(name: r.name, photoUrl: r.photoUrl, radius: 26, verified: r.isApproved),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                          Text(r.vehicleLabel, style: TextStyle(color: context.muted, fontSize: 12.5)),
                          Text(note, style: TextStyle(color: context.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (r.status != RiderStatus.suspended)
                      IconButton(tooltip: 'Edit details', onPressed: openForm, icon: const Icon(Icons.edit_outlined)),
                  ],
                ),
                if (r.isApproved)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: r.available,
                    activeThumbColor: AppColors.success,
                    onChanged: (v) => repo.setAvailable(uid, v),
                    title: Text(r.available ? 'Available for jobs' : 'Not taking jobs',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Sellers can choose available riders for their orders'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
