import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../theme/app_theme.dart';

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
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: const BoxDecoration(color: AppColors.blueLight, shape: BoxShape.circle),
              child: Icon(icon, size: 52, color: AppColors.blue),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey)),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final AppUser? user;
  final String? name;
  final String? imagePath; // overrides user.avatarPath (e.g. unsaved preview)
  final double radius;
  const UserAvatar({super.key, this.user, this.name, this.imagePath, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final path = imagePath ?? user?.avatarPath;
    final displayName = user?.name ?? name ?? '?';
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final initials = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    ImageProvider? img;
    if (path != null && path.isNotEmpty) {
      img = kIsWeb ? NetworkImage(path) : FileImage(File(path)) as ImageProvider;
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.blueLight,
      backgroundImage: img,
      child: img == null
          ? Text(initials,
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
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.orange,
        label: Text('$count'),
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
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.navy,
    ));
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
