import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design A ("Quiet Ledger"): IBM Plex Sans, flat bordered cards, soft
/// green-grey surfaces, brand green kept. Fonts load from Google Fonts at
/// runtime and fall back to the system font if offline.
///
/// Zonein's visual language in one place, instead of ad hoc colors/padding
/// scattered per screen. Deliberately built on stock Material 3 only --
/// ColorScheme, AppBarTheme, ButtonTheme, InputDecorationTheme -- with no
/// extra design or animation package, so it doesn't add anything to app
/// size or runtime cost. Supports light and dark since that's a one-line
/// difference with ColorScheme.fromSeed and Flutter picks between them
/// from the OS setting automatically.
class AppTheme {
  static const seed = Color(0xFF12896F);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final isLight = brightness == Brightness.light;
    final base =
        ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    final line = isLight ? const Color(0xFFD9E2DE) : const Color(0xFF2A3A33);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.ibmPlexSansTextTheme(base),
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF6F8F7) : colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: isLight ? Colors.white : colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: line),
        ),
      ),
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor:
            isLight ? const Color(0xFFF6F8F7) : colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
