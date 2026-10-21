import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/admin_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../catalog/product_detail_screen.dart';
import '../catalog/seller_profile_screen.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_widgets.dart';
import '../jobs/talent_detail_screen.dart';
import '../../core/theme/palette.dart';

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

/// Runs an admin action with a progress dialog and reports the result.
Future<void> _act(BuildContext context, Future<void> Function() task, String done) async {
  final err = await runWithProgress(context, task);
  if (!context.mounted) return;
  showSnack(context, err ?? done, error: err != null);
}

/// Search box + filter chips header used by the admin lists.
class _ListHeader extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onSearch;
  final List<String> filters;
  final String filter;
  final ValueChanged<String> onFilter;
  const _ListHeader({
    required this.hint,
    required this.onSearch,
    this.filters = const [],
    this.filter = '',
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(Icons.search_rounded, color: context.muted),
              isDense: true,
            ),
          ),
        ),
        if (filters.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: filter == f,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: filter == f ? Colors.white : AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => onFilter(f),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// White rounded row used in admin lists.
class _AdminTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? badge;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _AdminTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.muted, fontSize: 12)),
                    if (badge != null) ...[const SizedBox(height: 6), badge!],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      );
}

Widget _animatedList<T>(List<T> items, Widget Function(T item) build, {String Function(T item)? keyOf}) {
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
    itemCount: items.length,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, i) => FadeSlideIn(
      key: keyOf == null ? null : ValueKey(keyOf(items[i])),
      delay: Motion.stagger(i),
      child: build(items[i]),
    ),
  );
}

// ---------------------------------------------------------------------------
// Listings
// ---------------------------------------------------------------------------

class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen> {
  String _q = '';
  String _filter = 'All';

  bool _match(Product p) {
    final q = _q.trim().toLowerCase();
    final okFilter = switch (_filter) {
      'Active' => p.status == ProductStatus.active,
      'Hidden' => p.status == ProductStatus.hidden,
      'Sold' => p.status == ProductStatus.sold,
      'Featured' => p.featured,
      _ => true,
    };
    return okFilter && (q.isEmpty || '${p.title} ${p.sellerName} ${p.city}'.toLowerCase().contains(q));
  }

  void _menu(BuildContext context, Product p) {
    final repo = context.read<AdminRepository>();
    final hidden = p.status == ProductStatus.hidden;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${Fmt.price(p.price)} • ${p.sellerName} • ${p.city}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open listing'),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id)));
              },
            ),
            ListTile(
              leading: Icon(p.featured ? Icons.star_outline_rounded : Icons.star_rounded, color: const Color(0xFFFFB400)),
              title: Text(p.featured ? 'Remove from Featured' : 'Feature on home page'),
              onTap: () {
                Navigator.pop(sheet);
                _act(context, () => repo.setFeatured(p.id, !p.featured), p.featured ? 'Unfeatured' : 'Featured ⭐');
              },
            ),
            ListTile(
              leading: Icon(hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: context.brand),
              title: Text(hidden ? 'Unhide (make active)' : 'Hide from buyers'),
              onTap: () {
                Navigator.pop(sheet);
                _act(context, () => repo.setProductStatus(p.id, hidden ? 'active' : 'hidden'),
                    hidden ? 'Listing is visible again' : 'Listing hidden');
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_rounded),
              title: const Text('View seller'),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfileScreen(sellerId: p.sellerId)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
              title: const Text('Delete listing', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(sheet);
                if (await confirmDialog(context,
                        title: 'Delete listing?', message: 'This cannot be undone.', confirm: 'Delete', danger: true) &&
                    context.mounted) {
                  _act(context, () => repo.deleteProduct(p.id), 'Listing deleted');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listings')),
      body: Column(
        children: [
          _ListHeader(
            hint: 'Search title, seller or town',
            onSearch: (v) => setState(() => _q = v),
            filters: const ['All', 'Active', 'Hidden', 'Sold', 'Featured'],
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: StreamView<List<Product>>(
              create: () => context.read<AdminRepository>().products(),
              loading: const ListSkeleton(),
              builder: (context, all) {
                final list = all.where(_match).toList();
                if (list.isEmpty) {
                  return const EmptyState(icon: Icons.inventory_2_outlined, title: 'Nothing here', message: '');
                }
                return _animatedList<Product>(
                  list,
                  keyOf: (p) => p.id,
                  (p) => _AdminTile(
                    onTap: () => _menu(context, p),
                    leading: ProductImage(
                      url: p.cover,
                      categoryId: p.categoryId,
                      width: 56,
                      height: 56,
                      iconSize: 26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: p.title,
                    subtitle: '${Fmt.price(p.price)} • ${p.sellerName} • ${Fmt.ago(p.createdAt)}',
                    badge: Wrap(spacing: 6, children: [
                      JobTag(
                        switch (p.status) {
                          ProductStatus.active => 'Active',
                          ProductStatus.sold => 'Sold',
                          ProductStatus.hidden => 'Hidden',
                        },
                        color: p.status == ProductStatus.hidden ? AppColors.danger : AppColors.success,
                      ),
                      if (p.featured) const JobTag('Featured', color: Color(0xFFD97706), icon: Icons.star_rounded),
                    ]),
                    trailing: Icon(Icons.more_vert_rounded, color: context.muted),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _filter = 'Open';

  Future<void> _open(BuildContext context, Report r) async {
    final repo = context.read<AdminRepository>();
    Product? p;
    final err = await runWithProgress(context, () async => p = await repo.product(r.productId), label: 'Loading listing…');
    if (!context.mounted) return;
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    final product = p;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: AppColors.danger),
              title: Text(r.reason),
              subtitle: Text(product == null
                  ? 'The listing has already been deleted'
                  : '${product.title} • ${product.sellerName}'),
            ),
            const Divider(height: 1),
            if (product != null) ...[
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open listing'),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id)));
                },
              ),
              ListTile(
                leading: Icon(Icons.visibility_off_rounded, color: context.brand),
                title: const Text('Hide listing and close report'),
                onTap: () {
                  Navigator.pop(sheet);
                  _act(context, () async {
                    await repo.setProductStatus(product.id, 'hidden');
                    await repo.closeReport(r.id);
                  }, 'Listing hidden');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                title: const Text('Delete listing and close report', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(sheet);
                  _act(context, () async {
                    await repo.deleteProduct(product.id);
                    await repo.closeReport(r.id);
                  }, 'Listing deleted');
                },
              ),
            ],
            if (r.isOpen)
              ListTile(
                leading: const Icon(Icons.check_rounded, color: AppColors.success),
                title: const Text('Dismiss report (no action needed)'),
                onTap: () {
                  Navigator.pop(sheet);
                  _act(context, () => repo.closeReport(r.id), 'Report closed');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          _ListHeader(
            hint: 'Search reason',
            onSearch: (_) {},
            filters: const ['Open', 'All'],
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: StreamView<List<Report>>(
              create: () => context.read<AdminRepository>().reports(),
              loading: const ListSkeleton(),
              builder: (context, all) {
                final list = all.where((r) => _filter == 'All' || r.isOpen).toList();
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.verified_user_outlined,
                    title: 'All clear',
                    message: 'No reports need your attention.',
                  );
                }
                return _animatedList<Report>(
                  list,
                  keyOf: (r) => r.id,
                  (r) => _AdminTile(
                    onTap: () => _open(context, r),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.flag_rounded, color: AppColors.danger),
                    ),
                    title: r.reason,
                    subtitle: 'Listing ${r.productId.substring(0, r.productId.length < 8 ? r.productId.length : 8)} • ${Fmt.ago(r.createdAt)}',
                    badge: JobTag(r.isOpen ? 'Open' : 'Closed', color: r.isOpen ? AppColors.danger : context.muted),
                    trailing: Icon(Icons.chevron_right_rounded, color: context.muted),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

/// Private contact details and suspension state of a user, for the admin sheet.
Future<(Map<String, dynamic>, bool)> _loadUserDetails(AdminRepository repo, String uid) async {
  final results = await Future.wait<Object>([repo.privateOf(uid), repo.isSuspended(uid)]);
  return (results[0] as Map<String, dynamic>, results[1] as bool);
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _q = '';
  String _filter = 'All';

  void _details(BuildContext context, AppUser u) {
    final repo = context.read<AdminRepository>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: FutureBuilder<(Map<String, dynamic>, bool)>(
          future: _loadUserDetails(repo, u.id),
          builder: (_, snap) {
            final priv = snap.data?.$1 ?? const <String, dynamic>{};
            final suspended = snap.data?.$2 ?? false;
            final phone = (priv['phone'] ?? '') as String;
            final email = (priv['email'] ?? '') as String;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: UserAvatar(name: u.name, imageUrl: u.avatarUrl),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${u.city} • joined ${Fmt.date(u.joinedAt)}'),
                ),
                if (!snap.hasData && !snap.hasError) const LinearProgressIndicator(minHeight: 2),
                if (snap.hasData) ...[
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.email_outlined),
                    title: Text(email.isEmpty ? 'No email saved' : email),
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.phone_outlined),
                    title: Text(phone.isEmpty ? 'No phone saved' : Fmt.display(phone)),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: Icon(u.verified ? Icons.verified_outlined : Icons.verified_rounded, color: context.brand),
                  title: Text(u.verified ? 'Remove verified badge' : 'Mark as verified seller'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _act(context, () => repo.setVerified(u.id, !u.verified),
                        u.verified ? 'Badge removed' : '${u.name} is now verified ✓');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_rounded),
                  title: const Text('View their shop'),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfileScreen(sellerId: u.id)));
                  },
                ),
                if (snap.hasData)
                  ListTile(
                    leading: Icon(suspended ? Icons.lock_open_rounded : Icons.block_rounded,
                        color: suspended ? AppColors.success : AppColors.danger),
                    title: Text(suspended ? 'Restore account' : 'Suspend account',
                        style: TextStyle(color: suspended ? AppColors.success : AppColors.danger)),
                    subtitle: Text(suspended ? 'Let them sign in again' : 'Signs them out and blocks sign-in'),
                    onTap: () async {
                      Navigator.pop(sheet);
                      if (!suspended &&
                          !await confirmDialog(context,
                              title: 'Suspend ${u.name}?',
                              message: 'They will be signed out and unable to sign in until restored.',
                              confirm: 'Suspend',
                              danger: true)) {
                        return;
                      }
                      if (context.mounted) {
                        _act(context, () => repo.setSuspended(u.id, !suspended),
                            suspended ? 'Account restored' : 'Account suspended');
                      }
                    },
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          _ListHeader(
            hint: 'Search name or town',
            onSearch: (v) => setState(() => _q = v),
            filters: const ['All', 'Verified', 'Not verified'],
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: StreamView<List<AppUser>>(
              create: () => context.read<AdminRepository>().users(),
              loading: const ListSkeleton(),
              builder: (context, all) {
                final q = _q.trim().toLowerCase();
                final list = all
                    .where((u) =>
                        (_filter == 'All' || (_filter == 'Verified') == u.verified) &&
                        (q.isEmpty || '${u.name} ${u.city}'.toLowerCase().contains(q)))
                    .toList();
                if (list.isEmpty) {
                  return const EmptyState(icon: Icons.people_outline_rounded, title: 'No users found', message: '');
                }
                return _animatedList<AppUser>(
                  list,
                  keyOf: (u) => u.id,
                  (u) => _AdminTile(
                    onTap: () => _details(context, u),
                    leading: UserAvatar(name: u.name, imageUrl: u.avatarUrl),
                    title: u.name,
                    subtitle: '${u.city} • joined ${Fmt.date(u.joinedAt)} • ${u.salesCount} sales',
                    badge: u.verified ? const JobTag('Verified', color: AppColors.blue, icon: Icons.verified_rounded) : null,
                    trailing: Icon(Icons.chevron_right_rounded, color: context.muted),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _q = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filters = ['All', for (final s in OrderStatus.values) s.label];
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          _ListHeader(
            hint: 'Search buyer, seller or order number',
            onSearch: (v) => setState(() => _q = v),
            filters: filters,
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: StreamView<List<Order>>(
              create: () => context.read<AdminRepository>().orders(),
              loading: const ListSkeleton(),
              builder: (context, all) {
                final q = _q.trim().toLowerCase();
                final list = all
                    .where((o) =>
                        (_filter == 'All' || o.status.label == _filter) &&
                        (q.isEmpty || '${o.id} ${o.buyerName} ${o.sellerName} ${o.city}'.toLowerCase().contains(q)))
                    .toList();
                if (list.isEmpty) {
                  return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders', message: '');
                }
                final total = list.fold<double>(0, (sum, o) => sum + o.total);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        children: [
                          Text('${list.length} orders', style: TextStyle(color: context.muted)),
                          const Spacer(),
                          Text('Total ${Fmt.price(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _animatedList<Order>(
                        list,
                        keyOf: (o) => o.id,
                        (o) => _AdminTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.blueTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.receipt_long_rounded, color: context.brand),
                          ),
                          title: '#${o.id.substring(0, o.id.length < 8 ? o.id.length : 8).toUpperCase()} • ${Fmt.price(o.total)}',
                          subtitle: '${o.buyerName} → ${o.sellerName} • ${o.city} • ${Fmt.dateTime(o.createdAt)}',
                          badge: Row(children: [
                            StatusChip(o.status),
                            const SizedBox(width: 6),
                            JobTag(o.paymentMethod == 'cod' ? 'Cash on delivery' : 'Online',
                                color: context.muted),
                          ]),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Jobs and CV profiles
// ---------------------------------------------------------------------------

class AdminJobsScreen extends StatelessWidget {
  const AdminJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminRepository>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jobs & CVs'),
          bottom: TabBar(
            labelColor: context.brand,
            unselectedLabelColor: context.muted,
            indicatorColor: AppColors.orange,
            indicatorWeight: 3,
            tabs: [Tab(text: 'Job posts'), Tab(text: 'CV profiles')],
          ),
        ),
        body: TabBarView(
          children: [
            StreamView<List<Job>>(
              create: () => repo.jobs(),
              loading: const ListSkeleton(),
              builder: (context, jobs) {
                if (jobs.isEmpty) {
                  return const EmptyState(icon: Icons.work_outline_rounded, title: 'No job posts', message: '');
                }
                return _animatedList<Job>(
                  jobs,
                  keyOf: (j) => j.id,
                  (j) => _AdminTile(
                    onTap: () => _jobMenu(context, repo, j),
                    leading: JobLogo(company: j.company, categoryId: j.categoryId, size: 46),
                    title: j.title,
                    subtitle: '${j.company} • ${j.ownerName} • ${Fmt.ago(j.createdAt)} • ${j.applicationsCount} applied',
                    badge: JobTag(
                      switch (j.status) {
                        JobStatus.open => 'Open',
                        JobStatus.closed => 'Closed',
                        JobStatus.hidden => 'Hidden',
                      },
                      color: switch (j.status) {
                        JobStatus.open => AppColors.success,
                        JobStatus.closed => context.muted,
                        JobStatus.hidden => AppColors.danger,
                      },
                    ),
                    trailing: Icon(Icons.more_vert_rounded, color: context.muted),
                  ),
                );
              },
            ),
            StreamView<List<TalentProfile>>(
              create: () => repo.talent(),
              loading: const ListSkeleton(),
              builder: (context, people) {
                if (people.isEmpty) {
                  return const EmptyState(icon: Icons.badge_outlined, title: 'No CV profiles', message: '');
                }
                return _animatedList<TalentProfile>(
                  people,
                  keyOf: (t) => t.id,
                  (t) => _AdminTile(
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => TalentDetailScreen(uid: t.id))),
                    leading: UserAvatar(name: t.name, imageUrl: t.photoUrl),
                    title: t.name,
                    subtitle: '${t.headline} • ${t.city}',
                    badge: JobTag(t.visible ? 'Visible' : 'Hidden by owner',
                        color: t.visible ? AppColors.success : context.muted),
                    trailing: IconButton(
                      tooltip: 'Delete profile',
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      onPressed: () async {
                        if (await confirmDialog(context,
                                title: 'Delete ${t.name}\'s CV profile?',
                                message: 'Use this for fake or abusive profiles.',
                                confirm: 'Delete',
                                danger: true) &&
                            context.mounted) {
                          _act(context, () => repo.deleteTalent(t.id), 'Profile deleted');
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _jobMenu(BuildContext context, AdminRepository repo, Job j) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(j.title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(j.company)),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open job'),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: j.id)));
              },
            ),
            ListTile(
              leading: Icon(j.status == JobStatus.hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: context.brand),
              title: Text(j.status == JobStatus.hidden ? 'Unhide (reopen)' : 'Hide job'),
              onTap: () {
                Navigator.pop(sheet);
                final hide = j.status != JobStatus.hidden;
                _act(context, () => repo.setJobStatus(j.id, hide ? 'hidden' : 'open'), hide ? 'Job hidden' : 'Job reopened');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
              title: const Text('Delete job', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(sheet);
                if (await confirmDialog(context,
                        title: 'Delete job?',
                        message: 'The job and its applications will be removed.',
                        confirm: 'Delete',
                        danger: true) &&
                    context.mounted) {
                  _act(context, () => repo.deleteJob(j.id), 'Job deleted');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Banners
// ---------------------------------------------------------------------------

class AdminBannersScreen extends StatelessWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Home banners')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-add-banner',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _NewBannerSheet(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add banner'),
      ),
      body: StreamView<List<AdminBanner>>(
        create: () => repo.banners(),
        loading: const ListSkeleton(),
        builder: (context, banners) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: context.blueTint, borderRadius: BorderRadius.circular(14)),
                child: const Text(
                  'The three built-in banners always show first. Banners you add here appear after them, '
                  'in the order you choose. Switch one off to hide it without deleting.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              if (banners.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Text('No extra banners yet.', textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
                ),
              for (var i = 0; i < banners.length; i++)
                FadeSlideIn(
                  key: ValueKey(banners[i].id),
                  delay: Motion.stagger(i),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BannerTile(banner: banners[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  final AdminBanner banner;
  const _BannerTile({required this.banner});

  @override
  Widget build(BuildContext context) {
    final b = banner;
    final repo = context.read<AdminRepository>();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1440 / 316,
            child: b.imageUrl != null
                ? ProductImage(url: b.imageUrl, categoryId: b.categoryId ?? 'other')
                : Container(
                    decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Text(b.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
          ),
          ListTile(
            title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                '${b.subtitle}\nPosition ${b.order}${b.categoryId == null ? '' : ' • opens ${Catalog.category(b.categoryId!).name}'}'),
            isThreeLine: true,
            trailing: Switch(
              value: b.active,
              activeThumbColor: AppColors.success,
              onChanged: (v) => _act(context, () => repo.setBannerActive(b.id, v), v ? 'Banner shown' : 'Banner hidden'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                if (await confirmDialog(context,
                        title: 'Delete banner?', message: 'This cannot be undone.', confirm: 'Delete', danger: true) &&
                    context.mounted) {
                  _act(context, () => repo.deleteBanner(b.id), 'Banner deleted');
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              label: const Text('Delete', style: TextStyle(color: AppColors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewBannerSheet extends StatefulWidget {
  const _NewBannerSheet();

  @override
  State<_NewBannerSheet> createState() => _NewBannerSheetState();
}

class _NewBannerSheetState extends State<_NewBannerSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _order = TextEditingController(text: '10');
  String? _category;
  XFile? _image;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x != null && mounted) setState(() => _image = x);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = context.read<AdminRepository>();
    try {
      String? url;
      final img = _image;
      if (img != null) url = await repo.uploadBannerImage(await img.readAsBytes());
      await repo.addBanner(
        title: _title.text,
        subtitle: _subtitle.text,
        categoryId: _category,
        imageUrl: url,
        order: int.tryParse(_order.text.trim()) ?? 10,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Banner added');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, "Couldn't add the banner: $e", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('New banner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Back to school deals'),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitle,
                decoration: const InputDecoration(labelText: 'Subtitle'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Opens category (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('None')),
                  for (final c in Catalog.categories) DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Position (lower shows first)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.image_outlined),
                label: Text(_image == null ? 'Add image (wide, about 1440 × 316)' : 'Image selected ✓ — change'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Publish banner'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin team (super admin only)
// ---------------------------------------------------------------------------

class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({super.key});

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final e = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      showSnack(context, 'Enter a valid email address', error: true);
      return;
    }
    await _act(context, () => context.read<AdminRepository>().setAdmin(e, true), '$e is now an admin');
    _email.clear();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin team')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeSlideIn(
            child: _AdminTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(gradient: AppColors.orangeGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
              ),
              title: AppConfig.superAdminEmail,
              subtitle: 'Super admin • full access, can manage admins',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Add an admin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Admins can moderate listings, jobs, users, orders and banners. '
            'They get access the next time they sign in with this email.',
            style: TextStyle(color: context.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'name@example.com', isDense: true),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(90, 48)),
                  onPressed: _add,
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Admins', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          StreamView<List<String>>(
            create: () => repo.adminEmails(),
            loading: const LoadingView(padding: 20),
            builder: (context, emails) {
              if (emails.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No other admins yet.', style: TextStyle(color: context.muted)),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < emails.length; i++)
                    FadeSlideIn(
                      key: ValueKey(emails[i]),
                      delay: Motion.stagger(i),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AdminTile(
                          leading: UserAvatar(name: emails[i]),
                          title: emails[i],
                          subtitle: 'Admin',
                          trailing: IconButton(
                            tooltip: 'Remove admin',
                            icon: const Icon(Icons.person_remove_rounded, color: AppColors.danger),
                            onPressed: () async {
                              final email = emails[i];
                              if (await confirmDialog(context,
                                      title: 'Remove $email?',
                                      message: 'They lose admin access the next time they sign in.',
                                      confirm: 'Remove',
                                      danger: true) &&
                                  context.mounted) {
                                _act(context, () => repo.setAdmin(email, false), '$email removed');
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
