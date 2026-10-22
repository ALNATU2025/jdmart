import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/rider.dart';
import '../../data/repositories/rider_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../delivery/rider_widgets.dart';

/// Admins: review rider applications and manage verified riders.
class AdminRidersScreen extends StatefulWidget {
  const AdminRidersScreen({super.key});

  @override
  State<AdminRidersScreen> createState() => _AdminRidersScreenState();
}

class _AdminRidersScreenState extends State<AdminRidersScreen> {
  RiderStatus? _filter = RiderStatus.pending;

  static Color statusColor(RiderStatus s) => switch (s) {
        RiderStatus.pending => AppColors.orange,
        RiderStatus.approved => AppColors.success,
        RiderStatus.rejected => AppColors.grey,
        RiderStatus.suspended => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final filters = <(String, RiderStatus?)>[
      ('To review', RiderStatus.pending),
      ('Approved', RiderStatus.approved),
      ('Suspended', RiderStatus.suspended),
      ('Rejected', RiderStatus.rejected),
      ('All', null),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Riders')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                for (final (label, status) in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == status,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _filter == status ? Colors.white : context.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _filter = status),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamView<List<Rider>>(
              create: () => context.read<RiderRepository>().all(),
              loading: const ListSkeleton(),
              builder: (context, all) {
                final list = _filter == null ? all : all.where((r) => r.status == _filter).toList();
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.delivery_dining_rounded,
                    title: _filter == RiderStatus.pending ? 'No applications to review' : 'No riders here',
                    message: 'Rider applications from Account → Deliveries & tracking appear here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    return FadeSlideIn(
                      key: ValueKey(r.id),
                      delay: Motion.stagger(i),
                      child: Pressable(
                        onTap: () => _review(context, r),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: context.surface, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
                          child: Row(
                            children: [
                              RiderAvatar(name: r.name, photoUrl: r.photoUrl, radius: 26, verified: r.isApproved),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text('${r.vehicleLabel} • ${r.city}',
                                        style: TextStyle(color: context.muted, fontSize: 12.5)),
                                    Text('Applied ${Fmt.ago(r.createdAt)} • ${r.deliveries} deliveries',
                                        style: TextStyle(color: context.muted, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor(r.status).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(r.status.name,
                                    style: TextStyle(
                                        color: statusColor(r.status), fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _review(BuildContext context, Rider r) {
    final repo = context.read<RiderRepository>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: FutureBuilder<RiderKyc?>(
          future: repo.kyc(r.id),
          builder: (ctx, snap) {
            final k = snap.data;
            Future<void> set(RiderStatus s, String done) async {
              var note = '';
              if (s == RiderStatus.rejected || s == RiderStatus.suspended) {
                final c = TextEditingController();
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (d) => AlertDialog(
                    title: Text(s == RiderStatus.rejected ? 'Reason for rejecting' : 'Reason for suspending'),
                    content: TextField(
                      controller: c,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'e.g. Photo is not clear'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Confirm')),
                    ],
                  ),
                );
                note = c.text;
                c.dispose();
                if (ok != true) return;
              }
              if (!ctx.mounted) return;
              Navigator.pop(sheet);
              final err = await runWithProgress(context, () => repo.setStatus(r.id, s, note: note));
              if (context.mounted) showSnack(context, err ?? done, error: err != null);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      RiderAvatar(name: r.name, photoUrl: r.photoUrl, radius: 36, verified: r.isApproved),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text('${r.vehicleLabel} • ${r.city}', style: TextStyle(color: ctx.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (r.photoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                          aspectRatio: 4 / 3, child: NetImage(url: r.photoUrl!, error: () => const SizedBox.shrink())),
                    ),
                  const SizedBox(height: 14),
                  if (!snap.hasData && !snap.hasError) const LinearProgressIndicator(minHeight: 2),
                  if (k != null) ...[
                    Text('${k.idType}: ${k.idNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (k.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Phone: ${Fmt.display(k.phone)}'),
                      const SizedBox(height: 8),
                      ContactActions(phone: k.phone, whatsAppText: 'Hello ${r.name}, this is JDMart about your rider application.'),
                    ],
                    if (k.idPhotoUrl != null) ...[
                      const SizedBox(height: 12),
                      const Text('ID photo', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: NetImage(url: k.idPhotoUrl!, fit: BoxFit.contain, error: () => const SizedBox.shrink())),
                      ),
                    ],
                  ] else if (snap.hasData)
                    Text('No ID details were submitted.', style: TextStyle(color: ctx.muted)),
                  const SizedBox(height: 18),
                  if (r.status != RiderStatus.approved)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () => set(RiderStatus.approved, '${r.name} is now a verified rider ✓'),
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Approve rider'),
                    ),
                  if (r.status == RiderStatus.pending) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => set(RiderStatus.rejected, 'Application rejected'),
                      child: const Text('Reject'),
                    ),
                  ],
                  if (r.status == RiderStatus.approved)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                      onPressed: () => set(RiderStatus.suspended, 'Rider suspended'),
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Suspend rider'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
