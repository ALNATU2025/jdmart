import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../state/theme_controller.dart';
import 'motion.dart';

/// Sun / moon button that flips light and dark mode with a spin.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return IconButton(
      tooltip: dark ? 'Light mode' : 'Dark mode',
      onPressed: () => context.read<ThemeController>().toggle(context),
      icon: AnimatedSwitcher(
        duration: Motion.slow,
        transitionBuilder: (c, a) => RotationTransition(
          turns: Tween(begin: 0.6, end: 1.0).animate(a),
          child: ScaleTransition(scale: a, child: c),
        ),
        child: Icon(
          dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(dark),
          color: dark ? const Color(0xFFFFC94D) : context.ink,
        ),
      ),
    );
  }
}

/// System / Light / Dark choice for the Account page.
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    Widget option(ThemeMode m, IconData icon, String label) {
      final on = controller.mode == m;
      return Expanded(
        child: Pressable(
          scale: 0.95,
          haptic: true,
          onTap: () => controller.setMode(m),
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.curve,
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: on ? AppColors.brandGradient : null,
              color: on ? null : context.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(icon, color: on ? Colors.white : context.muted),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                      color: on ? Colors.white : context.ink,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          option(ThemeMode.system, Icons.brightness_auto_rounded, 'Auto'),
          option(ThemeMode.light, Icons.light_mode_rounded, 'Light'),
          option(ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
        ],
      ),
    );
  }
}
