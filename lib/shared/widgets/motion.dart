// Motion toolkit: entrance animations, press feedback, skeleton loaders and
// page transitions. Used across every screen so the app feels consistent.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Shared timing so every animation in the app feels like one family.
class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const curve = Curves.easeOutCubic;

  /// Delay for the [index]th item of a list, capped so long lists don't lag.
  static Duration stagger(int index, {int stepMs = 45, int maxSteps = 8}) =>
      Duration(milliseconds: stepMs * (index < maxSteps ? index : maxSteps));
}

/// Fades and slides its child in once, when it first appears.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Starting offset as a fraction of the child's size (0.08 = 8% lower).
  final Offset offset;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.offset = const Offset(0, 0.08),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Motion.curve);
  late final Animation<Offset> _slide = Tween(begin: widget.offset, end: Offset.zero).animate(_curve);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _curve, child: SlideTransition(position: _slide, child: widget.child));
}

/// Gives any widget a soft "press in" scale and optional haptic tick.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.965,
    this.haptic = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A moving highlight drawn over its child — wrap skeleton boxes in one Shimmer.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          final t = _c.value * 3 - 1; // sweeps from -1 to 2
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(t - 1, -0.3),
              end: Alignment(t, 0.3),
              colors: const [Color(0xFFEDF0F6), Color(0xFFF9FAFD), Color(0xFFEDF0F6)],
              stops: const [0.2, 0.5, 0.8],
            ).createShader(rect),
            child: child,
          );
        },
      );
}

/// Grey placeholder shape used inside a [Shimmer].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height, this.radius = 10});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFEDF0F6), borderRadius: BorderRadius.circular(radius)),
      );
}

/// Skeleton that mirrors a product card while listings load.
class ProductCardSkeleton extends StatelessWidget {
  final double? width;
  const ProductCardSkeleton({super.key, this.width});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 1.05, child: SkeletonBox(radius: 18)),
            Padding(
              padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 12),
                  SizedBox(height: 6),
                  SkeletonBox(height: 12, width: 80),
                  SizedBox(height: 10),
                  SkeletonBox(height: 16, width: 70),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Sliver grid of skeleton cards, shown while the product grid loads.
class ProductGridSkeleton extends StatelessWidget {
  final int count;
  const ProductGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w > 1100 ? 5 : w > 800 ? 4 : w > 560 ? 3 : 2;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.6,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, __) => const Shimmer(child: ProductCardSkeleton()),
          childCount: count,
        ),
      ),
    );
  }
}

/// Skeleton for list screens (orders, chats, listings).
class ListSkeleton extends StatelessWidget {
  final int count;
  const ListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) => Shimmer(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, __) => const Row(
            children: [
              SkeletonBox(width: 56, height: 56, radius: 16),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 13),
                    SizedBox(height: 8),
                    SkeletonBox(height: 11, width: 140),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Pops its child (e.g. a badge count or heart) whenever [value] changes.
class PopOnChange extends StatelessWidget {
  final Object value;
  final Widget child;
  const PopOnChange({super.key, required this.value, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Motion.medium,
        switchInCurve: Curves.elasticOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: KeyedSubtree(key: ValueKey(value), child: child),
      );
}

/// App-wide page transition: a quick fade with a gentle upward slide and a
/// slight recede of the page underneath. Smooth on phones and on the web.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Motion.curve, reverseCurve: Curves.easeInCubic);
    final under = CurvedAnimation(parent: secondaryAnimation, curve: Motion.curve);
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 0.97).animate(under),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(enter),
          child: child,
        ),
      ),
    );
  }
}

/// Gently bobs its child up and down forever (decorations, illustrations).
class Floating extends StatefulWidget {
  final Widget child;
  final double distance;
  final Duration period;

  /// 0–1: where in the cycle this one starts, so neighbours don't move in sync.
  final double phase;
  const Floating({
    super.key,
    required this.child,
    this.distance = 6,
    this.period = const Duration(milliseconds: 2400),
    this.phase = 0,
  });

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period, value: widget.phase)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, (Curves.easeInOut.transform(_c.value) * 2 - 1) * widget.distance),
          child: child,
        ),
      );
}

/// Soft brand-tinted shadow used on cards.
List<BoxShadow> softShadow([double strength = 1]) => [
      BoxShadow(
        color: AppColors.navy.withValues(alpha: 0.06 * strength),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];
