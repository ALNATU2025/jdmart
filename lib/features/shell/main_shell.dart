import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/chat_repository.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import '../account/account_screen.dart';
import '../auth/auth_guard.dart';
import '../catalog/categories_screen.dart';
import '../chat/chats_screen.dart';
import '../home/home_screen.dart';
import '../sell/add_product_screen.dart';
import '../../core/theme/palette.dart';
import '../onboarding/welcome_tour.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Lets nested widgets switch tabs. Pass -1 to open Sell.
  static void goTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_MainShellState>()?.setTab(index);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _tab = 0;
  String? _unreadUid;
  Stream<int>? _unread;

  late final AnimationController _fade = AnimationController(vsync: this, duration: Motion.medium, value: 1);

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void setTab(int i) {
    if (i < 0) {
      _sell();
      return;
    }
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
    _fade.forward(from: 0);
  }

  Future<void> _sell() async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
  }

  Stream<int>? _unreadFor(String? uid) {
    if (uid != _unreadUid) {
      _unreadUid = uid;
      _unread = uid == null ? null : context.read<ChatRepository>().unreadCount(uid);
    }
    return _unread;
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.isLoggedIn ? s.uid : null);
    final unreadStream = _unreadFor(uid);

    return Scaffold(
      body: WelcomeTour(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
          child: IndexedStack(
            index: _tab,
            children: const [HomeScreen(), CategoriesScreen(), ChatsScreen(), AccountScreen()],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: Pressable(
          scale: 0.9,
          haptic: true,
          onTap: _sell,
          child: Tooltip(
            message: 'Sell an item',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.orangeGradient,
                boxShadow: [
                  BoxShadow(color: AppColors.orange.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: const Icon(Icons.add_rounded, size: 34, color: Colors.white),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: context.surface,
        elevation: 12,
        shadowColor: Colors.black26,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 70,
        padding: EdgeInsets.zero,
        child: StreamBuilder<int>(
          stream: unreadStream,
          builder: (_, snap) {
            final unread = snap.data ?? 0;
            return Row(
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
            );
          },
        ),
      ),
    );
  }

  Widget _item(int i, IconData active, IconData inactive, String label, {int badge = 0}) {
    final selected = _tab == i;
    final color = selected ? AppColors.blue : context.muted;
    return Expanded(
      child: InkResponse(
        onTap: () => setTab(i),
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Motion.medium,
              curve: Motion.curve,
              padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? context.blueTint : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: Motion.medium,
                curve: Curves.easeOutBack,
                child: Badge(
                  isLabelVisible: badge > 0,
                  backgroundColor: AppColors.orange,
                  label: PopOnChange(value: badge, child: Text('$badge')),
                  child: Icon(selected ? active : inactive, color: color),
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: Motion.medium,
              style: TextStyle(
                fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
