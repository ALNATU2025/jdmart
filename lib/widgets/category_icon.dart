import 'package:flutter/material.dart';
import '../data/seed_data.dart';

/// Shows a category's image from assets/images/ (e.g. phone.png).
/// If the image file hasn't been added yet, it falls back to the built-in
/// Material icon in the category colour, so the app never shows a broken image.
class CategoryIcon extends StatelessWidget {
  final ProductCategory category;
  final double size;
  final double opacity;

  const CategoryIcon({super.key, required this.category, this.size = 28, this.opacity = 1});

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      category.imagePath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Icon(category.icon, size: size, color: category.color),
    );
    return opacity >= 1 ? img : Opacity(opacity: opacity, child: img);
  }
}
