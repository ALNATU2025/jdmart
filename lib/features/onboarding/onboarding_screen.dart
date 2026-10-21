import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/local_store.dart';
import '../../shared/widgets/motion.dart';
import '../auth/auth_flow_screen.dart';
import '../shell/main_shell.dart';

/// Deep blue of the onboarding panel (matches assets/images/onboarding2.jpg).
const _panelBlue = Color(0xFF022A95);
const _panelBlueDark = Color(0xFF04268A);
const _accentBlue = Color(0xFF5B8CFF);

class _OnboardPage {
  /// Title split into pieces so key words can be coloured.
  final List<(String, Color?)> title;
  final String body;
  final Widget Function() art;

  /// True when the artwork already contains the blue/orange wave.
  final bool artHasWave;
  const _OnboardPage({required this.title, required this.body, required this.art, this.artHasWave = false});
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  late final List<_OnboardPage> _pages = [
    _OnboardPage(
      title: const [('Welcome to ', null), ('JD', _accentBlue), ('Mart', AppColors.orange)],
      body: 'Buy smart and sell faster with people in Freetown, Bo, Kenema, Makeni and across Sierra Leone.',
      art: () => const _LogoArt(),
    ),
    _OnboardPage(
      title: const [
        ('The Smart Marketplace\nWhere ', null),
        ('Buyers', _accentBlue),
        (' and ', null),
        ('Sellers', AppColors.orange),
        (' Meet', null),
      ],
      body: 'Shop from trusted sellers and reach buyers in every corner of the country.',
      artHasWave: true,
      art: () => Image.asset(
        'assets/images/onboarding2.jpg',
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
      ),
    ),
    _OnboardPage(
      title: const [('Find Work. ', null), ('Hire Talent.', AppColors.orange)],
      body: 'Post jobs, apply in minutes, or share your CV so employers can contact you.',
      art: () => const _IconArt(
        icon: Icons.work_rounded,
        color: AppColors.blue,
        chips: [
          (Icons.campaign_rounded, 'Post a job', AppColors.blue),
          (Icons.send_rounded, 'Apply fast', AppColors.orange),
          (Icons.description_rounded, 'Upload CV', AppColors.success),
        ],
      ),
    ),
    _OnboardPage(
      title: const [('Pay ', null), ('Your Way', AppColors.orange)],
      body: 'Orange Money, Afrimoney, card or cash on delivery — simple, safe and local.',
      art: () => const _IconArt(
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.orange,
        chips: [
          (Icons.phone_android_rounded, 'Orange Money', AppColors.orange),
          (Icons.payments_rounded, 'Afrimoney', AppColors.blue),
          (Icons.local_shipping_rounded, 'Cash on delivery', AppColors.success),
        ],
      ),
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/onboarding2.jpg'), context);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish({bool login = false}) async {
    await LocalStore.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
    if (login) {
      Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AuthFlowScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    final p = _pages[_page];
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        // Phone-shaped column on wide screens (web, tablets).
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Soft circle in the corner, as in the artwork.
                    Positioned(
                      left: -140,
                      top: -160,
                      child: Container(
                        width: 360,
                        height: 360,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1F4FD)),
                      ),
                    ),
                    PageView.builder(
                      controller: _pc,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _pageView(i),
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, top: 4),
                          child: AnimatedOpacity(
                            duration: Motion.medium,
                            opacity: last ? 0 : 1,
                            child: TextButton(onPressed: last ? null : _finish, child: const Text('Skip')),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Static blue panel: text, button and dots.
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24, 6, 24, 16 + bottomInset),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_panelBlue, _panelBlueDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 112,
                      child: AnimatedSwitcher(
                        duration: Motion.slow,
                        switchInCurve: Motion.curve,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                            child: c,
                          ),
                        ),
                        child: Column(
                          key: ValueKey(_page),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text.rich(
                              TextSpan(children: [
                                for (final (text, color) in p.title)
                                  TextSpan(text: text, style: TextStyle(color: color ?? Colors.white)),
                              ]),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p.body,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13.5, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _GetStartedButton(
                      label: last ? 'Get Started' : 'Next',
                      onTap: () => last
                          ? _finish(login: true)
                          : _pc.nextPage(duration: const Duration(milliseconds: 550), curve: Curves.easeInOutCubic),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => GestureDetector(
                          onTap: () => _pc.animateToPage(i, duration: Motion.slow, curve: Curves.easeInOutCubic),
                          child: AnimatedContainer(
                            duration: Motion.medium,
                            curve: Motion.curve,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: _page == i ? 26 : 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: _page == i ? AppColors.orange : const Color(0xFF2F55D4),
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: Motion.medium,
                      curve: Motion.curve,
                      child: last
                          ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: TextButton(
                                onPressed: _finish,
                                child: const Text('Browse as guest', style: TextStyle(color: Colors.white70)),
                              ),
                            )
                          : const SizedBox(width: double.infinity, height: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One page of artwork. Content drifts and fades while it is being swiped.
  Widget _pageView(int i) {
    final page = _pages[i];
    return AnimatedBuilder(
      animation: _pc,
      builder: (_, child) {
        final pos = _pc.hasClients && _pc.position.haveDimensions ? (_pc.page ?? 0) : 0.0;
        final d = (pos - i).clamp(-1.0, 1.0).toDouble();
        return Opacity(
          opacity: 1 - d.abs() * 0.5,
          child: Transform.scale(scale: 1 - d.abs() * 0.08, child: child),
        );
      },
      child: page.artHasWave
          ? SizedBox.expand(child: page.art())
          : Column(
              children: [
                Expanded(child: SafeArea(bottom: false, child: page.art())),
                LayoutBuilder(
                  builder: (_, box) => SizedBox(
                    width: box.maxWidth,
                    height: box.maxWidth * 0.26,
                    child: const CustomPaint(painter: _WavePainter()),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Orange pill with a white circular arrow, as in the artwork.
class _GetStartedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GetStartedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.96,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF7A1A), AppColors.orange]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedSwitcher(
              duration: Motion.medium,
              child: Text(label,
                  key: ValueKey(label),
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600)),
            ),
            Positioned(
              right: 7,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const _NudgingArrow(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arrow that nudges forward to invite a tap.
class _NudgingArrow extends StatefulWidget {
  const _NudgingArrow();

  @override
  State<_NudgingArrow> createState() => _NudgingArrowState();
}

class _NudgingArrowState extends State<_NudgingArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          // Quick nudge in the first third of each cycle, then rest.
          final t = _c.value < 0.35 ? Curves.easeInOut.transform(_c.value / 0.35) : 0.0;
          final dx = (t < 0.5 ? t : 1 - t) * 8;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: const Icon(Icons.arrow_forward_rounded, color: AppColors.orange, size: 26),
      );
}

/// Blue and orange wave that flows into the blue panel (drawn in code so it
/// matches the artwork on every page).
class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final orange = Path()
      ..moveTo(w * 0.40, h)
      ..quadraticBezierTo(w * 0.80, h * 0.92, w, h * 0.10)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      orange,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFFF8A3D), AppColors.orange])
            .createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final blue = Path()
      ..moveTo(0, h * 0.05)
      ..quadraticBezierTo(w * 0.30, h * 1.02, w * 0.55, h * 0.98)
      ..quadraticBezierTo(w * 0.85, h * 0.92, w, h * 0.42)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      blue,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1D4FE0), _panelBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Floating round badge holding a small icon (decoration).
class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  static const double size = 64;
  const _Badge(this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.10)),
        child: Icon(icon, color: color, size: size * 0.42),
      );
}

/// Page 1: the logo surrounded by floating shopping icons.
class _LogoArt extends StatelessWidget {
  const _LogoArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      return Stack(
        children: [
          Positioned(
            left: w * 0.42,
            top: h * 0.08,
            child: const Floating(phase: 0.2, child: _Badge(Icons.shopping_bag_outlined, AppColors.orange)),
          ),
          Positioned(
            right: w * 0.10,
            top: h * 0.30,
            child: const Floating(phase: 0.6, child: _Badge(Icons.shopping_cart_outlined, AppColors.blue)),
          ),
          Positioned(
            left: w * 0.06,
            top: h * 0.50,
            child: const Floating(phase: 0.4, child: _Badge(Icons.sell_outlined, AppColors.blue)),
          ),
          Positioned(
            right: w * 0.12,
            top: h * 0.08,
            child: const _DotGrid(),
          ),
          Positioned(left: w * 0.16, top: h * 0.26, child: const _Dot(AppColors.orange, 10)),
          Positioned(right: w * 0.12, top: h * 0.60, child: const _Dot(AppColors.blue, 12)),
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: h * 0.08),
              child: FadeSlideIn(
                duration: const Duration(milliseconds: 800),
                offset: const Offset(0, 0.15),
                child: Image.asset('assets/images/logo.png', width: (w * 0.72).clamp(180.0, 340.0).toDouble()),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot(this.color, this.size);

  @override
  Widget build(BuildContext context) => Floating(
        distance: 4,
        child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      );
}

class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                4,
                (_) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(color: Color(0xFF5B8CFF), shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Pages 3 and 4: a big glowing icon with floating feature chips.
class _IconArt extends StatelessWidget {
  final IconData icon;
  final Color color;
  final List<(IconData, String, Color)> chips;
  const _IconArt({required this.icon, required this.color, required this.chips});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final circle = (w * 0.48).clamp(140.0, 230.0).toDouble();
      final spots = [
        Offset(w * 0.05, h * 0.22),
        Offset(w * 0.50, h * 0.12),
        Offset(w * 0.30, h * 0.74),
      ];
      return Stack(
        children: [
          Positioned(right: w * 0.12, top: h * 0.10, child: const _DotGrid()),
          Center(
            child: FadeSlideIn(
              duration: const Duration(milliseconds: 800),
              child: Floating(
                distance: 8,
                child: Container(
                  width: circle,
                  height: circle,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.05)]),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 50, spreadRadius: 6)],
                  ),
                  child: Icon(icon, size: circle * 0.46, color: color),
                ),
              ),
            ),
          ),
          for (var i = 0; i < chips.length && i < spots.length; i++)
            Positioned(
              left: spots[i].dx,
              top: spots[i].dy,
              child: FadeSlideIn(
                delay: Duration(milliseconds: 250 + i * 140),
                child: Floating(
                  phase: i * 0.3,
                  child: _Chip(chips[i].$1, chips[i].$2, chips[i].$3),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
          ],
        ),
      );
}
