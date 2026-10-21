import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/order.dart';
import '../../features/cart/cart_screen.dart';
import '../../state/cart_provider.dart';
import 'motion.dart';

class JDLogo extends StatelessWidget {
  final double height;
  final bool markOnly;
  const JDLogo({super.key, this.height = 40, this.markOnly = false});

  @override
  Widget build(BuildContext context) => Image.asset(
        markOnly ? 'assets/images/logo_mark_transparent.png' : 'assets/images/logo.png',
        height: height,
        fit: BoxFit.contain,
      );
}

/// Wordmark built in code so it stays crisp in app bars.
class JDWordmark extends StatelessWidget {
  final double size;
  const JDWordmark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/logo_mark_transparent.png', height: size * 1.6),
        const SizedBox(width: 4),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'JD', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: size)),
            TextSpan(text: 'Mart', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800, fontSize: size)),
          ]),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.action, this.onAction, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: FadeSlideIn(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Floating(
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.blueLight, Color(0xFFF4F7FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: softShadow(),
                ),
                child: Icon(icon, size: 52, color: AppColors.blue),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              SizedBox(width: 220, child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!))),
            ],
          ],
          ),
        ),
      ),
    );
  }
}

/// Gentle up-and-down bob for empty-state illustrations.
class _Floating extends StatefulWidget {
  final Widget child;
  const _Floating({required this.child});

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  late final Animation<Offset> _y = Tween(begin: const Offset(0, -0.04), end: const Offset(0, 0.04))
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(position: _y, child: widget.child);
}

class LoadingView extends StatelessWidget {
  final double padding;
  const LoadingView({super.key, this.padding = 40});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(padding),
          // Appears after a short delay so quick loads don't flash a spinner.
          child: const FadeSlideIn(
            delay: Duration(milliseconds: 180),
            offset: Offset.zero,
            child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2.6),
          ),
        ),
      );
}

class ErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    debugPrint('ErrorView: $error');
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: "Couldn't load this",
      message: 'Check your internet connection and try again.',
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

/// Listens to a Firestore stream with consistent loading / error handling.
/// The stream is created once (and again only when [id] changes), so parent
/// rebuilds don't open new listeners.
class StreamView<T> extends StatefulWidget {
  final Object? id;
  final Stream<T> Function() create;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;
  const StreamView({super.key, this.id, required this.create, required this.builder, this.loading});

  @override
  State<StreamView<T>> createState() => _StreamViewState<T>();
}

class _StreamViewState<T> extends State<StreamView<T>> {
  late Stream<T> _stream = widget.create();

  @override
  void didUpdateWidget(covariant StreamView<T> old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _stream = widget.create();
  }

  void _retry() => setState(() => _stream = widget.create());

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        stream: _stream,
        builder: (ctx, snap) {
          if (snap.hasError) return ErrorView(error: snap.error, onRetry: _retry);
          // Only "waiting" means loading: a stream may legitimately emit null (e.g. a deleted document).
          if (snap.connectionState == ConnectionState.waiting || (!snap.hasData && null is! T)) {
            return widget.loading ?? const LoadingView();
          }
          return widget.builder(ctx, snap.data as T);
        },
      );
}

class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  const UserAvatar({super.key, required this.name, this.imageUrl, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
    final url = imageUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.blueLight,
      backgroundImage: (url != null && url.isNotEmpty) ? CachedNetworkImageProvider(url) : null,
      child: (url == null || url.isEmpty)
          ? Text(initials.isEmpty ? '?' : initials,
              style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700, fontSize: radius * 0.7))
          : null,
    );
  }
}

class CartIconButton extends StatelessWidget {
  final Color color;
  const CartIconButton({super.key, this.color = AppColors.navy});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().count;
    return IconButton(
      tooltip: 'Cart',
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.orange,
        label: PopOnChange(value: count, child: Text('$count')),
        child: Icon(Icons.shopping_cart_outlined, color: color),
      ),
    );
  }
}

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  const RatingStars({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final v = rating - i;
        return Icon(
          v >= 1 ? Icons.star_rounded : (v >= 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
          size: size,
          color: const Color(0xFFFFB400),
        );
      }),
    );
  }
}

class StatusChip extends StatelessWidget {
  final OrderStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.pending => const Color(0xFFD97706),
      OrderStatus.confirmed => AppColors.blue,
      OrderStatus.shipped => const Color(0xFF7C3AED),
      OrderStatus.delivered => AppColors.success,
      OrderStatus.cancelled => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.navy));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirm = 'Yes', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm, style: TextStyle(color: danger ? AppColors.danger : AppColors.blue)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Runs [task] with a blocking progress dialog. Returns the error message, or null.
Future<String?> runWithProgress(BuildContext context, Future<void> Function() task, {String label = 'Please wait…'}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.orange)),
            const SizedBox(width: 16),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
  String? error;
  try {
    await task();
  } catch (e) {
    error = e.toString().replaceFirst('Exception: ', '');
  }
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  return error;
}
