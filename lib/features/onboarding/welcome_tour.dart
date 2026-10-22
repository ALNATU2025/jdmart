import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../data/services/local_store.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import '../jobs/jobs_home_screen.dart';
import '../shell/main_shell.dart';

/// Marks the signed-in user as brand new, so the welcome tour runs for them.
Future<void> markNewUser(String uid) => LocalStore.setBool('new_user_$uid', true);

/// Friendly pop-ups for new members, one at a time:
///  1. Welcome (right after sign-up)
///  2. "What do you want to sell today?" (a little later)
///  3. "Looking for a job or for talented workers?"
///  4. "Buy from home, office — anywhere" (next time they open the app)
class WelcomeTour extends StatefulWidget {
  final Widget child;
  const WelcomeTour({super.key, required this.child});

  @override
  State<WelcomeTour> createState() => _WelcomeTourState();
}

class _WelcomeTourState extends State<WelcomeTour> {
  static const _lastStep = 4;
  String? _uid;
  Timer? _timer;
  bool _showing = false;
  bool _firstThisSession = true;

  String _stepKey(String uid) => 'tour_step_$uid';
  int _step(String uid) => int.tryParse(LocalStore.getString(_stepKey(uid)) ?? '') ?? 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resume() {
    _timer?.cancel();
    final uid = _uid;
    if (uid == null || !LocalStore.getBool('new_user_$uid')) return;
    final step = _step(uid);
    if (step >= _lastStep) return;
    final delay = switch (step) {
      0 => const Duration(milliseconds: 900),
      1 => const Duration(seconds: 25),
      2 => const Duration(seconds: 45),
      _ => _firstThisSession ? const Duration(seconds: 4) : const Duration(minutes: 30),
    };
    _firstThisSession = false;
    _timer = Timer(delay, () => _show(uid, step));
  }

  Future<void> _show(String uid, int step) async {
    if (!mounted || _showing || uid != _uid) return;
    // Wait while the user is on another page or a dialog is open.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      _timer = Timer(const Duration(seconds: 6), () => _show(uid, step));
      return;
    }
    _showing = true;
    final name = context.read<SessionProvider>().profile?.firstName ?? '';
    final action = await showPromo(context, _promo(step, name));
    _showing = false;
    await LocalStore.setString(_stepKey(uid), '${step + 1}');
    if (!mounted) return;
    switch (action) {
      case 'sell':
        MainShell.goTo(context, -1);
      case 'jobs':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsHomeScreen()));
      case 'talent':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsHomeScreen(initialTab: 1)));
      case 'shop':
        MainShell.goTo(context, 0);
    }
    _resume();
  }

  Promo _promo(int step, String name) => switch (step) {
        0 => Promo(
            image: 'assets/images/popup_welcome.jpg',
            badge: 'WELCOME',
            title: name.isEmpty ? 'Welcome to JDMart! 🎉' : 'Welcome to JDMart, $name! 🎉',
            body: "Sierra Leone's smartest marketplace is now in your pocket. Take a look around — great deals are waiting.",
            actions: const [PromoAction('explore', 'Start exploring', Icons.explore_rounded, primary: true)],
          ),
        1 => const Promo(
            image: 'assets/images/popup_sell.jpg',
            badge: 'SELL FOR FREE',
            title: 'What do you want to sell today?',
            body: 'Snap a photo, set your price in Leones and reach buyers across Sierra Leone in minutes.',
            actions: [
              PromoAction('sell', 'List my first item', Icons.add_a_photo_rounded, primary: true),
              PromoAction('later', 'Maybe later', null),
            ],
          ),
        2 => const Promo(
            image: 'assets/images/popup_jobs.jpg',
            badge: 'JDMART JOBS',
            title: 'Looking for a job or for talented workers?',
            body: 'Find work near you, post a job for free, or share your CV so employers can call you.',
            actions: [
              PromoAction('jobs', 'Find a job', Icons.work_rounded, primary: true),
              PromoAction('talent', 'Find talent', Icons.groups_rounded),
            ],
          ),
        _ => const Promo(
            image: 'assets/images/popup_anywhere.jpg',
            badge: 'SHOP ANYWHERE',
            title: 'Buy from home, office — anywhere',
            body: 'Order in a few taps, pay with Orange Money, Afrimoney or cash on delivery, and follow your rider live to your door.',
            actions: [PromoAction('shop', 'Start shopping', Icons.shopping_bag_rounded, primary: true)],
          ),
      };

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.isLoggedIn ? s.uid : null);
    if (uid != _uid) {
      _uid = uid;
      _timer?.cancel();
      if (uid != null) WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
    }
    return widget.child;
  }
}

class PromoAction {
  final String id;
  final String label;
  final IconData? icon;
  final bool primary;
  const PromoAction(this.id, this.label, this.icon, {this.primary = false});
}

class Promo {
  final String image;
  final String badge;
  final String title;
  final String body;
  final List<PromoAction> actions;
  const Promo({required this.image, required this.badge, required this.title, required this.body, required this.actions});
}

/// Shows an illustrated pop-up. Returns the id of the button tapped (null if closed).
Future<String?> showPromo(BuildContext context, Promo promo) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (_, __, ___) => _PromoCard(promo: promo),
    transitionBuilder: (_, a, __, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6 * a.value, sigmaY: 6 * a.value),
        child: FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.82, end: 1.0).animate(curved), child: child),
        ),
      );
    },
  );
}

class _PromoCard extends StatelessWidget {
  final Promo promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: context.surface,
            borderRadius: BorderRadius.circular(30),
            clipBehavior: Clip.antiAlias,
            elevation: 24,
            shadowColor: Colors.black54,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1200 / 760,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.15, end: 1.0),
                          duration: const Duration(milliseconds: 1400),
                          curve: Curves.easeOutCubic,
                          builder: (_, s, child) => Transform.scale(scale: s, child: child),
                          child: Image.asset(promo.image, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: 16,
                        child: FadeSlideIn(
                          delay: const Duration(milliseconds: 250),
                          offset: const Offset(-0.3, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: softShadow(2),
                            ),
                            child: Text(promo.badge,
                                style: const TextStyle(
                                    color: AppColors.orange, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Pressable(
                          onTap: () => Navigator.pop(context),
                          scale: 0.85,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 180),
                          child: Text(promo.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.25)),
                        ),
                        const SizedBox(height: 8),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 260),
                          child: Text(promo.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.muted, fontSize: 14, height: 1.5)),
                        ),
                        const SizedBox(height: 20),
                        for (var i = 0; i < promo.actions.length; i++)
                          FadeSlideIn(
                            delay: Duration(milliseconds: 340 + i * 80),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ActionButton(action: promo.actions[i]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final PromoAction action;
  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final a = action;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (a.icon != null) ...[
          Icon(a.icon, color: a.primary ? Colors.white : context.brand, size: 20),
          const SizedBox(width: 8),
        ],
        Text(a.label,
            style: TextStyle(
              color: a.primary ? Colors.white : context.brand,
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
            )),
      ],
    );
    return Pressable(
      haptic: true,
      scale: 0.96,
      onTap: () => Navigator.pop(context, a.id),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: a.primary ? AppColors.orangeGradient : null,
          color: a.primary ? null : context.blueTint,
          borderRadius: BorderRadius.circular(27),
          boxShadow: a.primary
              ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: content,
      ),
    );
  }
}
