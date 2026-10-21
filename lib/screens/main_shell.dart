import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'auth/login_screen.dart';
import 'categories_screen.dart';
import 'chats_screen.dart';
import 'home_screen.dart';
import 'sell/add_product_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Lets nested widgets switch tabs (e.g. "See all categories"). Pass -1 to open Sell.
  static void goTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_MainShellState>()?.setTab(index);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  void setTab(int i) {
    if (i < 0) {
      _sell();
      return;
    }
    setState(() => _tab = i);
  }

  Future<void> _sell() async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final unread = user == null ? 0 : context.watch<ChatProvider>().unreadHint(user.id);

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [HomeScreen(), CategoriesScreen(), ChatsScreen(), AccountScreen()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          onPressed: _sell,
          elevation: 3,
          shape: const CircleBorder(),
          backgroundColor: AppColors.orange,
          child: const Icon(Icons.add_rounded, size: 34, color: Colors.white),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 12,
        shadowColor: Colors.black26,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 70,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _item(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
            _item(1, Icons.grid_view_rounded, Icons.grid_view_outlined, 'Categories'),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 34),
                child: Text('Sell',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orange)),
              ),
            ),
            _item(2, Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Messages', badge: unread),
            _item(3, Icons.person_rounded, Icons.person_outline_rounded, 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _item(int i, IconData active, IconData inactive, String label, {int badge = 0}) {
    final selected = _tab == i;
    final color = selected ? AppColors.blue : AppColors.grey;
    return Expanded(
      child: InkResponse(
        onTap: () => setTab(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              backgroundColor: AppColors.orange,
              label: Text('$badge'),
              child: Icon(selected ? active : inactive, color: color),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
