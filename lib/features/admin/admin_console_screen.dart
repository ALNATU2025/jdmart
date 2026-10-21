import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/admin_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import 'admin_screens.dart';
import '../../core/theme/palette.dart';

/// Admin console: numbers at a glance and tools to manage JDMart.
/// Only visible to accounts with the admin claim (see functions/src/admin.ts).
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  late Future<AdminStats> _stats = context.read<AdminRepository>().stats();

  void _refresh() => setState(() => _stats = context.read<AdminRepository>().stats());

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (!session.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin console')),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Admins only',
          message: 'If you were just made an admin, sign out and sign back in.',
        ),
      );
    }

    final tools = <_Tool>[
      _Tool(Icons.inventory_2_rounded, 'Listings', 'Feature, hide or remove', AppColors.blue, const AdminListingsScreen()),
      _Tool(Icons.flag_rounded, 'Reports', 'Reported listings', AppColors.danger, const AdminReportsScreen()),
      _Tool(Icons.people_alt_rounded, 'Users', 'Verify or suspend', const Color(0xFF7C3AED), const AdminUsersScreen()),
      _Tool(Icons.receipt_long_rounded, 'Orders', 'All orders', AppColors.success, const AdminOrdersScreen()),
      _Tool(Icons.work_rounded, 'Jobs & CVs', 'Moderate job posts', AppColors.orange, const AdminJobsScreen()),
      _Tool(Icons.view_carousel_rounded, 'Banners', 'Home page promos', const Color(0xFF0EA5E9), const AdminBannersScreen()),
      if (session.isSuperAdmin)
        _Tool(Icons.admin_panel_settings_rounded, 'Admin team', 'Add or remove admins', AppColors.navy,
            const AdminTeamScreen()),
    ];

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: () async {
          _refresh();
          await _stats.catchError((Object _) => const AdminStats(0, 0, 0, 0, 0, 0));
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 170,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              actions: [
                IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14),
                title: const Text('Admin console',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.navy, Color(0xFF1E3A8A), AppColors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 56, 20, 0),
                  alignment: Alignment.topLeft,
                  child: FadeSlideIn(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.orangeGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(session.isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(session.email,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: FutureBuilder<AdminStats>(
                  future: _stats,
                  builder: (_, snap) {
                    if (snap.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: context.orangeTint, borderRadius: BorderRadius.circular(14)),
                        child: const Text(
                          "Couldn't load the numbers. If you were just made an admin, sign out and back in, "
                          'and make sure the latest rules are deployed.',
                          style: TextStyle(fontSize: 13),
                        ),
                      );
                    }
                    final s = snap.data;
                    final items = [
                      ('Users', s?.users, Icons.people_alt_rounded, const Color(0xFF7C3AED)),
                      ('Listings', s?.listings, Icons.inventory_2_rounded, AppColors.blue),
                      ('Orders', s?.orders, Icons.receipt_long_rounded, AppColors.success),
                      ('Open jobs', s?.openJobs, Icons.work_rounded, AppColors.orange),
                      ('CVs', s?.talent, Icons.badge_rounded, const Color(0xFF0EA5E9)),
                      ('Open reports', s?.openReports, Icons.flag_rounded, AppColors.danger),
                    ];
                    return LayoutBuilder(builder: (_, box) {
                      final cols = box.maxWidth > 700 ? 6 : 3;
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.05,
                        children: [
                          for (var i = 0; i < items.length; i++)
                            FadeSlideIn(
                              delay: Motion.stagger(i),
                              child: _StatTile(
                                label: items[i].$1,
                                value: items[i].$2,
                                icon: items[i].$3,
                                color: items[i].$4,
                              ),
                            ),
                        ],
                      );
                    });
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader(title: 'Manage')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => FadeSlideIn(
                    delay: const Duration(milliseconds: 150) + Motion.stagger(i),
                    child: _ToolCard(tool: tools[i]),
                  ),
                  childCount: tools.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Text(
                  'Super admin: ${AppConfig.superAdminEmail}\n'
                  'Role changes take effect the next time the person signs in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.muted, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget page;
  const _Tool(this.icon, this.title, this.subtitle, this.color, this.page);
}

class _StatTile extends StatelessWidget {
  final String label;
  final int? value;
  final IconData icon;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          if (value == null)
            const Shimmer(child: SkeletonBox(width: 40, height: 20))
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value!.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text('${v.round()}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
            ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.muted, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final _Tool tool;
  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => tool.page)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, tool.color.withValues(alpha: 0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: softShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [tool.color, Color.lerp(tool.color, Colors.black, 0.2)!]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tool.icon, color: Colors.white, size: 22),
            ),
            const Spacer(),
            Text(tool.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(tool.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
