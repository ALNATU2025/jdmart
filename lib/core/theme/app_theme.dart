import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/widgets/motion.dart';

/// Brand colours sampled directly from the JDMart logo.
class AppColors {
  static const blue = Color(0xFF0029A8);
  static const blueDark = Color(0xFF001E7D);
  static const blueLight = Color(0xFFE8EDFB);
  static const orange = Color(0xFFFB6401);
  static const orangeLight = Color(0xFFFFF0E5);
  static const navy = Color(0xFF142237);
  static const grey = Color(0xFF6B7385);
  static const greyLight = Color(0xFFF4F6FA);
  static const border = Color(0xFFE3E7EF);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const white = Colors.white;

  // Dark mode
  static const darkBg = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF151E31);
  static const darkSurfaceHigh = Color(0xFF1D2840);
  static const darkBorder = Color(0xFF2A3652);
  static const darkInk = Color(0xFFE8ECF4);
  static const darkMuted = Color(0xFF98A2B7);
  static const blueBright = Color(0xFF7C9DFF); // brand blue that reads well on dark

  static const brandGradient = LinearGradient(
    colors: [blue, Color(0xFF1543D6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const orangeGradient = LinearGradient(
    colors: [orange, Color(0xFFFF8A3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get light => _build(false);
  static ThemeData get dark => _build(true);

  static ThemeData _build(bool dark) {
    final surface = dark ? AppColors.darkSurface : Colors.white;
    final bg = dark ? AppColors.darkBg : AppColors.greyLight;
    final ink = dark ? AppColors.darkInk : AppColors.navy;
    final line = dark ? AppColors.darkBorder : AppColors.border;
    final muted = dark ? AppColors.darkMuted : AppColors.grey;
    final link = dark ? AppColors.blueBright : AppColors.blue;

    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        primary: dark ? AppColors.blueBright : AppColors.blue,
        onPrimary: dark ? AppColors.darkBg : Colors.white,
        secondary: AppColors.orange,
        surface: surface,
        onSurface: ink,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: bg,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      textTheme: textTheme,
      // Smooth fade-and-rise between pages everywhere; iOS keeps its native swipe-back.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SmoothPageTransitionsBuilder(),
        TargetPlatform.fuchsia: SmoothPageTransitionsBuilder(),
        TargetPlatform.windows: SmoothPageTransitionsBuilder(),
        TargetPlatform.linux: SmoothPageTransitionsBuilder(),
        TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: line)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.orange),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: link,
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: ink, textColor: ink),
      iconTheme: IconThemeData(color: ink),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: ink),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: dark ? AppColors.darkSurfaceHigh : null,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: link,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: link, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        labelStyle: TextStyle(color: muted),
        border: border(line),
        enabledBorder: border(line),
        focusedBorder: border(link, 1.6),
        errorBorder: border(AppColors.danger),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: AppColors.blue,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.darkSurfaceHigh : AppColors.navy,
        contentTextStyle: GoogleFonts.poppins(color: dark ? AppColors.darkInk : Colors.white, fontSize: 14),
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tabBarTheme: TabBarThemeData(labelColor: link, unselectedLabelColor: muted, indicatorColor: AppColors.orange),
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line),
    );
  }
}
