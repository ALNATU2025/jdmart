import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../data/repositories/notification_repository.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import 'notifications_screen.dart';

/// Bell with an unread badge. It rings (wiggles) when something new arrives.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  StreamSubscription<int>? _sub;
  String? _uid;
  int _count = 0;

  void _listen(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _count = 0;
    if (uid == null) return;
    _sub = context.read<NotificationRepository>().unreadCount(uid).listen((c) {
      if (!mounted) return;
      if (c > _count) _ring.forward(from: 0);
      setState(() => _count = c);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.isLoggedIn ? s.uid : null);
    _listen(uid);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      icon: AnimatedBuilder(
        animation: _ring,
        builder: (_, child) {
          // Damped wiggle.
          final t = _ring.value;
          final angle = math.sin(t * math.pi * 6) * 0.35 * (1 - t);
          return Transform.rotate(angle: angle, alignment: Alignment.topCenter, child: child);
        },
        child: Badge(
          isLabelVisible: _count > 0,
          backgroundColor: AppColors.orange,
          label: PopOnChange(value: _count, child: Text(_count > 9 ? '9+' : '$_count')),
          child: Icon(_count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
              color: context.ink),
        ),
      ),
    );
  }
}
