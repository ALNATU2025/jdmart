import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import '../../state/wishlist_provider.dart';
import '../admin/admin_console_screen.dart';
import '../auth/auth_guard.dart';
import '../jobs/jobs_home_screen.dart';
import '../jobs/my_jobs_screen.dart';
import '../jobs/talent_edit_screen.dart';
import '../orders/orders_screen.dart';
import '../sell/my_listings_screen.dart';
import '../sell/seller_hub_screen.dart';
import 'edit_profile_screen.dart';
import 'legal_links.dart';
import 'wishlist_screen.dart';
import '../../core/theme/palette.dart';
import '../../shared/widgets/theme_toggle.dart';
import '../delivery/rider_screen.dart';
import '../notifications/notifications_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final me = session.profile;
    final saved = context.select<WishlistProvider, int>((w) => w.ids.length);

    if (me == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const JDLogo(height: 140),
                  const SizedBox(height: 24),
                  const Text(AppConfig.tagline, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Sign in with your email to buy, sell, chat with sellers and track orders.',
                      textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
                  const SizedBox(height: 28),
                  ElevatedButton(onPressed: () => ensureLoggedIn(context), child: const Text('Sign in / Sign up')),
                  const SizedBox(height: 24),
                  const ThemeModeSelector(),
                  const SizedBox(height: 8),
                  ..._legalTiles(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 28),
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: context.surface, shape: BoxShape.circle),
                  child: UserAvatar(name: me.name, imageUrl: me.avatarUrl, radius: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(me.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                          ),
                          if (me.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(session.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('${me.city} • Member since ${Fmt.date(me.joinedAt)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (session.isAdmin)
            _section('Admin', [
              _tile(context, Icons.admin_panel_settings_rounded, 'Admin console',
                  session.isSuperAdmin ? 'Super admin • manage everything' : 'Moderate and manage JDMart',
                  const AdminConsoleScreen(),
                  color: context.ink),
            ], index: 0),
          _section('Selling', [
            _tile(context, Icons.storefront_rounded, 'Seller Hub', 'Sales, earnings & alerts', const SellerHubScreen(),
                color: AppColors.orange),
            _tile(context, Icons.inventory_2_outlined, 'My listings', 'Edit, mark sold or relist', const MyListingsScreen()),
            _tile(context, Icons.point_of_sale_rounded, 'Sales orders', 'Orders from your buyers',
                const OrdersScreen(sellerView: true)),
          ], index: 1),
          _section('Buying', [
            _tile(context, Icons.notifications_rounded, 'Notifications', 'Orders, messages, jobs and deliveries',
                const NotificationsScreen(),
                color: AppColors.orange),
            _tile(context, Icons.receipt_long_outlined, 'My orders', 'Track your purchases', const OrdersScreen()),
            _tile(context, Icons.favorite_border_rounded, 'Saved items', '$saved saved', const WishlistScreen()),
            _tile(context, Icons.delivery_dining_rounded, 'Deliveries & tracking', 'Live map, rider jobs, delivery codes',
                const RiderScreen(),
                color: AppColors.orange),
          ], index: 2),
          _section('Jobs', [
            _tile(context, Icons.work_rounded, 'Jobs board', 'Find jobs or find talent', const JobsHomeScreen(),
                color: AppColors.orange),
            _tile(context, Icons.work_history_outlined, 'My jobs & applications', 'Your posts and applications',
                const MyJobsScreen()),
            _tile(context, Icons.badge_outlined, 'My CV profile', 'Let employers find and contact you',
                const TalentEditScreen(), color: AppColors.success),
          ], index: 3),
          _section('Help & legal', [
            if (AppConfig.supportWhatsApp.isNotEmpty || AppConfig.supportPhone.isNotEmpty)
              ListTile(
                leading: Icon(Icons.support_agent_rounded, color: context.brand),
                title: const Text('Contact support'),
                subtitle: Text(AppConfig.supportWhatsApp.isNotEmpty ? AppConfig.supportWhatsApp : AppConfig.supportPhone),
                onTap: () {
                  final wa = AppConfig.supportWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
                  launchUrl(
                    wa.isNotEmpty
                        ? Uri.parse('https://wa.me/$wa')
                        : Uri.parse('tel:${AppConfig.supportPhone.replaceAll(' ', '')}'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            if (AppConfig.supportEmail.isNotEmpty)
              ListTile(
                leading: Icon(Icons.email_outlined, color: context.brand),
                title: const Text('Email us'),
                subtitle: const Text(AppConfig.supportEmail),
                onTap: () => launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}')),
              ),
            ListTile(
              leading: Icon(Icons.shield_outlined, color: context.brand),
              title: const Text('Safety tips'),
              onTap: () => _safety(context),
            ),
            ..._legalTiles(),
          ], index: 4),
          _section('Appearance', [const ThemeModeSelector()], index: 5),
          _section('Account', [
            ListTile(
              leading: Icon(Icons.logout_rounded, color: context.ink),
              title: const Text('Sign out'),
              onTap: () async {
                if (await confirmDialog(context, title: 'Sign out?', message: 'You can sign back in any time.')) {
                  await session.signOut();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
              title: const Text('Delete my account', style: TextStyle(color: AppColors.danger)),
              subtitle: const Text('Removes your profile, listings, saved items and chats'),
              onTap: () => _deleteAccount(context),
            ),
          ], index: 5),
          Padding(
            padding: EdgeInsets.all(24),
            child: Text('JDMart • Made in Sierra Leone 🇸🇱',
                textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 12)),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  List<Widget> _legalTiles() => [
        if (AppConfig.termsUrl.isNotEmpty)
          ListTile(
            leading: Builder(builder: (context) => Icon(Icons.description_outlined, color: context.brand)),
            title: const Text('Terms of use'),
            onTap: () => openLink(AppConfig.termsUrl),
          ),
        if (AppConfig.privacyPolicyUrl.isNotEmpty)
          ListTile(
            leading: Builder(builder: (context) => Icon(Icons.privacy_tip_outlined, color: context.brand)),
            title: const Text('Privacy policy'),
            onTap: () => openLink(AppConfig.privacyPolicyUrl),
          ),
      ];

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete your account?',
      message: 'This permanently deletes your profile, listings, saved items and chats. '
          'Records of completed orders are kept as required for buyers and sellers. This cannot be undone.',
      confirm: 'Delete',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final users = context.read<UserRepository>();
    final session = context.read<SessionProvider>();
    final err = await runWithProgress(context, () async {
      await users.deleteAccount();
      await session.signOut();
    }, label: 'Deleting account…');
    if (context.mounted) {
      showSnack(context, err ?? 'Your account has been deleted.', error: err != null);
    }
  }

  Widget _section(String title, List<Widget> children, {int index = 0}) => FadeSlideIn(
        delay: Motion.stagger(index, stepMs: 60),
        child: Builder(builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title.toUpperCase(),
                  style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
              child: Column(children: children),
            ),
          ],
        ),
        )),
      );

  Widget _tile(BuildContext context, IconData icon, String title, String sub, Widget page,
          {Color color = AppColors.blue}) =>
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      );

  void _safety(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stay safe on JDMart', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              SizedBox(height: 14),
              Text('• Meet in busy, public places when buying in person.'),
              SizedBox(height: 6),
              Text('• Inspect the item before paying.'),
              SizedBox(height: 6),
              Text('• Pay through JDMart checkout or on delivery — never send money in advance to strangers.'),
              SizedBox(height: 6),
              Text('• Never share your Orange Money or Afrimoney PIN, or a JDMart sign-in code, with anyone.'),
              SizedBox(height: 6),
              Text('• Report suspicious listings with the ⋮ menu on the listing page.'),
            ],
          ),
        ),
      ),
    );
  }
}
