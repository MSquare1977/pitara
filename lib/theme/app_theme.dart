import 'package:flutter/material.dart';

/// One place for the whole look and feel. Same navy + brass palette as the
/// icon, splash and pitch one-pager — just applied with bolder contrast,
/// heavier type and rounder, deeper surfaces.
class AppTheme {
  AppTheme._();

  // Brand palette
  static const Color navy900 = Color(0xFF0B1426);
  static const Color navy800 = Color(0xFF14213D);
  static const Color navy700 = Color(0xFF1F3361);
  static const Color brass = Color(0xFFB8860B);
  static const Color brassDeep = Color(0xFF8A6508);
  static const Color brassLight = Color(0xFFF0C14B);
  static const Color ivory = Color(0xFFF7F4EC);

  /// Android maps this to its built-in serif (Noto Serif) — gives headings an
  /// editorial, premium feel without bundling a font file or adding a package.
  static const String serif = 'serif';

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: brass,
    brightness: Brightness.light,
  ).copyWith(
    primary: brassDeep,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFF3E6BD),
    onPrimaryContainer: navy800,
    secondary: navy800,
    onSecondary: ivory,
    secondaryContainer: const Color(0xFFE9E0C6),
    onSecondaryContainer: navy800,
    surface: ivory,
    onSurface: navy800,
    onSurfaceVariant: const Color(0xFF5A6480),
    surfaceContainerHigh: Colors.white,
    surfaceContainerHighest: const Color(0xFFF0EBDD),
    outlineVariant: const Color(0xFFDDD5BE),
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: brassLight,
    brightness: Brightness.dark,
  ).copyWith(
    primary: brassLight,
    onPrimary: navy800,
    primaryContainer: const Color(0xFF3D3210),
    onPrimaryContainer: brassLight,
    secondary: const Color(0xFFC9D3EA),
    onSecondary: navy800,
    secondaryContainer: const Color(0xFF22345C),
    onSecondaryContainer: brassLight,
    surface: navy900,
    onSurface: const Color(0xFFF3EFE4),
    onSurfaceVariant: const Color(0xFFA9B3C9),
    surfaceContainerHigh: const Color(0xFF16233F),
    surfaceContainerHighest: const Color(0xFF1E2E50),
    outlineVariant: const Color(0xFF2C3B5E),
  );

  static ThemeData light() => _build(_lightScheme);
  static ThemeData dark() => _build(_darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final rounded16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: serif,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 52),
          shape: rounded16,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 1.2),
          shape: rounded16,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontFamily: serif,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? navy700 : navy800,
        contentTextStyle: const TextStyle(color: ivory, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      drawerTheme: const DrawerThemeData(
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    );
  }
}