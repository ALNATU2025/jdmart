import 'package:flutter/material.dart';
import 'search_screen.dart';

/// A category page is the search screen pre-filtered to one category.
class CategoryProductsScreen extends StatelessWidget {
  final String categoryId;
  const CategoryProductsScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) => SearchScreen(categoryId: categoryId, autofocus: false);
}
