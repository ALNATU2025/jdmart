import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import '../auth/auth_guard.dart';
import '../catalog/product_detail_screen.dart';
import '../chat/chat_screen.dart';
import '../delivery/live_tracking_screen.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/talent_detail_screen.dart';
import '../orders/order_detail_screen.dart';

/// Icon and colour for each kind of notification.
(IconData, Color) notificationStyle(String type) => switch (type) {
      'order' => (Icons.receipt_long_rounded, AppColors.blue),
      'chat' => (Icons.chat_bubble_rounded, const Color(0xFF0EA5E9)),
      'job' => (Icons.work_rounded, AppColors.orange),
      'talent' => (Icons.badge_rounded, const Color(0xFF7C3AED)),
      'delivery' => (Icons.delivery_dining_rounded, AppColors.orange),
      'product' => (Icons.sell_rounded, AppColors.success),
      'report' => (Icons.flag_rounded, AppColors.danger),
      'user' => (Icons.person_add_alt_1_rounded, const Color(0xFF7C3AED)),
      'welcome' => (Icons.celebration_rounded, AppColors.orange),
      'rider' => (Icons.delivery_dining_rounded, AppColors.orange),
      'admin' => (Icons.admin_panel_settings_rounded, AppColors.navy),
      _ => (Icons.notifications_rounded, AppColors.blue),
    };

/// Opens the screen a notification is about.
Future<void> openNotificationTarget(BuildContext context, AppNotification n) async {
  final d = n.data;
  Widget? page;
  switch (n.type) {
    case 'order':
      final orderId = d['orderId'] ?? '';
      if (orderId.isEmpty) return;
      final uid = context.read<SessionProvider>().uid;
      final order = await context.read<OrderRepository>().watch(orderId).first.catchError((Object _) => null);
      if (!context.mounted || order == null) return;
      page = OrderDetailScreen(orderId: orderId, sellerView: order.sellerId == uid);
    case 'chat':
      final chatId = d['chatId'] ?? '';
      if (chatId.isNotEmpty) page = ChatScreen(conversationId: chatId);
    case 'job':
      final jobId = d['jobId'] ?? '';
      if (jobId.isNotEmpty) page = JobDetailScreen(jobId: jobId);
    case 'delivery':
      final deliveryId = d['orderId'] ?? '';
      if (deliveryId.isNotEmpty) page = LiveTrackingScreen(orderId: deliveryId);
    case 'product' || 'report':
      final productId = d['productId'] ?? '';
      if (productId.isNotEmpty) page = ProductDetailScreen(productId: productId);
    case 'talent':
      final talentId = d['userId'] ?? '';
      if (talentId.isNotEmpty) page = TalentDetailScreen(uid: talentId);
  }
  final target = page;
  if (target != null && context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => target));
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.isLoggedIn ? s.uid : null);
    final repo = context.read<NotificationRepository>();
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Stay in the loop',
          message: 'Sign in to get updates about your orders, messages, jobs and deliveries.',
          actionLabel: 'Sign in',
          onAction: () => ensureLoggedIn(context),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () => repo.markAllRead(uid),
          ),
          PopupMenuButton<String>(
            onSelected: (_) async {
              if (await confirmDialog(context,
                      title: 'Clear all notifications?', message: 'This removes them from this list.', confirm: 'Clear') &&
                  context.mounted) {
                await repo.clearAll(uid);
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Clear all'))],
          ),
        ],
      ),
      body: StreamView<List<AppNotification>>(
        id: uid,
        create: () => repo.watch(uid),
        loading: const ListSkeleton(),
        builder: (context, list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message: 'Orders, messages, job applications and deliveries will show up here.',
            );
          }
          final today = DateTime.now();
          bool isToday(DateTime d) => d.year == today.year && d.month == today.month && d.day == today.day;
          final items = <Widget>[];
          String? section;
          for (var i = 0; i < list.length; i++) {
            final n = list[i];
            final s = isToday(n.createdAt) ? 'Today' : 'Earlier';
            if (s != section) {
              section = s;
              items.add(Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: Text(s.toUpperCase(),
                    style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ));
            }
            items.add(FadeSlideIn(
              key: ValueKey(n.id),
              delay: Motion.stagger(i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Dismissible(
                  key: ValueKey('d-${n.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 22),
                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) => repo.delete(uid, n.id),
                  child: NotificationTile(
                    n: n,
                    onTap: () {
                      if (!n.read) repo.markRead(uid, n.id);
                      openNotificationTarget(context, n);
                    },
                  ),
                ),
              ),
            ));
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: items);
        },
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final AppNotification n;
  final VoidCallback? onTap;
  final bool showUnread;
  const NotificationTile({super.key, required this.n, this.onTap, this.showUnread = true});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = notificationStyle(n.type);
    final unread = showUnread && !n.read;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: Motion.medium,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? context.blueTint : context.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: softShadow(),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.2)!]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n.title,
                            style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600, fontSize: 14.5)),
                      ),
                      Text(Fmt.ago(n.createdAt), style: TextStyle(color: context.muted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(n.body, style: TextStyle(color: context.muted, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
