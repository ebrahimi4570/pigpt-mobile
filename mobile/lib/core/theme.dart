import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark-first teal brand tokens matching pigpt.ir CSS variables.
class PigptColors {
  static const brand = Color(0xFF2DD4BF);
  static const brandDeep = Color(0xFF0F766E);
  static const brandSoft = Color(0x1F2DD4BF);

  static const bg = Color(0xFF0B1220);
  static const bgElevated = Color(0xFF121A2B);
  static const bgHover = Color(0xFF182235);
  static const border = Color(0xFF243044);

  static const ink = Color(0xFFE8EEF7);
  static const inkMuted = Color(0xFF9AA8BC);
  static const inkFaint = Color(0xFF6B7A90);

  static const danger = Color(0xFFF87171);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);

  static const lightBg = Color(0xFFF4F7FB);
  static const lightInk = Color(0xFF0F172A);
  static const lightBrand = Color(0xFF0F766E);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightMuted = Color(0xFF5B6B7C);
  static const lightFaint = Color(0xFF8A97A8);
  static const lightElevated = Color(0xFFFFFFFF);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? bgElevated : lightElevated;

  static Color mutedOf(BuildContext context) =>
      isDark(context) ? inkMuted : lightMuted;

  static Color faintOf(BuildContext context) =>
      isDark(context) ? inkFaint : lightFaint;

  static Color inkOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? border : lightBorder;

  static Color bubbleUser(BuildContext context) => isDark(context)
      ? brandDeep.withValues(alpha: 0.35)
      : const Color(0xFFD7EDEA);

  static Color bubbleAssistant(BuildContext context) =>
      isDark(context) ? bgElevated : lightElevated;

  static Color codeBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF0A0F18) : const Color(0xFFF1F5F9);
}

class PigptTheme {
  static TextTheme _text(Brightness brightness) {
    final base = GoogleFonts.vazirmatnTextTheme();
    final color =
        brightness == Brightness.dark ? PigptColors.ink : PigptColors.lightInk;
    return base.apply(bodyColor: color, displayColor: color);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: PigptColors.brand,
      onPrimary: const Color(0xFF042F2E),
      secondary: PigptColors.brandDeep,
      surface: PigptColors.bgElevated,
      onSurface: PigptColors.ink,
      error: PigptColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: PigptColors.bg,
      textTheme: _text(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: PigptColors.bg.withValues(alpha: 0.92),
        foregroundColor: PigptColors.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.vazirmatn(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: PigptColors.ink,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PigptColors.bgElevated,
        selectedItemColor: PigptColors.brand,
        unselectedItemColor: PigptColors.inkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: PigptColors.bgElevated,
        indicatorColor: PigptColors.brandSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? PigptColors.brand : PigptColors.inkFaint,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? PigptColors.brand : PigptColors.inkMuted,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: PigptColors.bgElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PigptColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PigptColors.bg,
        hintStyle: const TextStyle(color: PigptColors.inkFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PigptColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PigptColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PigptColors.brand, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PigptColors.brand,
          foregroundColor: const Color(0xFF042F2E),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.vazirmatn(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PigptColors.brand,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: PigptColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PigptColors.bgHover,
        contentTextStyle: GoogleFonts.vazirmatn(color: PigptColors.ink),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: PigptColors.border,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PigptColors.brand,
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: PigptColors.lightBrand,
      onPrimary: Colors.white,
      secondary: PigptColors.brand,
      surface: Colors.white,
      onSurface: PigptColors.lightInk,
      error: PigptColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: PigptColors.lightBg,
      textTheme: _text(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        foregroundColor: PigptColors.lightInk,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.vazirmatn(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: PigptColors.lightInk,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: PigptColors.brandSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFFF7F9FC),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PigptColors.lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: PigptColors.lightFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PigptColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PigptColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PigptColors.lightBrand, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PigptColors.lightBrand,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PigptColors.lightBrand,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: PigptColors.lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.vazirmatn(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: PigptColors.lightBorder,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PigptColors.lightBrand,
      ),
    );
  }
}
