import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Brand Colors
  static const Color primary = Color(0xFF00E5FF);       // Cyan
  static const Color primaryDark = Color(0xFF0097A7);
  static const Color secondary = Color(0xFF7C4DFF);     // Purple
  static const Color danger = Color(0xFFFF3D71);        // Red
  static const Color warning = Color(0xFFFFAA00);       // Amber
  static const Color safe = Color(0xFF00E676);          // Green
  static const Color suspicious = Color(0xFFFFAA00);   // Amber

  // Background
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF131929);
  static const Color surfaceVariant = Color(0xFF1C2439);
  static const Color border = Color(0xFF252D42);

  // Text
  static const Color textPrimary = Color(0xFFEDF2FF);
  static const Color textSecondary = Color(0xFF8896B3);
  static const Color textTertiary = Color(0xFF4D5E80);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        error: danger,
        surface: surface,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(color: textTertiary),
      ),
    );
  }

  // Verdict colors
  static Color forVerdict(String level) {
    switch (level.toLowerCase()) {
      case 'safe':
        return safe;
      case 'suspicious':
        return suspicious;
      case 'danger':
        return danger;
      default:
        return textSecondary;
    }
  }
}
