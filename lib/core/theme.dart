import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design A, "Lembar Kerja": Public Sans, a pale green-grey canvas with a
/// white work sheet, tonal (borderless) tiles, deep green #07775A for
/// buttons and white-on-green text. Same tokens as the web dashboard so the
/// two look like one product. Fonts are bundled in assets/google_fonts.
class AppTheme {
  static const brand = Color(0xFF0A8F6B);
  static const brandDeep = Color(0xFF07775A);
  static const tint = Color(0xFFE6EFEB);
  static const soft = Color(0xFFDCEFE7);
  static const line = Color(0xFFD3DDD8);
  static const muted = Color(0xFF4D5F57);
  static const ink = Color(0xFF14211C);
  static const warn = Color(0xFF9A4A05);
  static const warnBg = Color(0xFFFBE8CC);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = isLight
        ? ColorScheme.fromSeed(seedColor: brandDeep, brightness: brightness).copyWith(
            primary: brandDeep,
            onPrimary: Colors.white,
            primaryContainer: soft,
            onPrimaryContainer: brandDeep,
            surface: Colors.white,
            onSurface: ink,
            onSurfaceVariant: muted,
            surfaceContainerHighest: tint,
            surfaceContainer: tint,
            outline: muted,
            outlineVariant: line,
            error: const Color(0xFFA3201A),
            errorContainer: const Color(0xFFF9DEDB),
            surfaceTint: Colors.transparent,
          )
        : ColorScheme.fromSeed(seedColor: brand, brightness: brightness).copyWith(
            primary: const Color(0xFF2FC79B),
            onPrimary: const Color(0xFF06201A),
            primaryContainer: const Color(0xFF1D3A30),
            onPrimaryContainer: const Color(0xFF2FC79B),
            surface: const Color(0xFF0E1512),
            onSurface: const Color(0xFFE8F1ED),
            onSurfaceVariant: const Color(0xFFA3B7AE),
            surfaceContainerHighest: const Color(0xFF1A2722),
            surfaceContainer: const Color(0xFF1A2722),
            outlineVariant: const Color(0xFF2A3A33),
            surfaceTint: Colors.transparent,
          );
    final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    final text = GoogleFonts.publicSansTextTheme(base).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final tonal = scheme.surfaceContainerHighest;
    final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: tonal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        subtitleTextStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          shape: btnShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          shape: btnShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: btnShape)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: btnShape,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: tonal,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
    );
  }
}
