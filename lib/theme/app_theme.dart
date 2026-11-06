import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Greens (Tradition, Freshness, Leaves)
  static const Color primary = Color(0xFF003820);
  static const Color primaryContainer = Color(0xFF0F5132);
  static const Color leafGreen = Color(0xFF0F5132);
  static const Color leafGreenDark = Color(0xFF003820);
  static const Color onPrimaryContainer = Color(0xFF95D4AC);
  static const Color primaryFixed = Color(0xFFB0F1C7);

  // Secondary Oranges (Pickle oil, Appetite, Energy, CTAs)
  static const Color pickleOrange = Color(0xFFFC820C);
  static const Color secondary = Color(0xFF964900);
  static const Color secondaryOrange = Color(0xFFFC820C);
  static const Color orangeDark = Color(0xFF964900);
  static const Color secondaryContainer = Color(0xFFFC820C);
  static const Color onSecondaryContainer = Color(0xFF5E2C00);

  // Tertiary Yellows (Turmeric, Mustard, Celebration)
  static const Color spiceYellow = Color(0xFFD2A500);
  static const Color tertiary = Color(0xFF755B00);
  static const Color tertiaryFixed = Color(0xFFFFDF90);

  // Status & Spice
  static const Color chilliRed = Color(0xFFC0392B);
  static const Color error = Color(0xFFBA1A1A);

  // Warm Surfaces & Containers from DESIGN.md
  static const Color surface = Color(0xFFFFF8F6);
  static const Color background = Color(0xFFFFF8F6);
  static const Color surfaceDim = Color(0xFFFBD1C4);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFFFF1ED);
  static const Color surfaceContainer = Color(0xFFFFE9E3);
  static const Color surfaceHigh = Color(0xFFFFE2DA);
  static const Color surfaceHighest = Color(0xFFFFDBD0);

  // Text & Outlines
  static const Color textPrimary = Color(0xFF2C160E);
  static const Color onSurface = Color(0xFF2C160E);
  static const Color textSecondary = Color(0xFF5D4037);
  static const Color textTertiary = Color(0xFF8D6E63);
  static const Color outline = Color(0xFF707971);
  static const Color outlineVariant = Color(0xFFC0C9C0);
  static const Color borderSubtle = Color(0xFFEFE4D2);
  static const Color borderCard = Color(0x145D4037); // rgba(93,64,55,.08)

  // Status Colors
  static const Color statusVeg = Color(0xFF0F5132);
  static const Color successBg = Color(0xFFDFF3E6);
  static const Color white = Colors.white;

  // Compatibility Aliases
  static const Color warmCream = Color(0xFFFFF8F6);
  static const Color cardBorder = Color(0xFFEBDDC9);
  static const Color earthBrown = Color(0xFF5D4037);
  static const Color pickleOrangeDark = Color(0xFF964900);
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryContainer,
        primary: AppColors.primaryContainer,
        secondary: AppColors.pickleOrange,
        tertiary: AppColors.spiceYellow,
        surface: AppColors.surface,
        error: AppColors.chilliRed,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pickleOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.leafGreen,
          side: const BorderSide(color: AppColors.leafGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surfaceLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.borderCard, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceHighest),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceHighest),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.leafGreen, width: 1.5),
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
