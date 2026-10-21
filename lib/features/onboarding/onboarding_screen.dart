import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/local_store.dart';
import '../auth/auth_flow_screen.dart';
import '../shell/main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.shopping_bag_rounded,
      'Buy Smart',
      'Discover products from sellers in Freetown, Bo, Kenema, Makeni and across Sierra Leone.',
      AppColors.blue
    ),
    (
      Icons.storefront_rounded,
      'Sell Faster',
      'Snap a photo, set your price in Leones and reach buyers all over the country in minutes.',
      AppColors.orange
    ),
    (
      Icons.account_balance_wallet_rounded,
      'Pay Your Way',
      'Orange Money, Afrimoney, card or cash on delivery — safe, simple and local.',
      AppColors.success
    ),
  ];

  Future<void> _finish({bool login = false}) async {
    await LocalStore.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
    if (login) {
      Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AuthFlowScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final (icon, title, body, color) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (i == 0) Image.asset('assets/images/logo.png', height: 170),
                        if (i != 0)
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Icon(icon, size: 90, color: color),
                          ),
                        const SizedBox(height: 40),
                        Text(title,
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
                        const SizedBox(height: 14),
                        Text(body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, color: AppColors.grey, height: 1.5)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i ? AppColors.orange : AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
              child: ElevatedButton(
                onPressed: () => last
                    ? _finish(login: true)
                    : _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
                child: Text(last ? 'Get Started' : 'Next'),
              ),
            ),
            if (last)
              TextButton(onPressed: _finish, child: const Text('Browse as guest'))
            else
              const SizedBox(height: 48),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
