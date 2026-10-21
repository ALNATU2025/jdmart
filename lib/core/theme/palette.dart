import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Colours that change between light and dark mode. Use these instead of
/// hard-coded whites and greys:  `color: context.surface`.
extension Palette on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Cards, sheets, bars.
  Color get surface => isDark ? AppColors.darkSurface : Colors.white;

  /// Page background.
  Color get soft => isDark ? AppColors.darkBg : AppColors.greyLight;

  /// Main text and icons.
  Color get ink => isDark ? AppColors.darkInk : AppColors.navy;

  /// Secondary text.
  Color get muted => isDark ? AppColors.darkMuted : AppColors.grey;

  /// Borders and dividers.
  Color get line => isDark ? AppColors.darkBorder : AppColors.border;

  /// Brand blue for text, icons and links.
  Color get brand => isDark ? AppColors.blueBright : AppColors.blue;

  /// Light tints behind icons and notices.
  Color get blueTint => isDark ? const Color(0xFF1B2A5C) : AppColors.blueLight;
  Color get orangeTint => isDark ? const Color(0xFF3A2516) : AppColors.orangeLight;

  /// Skeleton / placeholder grey.
  Color get skeleton => isDark ? AppColors.darkSurfaceHigh : const Color(0xFFEDF0F6);
}
