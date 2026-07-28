import 'package:flutter/material.dart';
import 'app_constants.dart';

/// Light/dark themes matching Section 7 (UI Design System).
class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
      primary: AppColors.primaryBlue,
      secondary: AppColors.secondaryTeal,
      error: AppColors.errorRed,
      surface: AppColors.cardLight,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardLight,
      elevation: 1, // Section 7.3 — 1dp elevation shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // Section 7.3 — 8dp corner radius
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(), // Section 7.3 — outlined text fields
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48), // Section 7.3 — 48dp tall, full width
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryBlue, // Section 7.3 — loading indicator colour
    ),
    textTheme: _textTheme(AppColors.textPrimary, AppColors.textSecondary),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.dark,
      primary: AppColors.primaryBlue,
      secondary: AppColors.secondaryTeal,
      error: AppColors.errorRed,
      surface: AppColors.cardDark,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardDark,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryBlue,
    ),
    textTheme: _textTheme(Colors.white, Colors.white70),
  );

  /// Section 7.2 — Typography (Roboto, sp sizes map roughly to Material 3
  /// text styles). Bengali mode should swap the fontFamily to
  /// "HindSiliguri" once that font is bundled — see pubspec.yaml.
  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineSmall: TextStyle(
        // Heading 1 — Screen Title: Roboto 22sp Bold
        fontSize: 22, fontWeight: FontWeight.bold, color: primary,
      ),
      titleMedium: TextStyle(
        // Heading 2 — Section Title: Roboto 18sp Medium
        fontSize: 18, fontWeight: FontWeight.w500, color: primary,
      ),
      bodyMedium: TextStyle(
        // Body Text: Roboto 14sp Regular
        fontSize: 14, fontWeight: FontWeight.normal, color: primary,
      ),
      labelSmall: TextStyle(
        // Caption / Label: Roboto 12sp Regular
        fontSize: 12, fontWeight: FontWeight.normal, color: secondary,
      ),
      labelLarge: TextStyle(
        // Button Text: Roboto 14sp Medium, All Caps applied at the widget level
        fontSize: 14, fontWeight: FontWeight.w500, color: primary,
      ),
    );
  }
}
