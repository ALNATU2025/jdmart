import 'package:flutter/material.dart';
import '../../core/constants/catalog.dart';
import '../../shared/widgets/category_icon.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          childAspectRatio: 1.25,
        ),
        itemCount: Catalog.categories.length,
        itemBuilder: (_, i) {
          final c = Catalog.categories[i];
          return FadeSlideIn(
            delay: Motion.stagger(i, stepMs: 40, maxSteps: 12),
            child: Pressable(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => SearchScreen(categoryId: c.id, autofocus: false))),
            child: Container(
              padding: const EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, c.color.withValues(alpha: 0.07)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: softShadow(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: CategoryIcon(category: c, size: 40),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(c.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: c.color),
                    ],
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
