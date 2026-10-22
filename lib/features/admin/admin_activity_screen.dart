import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../notifications/notifications_screen.dart';

/// Admins: live feed of everything that happens in JDMart.
class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  static const _filters = <(String, String?)>[
    ('All', null),
    ('Orders', 'order'),
    ('Listings', 'product'),
    ('Members', 'user'),
    ('Jobs', 'job'),
    ('CVs', 'talent'),
    ('Reports', 'report'),
    ('Deliveries', 'delivery'),
    ('Riders', 'rider'),
  ];
  String? _type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live activity')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                for (final (label, type) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _type == type,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _type == type ? Colors.white : null,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _type = type),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamView<List<AppNotification>>(
              create: () => context.read<NotificationRepository>().adminFeed(),
              loading: const ListSkeleton(),
              builder: (context, all) {
                final list = _type == null ? all : all.where((n) => n.type == _type).toList();
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.timeline_rounded,
                    title: 'No activity yet',
                    message: 'New members, listings, orders, jobs and reports appear here in real time.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => FadeSlideIn(
                    key: ValueKey(list[i].id),
                    delay: Motion.stagger(i),
                    child: NotificationTile(
                      n: list[i],
                      showUnread: false,
                      onTap: () => openNotificationTarget(context, list[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
