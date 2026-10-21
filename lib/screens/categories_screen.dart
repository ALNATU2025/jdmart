import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'category_products_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final w = MediaQuery.of(context).size.width;
    final cols = w > 900 ? 4 : w > 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Categories'), actions: const [CartIconButton()]),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.15,
        ),
        itemCount: SeedData.categories.length,
        itemBuilder: (_, i) {
          final c = SeedData.categories[i];
          final count = products.byCategory(c.id).length;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(categoryId: c.id))),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(c.icon, color: c.color, size: 28),
                  ),
                  const Spacer(),
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  Text('$count ${count == 1 ? 'item' : 'items'}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
