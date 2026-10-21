import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'edit_profile_screen.dart';
import 'orders_screen.dart';
import 'sell/my_listings_screen.dart';
import 'sell/seller_hub_screen.dart';
import 'wishlist_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.user;

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
                  const Text('Buy Smart. Sell Faster.',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Sign in to track orders, save items, chat with sellers and start selling.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey)),
                  const SizedBox(height: 28),
                  ElevatedButton(onPressed: () => ensureLoggedIn(context), child: const Text('Sign In')),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final orders = context.watch<OrderProvider>();
    final products = context.watch<ProductProvider>();
    final myOrders = orders.forBuyer(me.id).length;
    final myListings = products.bySeller(me.id).length;
    final saved = products.wishlist.length;

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
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: UserAvatar(user: me, radius: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(me.name,
                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(me.phone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('${me.city} • Member since ${Fmt.date(me.joinedAt)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _stat('$myOrders', 'Orders'),
                    _stat('$myListings', 'Listings'),
                    _stat('$saved', 'Saved'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _section('Selling', [
            _tile(context, Icons.storefront_rounded, 'Seller Hub', 'Sales, earnings & performance',
                const SellerHubScreen(), color: AppColors.orange),
            _tile(context, Icons.inventory_2_outlined, 'My listings', '$myListings items', const MyListingsScreen()),
            _tile(context, Icons.point_of_sale_rounded, 'Sales orders', 'Orders from your buyers',
                const OrdersScreen(sellerView: true)),
          ]),
          _section('Buying', [
            _tile(context, Icons.receipt_long_outlined, 'My orders', 'Track your purchases', const OrdersScreen()),
            _tile(context, Icons.favorite_border_rounded, 'Saved items', '$saved items', const WishlistScreen()),
          ]),
          _section('Support', [
            ListTile(
              leading: const Icon(Icons.help_outline_rounded, color: AppColors.blue),
              title: const Text('Help centre'),
              subtitle: const Text('Call or WhatsApp +232 76 000 000'),
              onTap: () => showSnack(context, 'Support: +232 76 000 000 • help@jdmart.sl'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined, color: AppColors.blue),
              title: const Text('Safety tips'),
              onTap: () => _safety(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Sign out', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                if (await confirmDialog(context, title: 'Sign out?', message: 'You can sign back in anytime.')) {
                  auth.logout();
                }
              },
            ),
          ]),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('JDMart v1.0.0 • Made in Sierra Leone 🇸🇱',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(children: children),
            ),
          ],
        ),
      );

  Widget _tile(BuildContext context, IconData icon, String title, String sub, Widget page,
          {Color color = AppColors.blue}) =>
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
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
      backgroundColor: Colors.white,
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
              Text('• Use JDMart checkout or cash on delivery — never send money upfront to strangers.'),
              SizedBox(height: 6),
              Text('• Never share your Orange Money or Afrimoney PIN with anyone.'),
              SizedBox(height: 6),
              Text('• Report suspicious sellers to help@jdmart.sl.'),
            ],
          ),
        ),
      ),
    );
  }
}
