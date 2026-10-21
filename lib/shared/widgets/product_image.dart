import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/catalog.dart';
import 'category_icon.dart';

/// A product photo from Firebase Storage, cached on the device to save mobile
/// data. Listings without photos show the category artwork instead.
class ProductImage extends StatelessWidget {
  final String? url;
  final String categoryId;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.url,
    required this.categoryId,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final u = url;
    final Widget child = (u == null || u.isEmpty)
        ? _art()
        : CachedNetworkImage(
            imageUrl: u,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, __) => Container(color: const Color(0xFFF1F3F7)),
            errorWidget: (_, __, ___) => _art(),
          );
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: child),
    );
  }

  Widget _art() {
    final c = Catalog.category(categoryId);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.color.withValues(alpha: 0.14), c.color.withValues(alpha: 0.32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -iconSize * 0.4,
            bottom: -iconSize * 0.4,
            child: CategoryIcon(category: c, size: iconSize * 2.2, opacity: 0.12),
          ),
          Center(child: CategoryIcon(category: c, size: iconSize * 1.3)),
        ],
      ),
    );
  }
}
