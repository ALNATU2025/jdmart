import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../data/seed_data.dart';
import 'category_icon.dart';

/// Shows a product photo from a URL or local file. When a product has no
/// photo (e.g. demo data), it renders branded category artwork instead, so the
/// app looks good fully offline.
class ProductImage extends StatelessWidget {
  final String? path;
  final String categoryId;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.path,
    required this.categoryId,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    final p = path;
    if (p == null || p.isEmpty) {
      child = _art();
    } else if (kIsWeb || p.startsWith('http') || p.startsWith('blob:')) {
      child = Image.network(p, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _art());
    } else {
      child = Image.file(File(p), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _art());
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: child),
    );
  }

  Widget _art() {
    final c = SeedData.category(categoryId);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.color.withOpacity(0.14), c.color.withOpacity(0.32)],
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
