import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------
/// SMART HEALTH GUARDIAN — DESIGN SYSTEM
/// Base: black / white / greyscale.
/// Accent: teal (primary actions, "good" health states).
/// Alert:  red   (SOS, emergencies, critical readings).
/// Warn:   amber (attention-needed, medium risk).
/// ---------------------------------------------------------------------
class AppColors {
  AppColors._();

  // Base — black & white
  static const Color black = Color(0xFF0B0B0C);
  static const Color surfaceDark = Color(0xFF17181A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF6F7F8);
  static const Color grey100 = Color(0xFFF1F1F3);
  static const Color grey300 = Color(0xFFD9DADE);
  static const Color grey500 = Color(0xFF8E9096);
  static const Color grey600 = Color(0xFF6B6C70);
  static const Color grey700 = Color(0xFF4A4B50);

  // Accent — used sparingly, deliberately
  static const Color teal = Color(0xFF0FB6A6);
  static const Color tealDark = Color(0xFF0A8E82);
  static const Color tealTint = Color(0xFFE3F7F5);

  // Status colors
  static const Color danger = Color(0xFFE2503A);
  static const Color dangerTint = Color(0xFFFCE7E3);
  static const Color warn = Color(0xFFE0A93B);
  static const Color warnTint = Color(0xFFFBF1DD);
  static const Color good = teal;
  static const Color goodTint = tealTint;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.offWhite,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.black,
        secondary: AppColors.teal,
        surface: AppColors.white,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.offWhite,
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.black,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.black,
        displayColor: AppColors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.grey300, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
        labelStyle: const TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w600, fontSize: 12),
        hintStyle: const TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.grey100, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.grey100, thickness: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.black,
        unselectedItemColor: AppColors.grey500,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
