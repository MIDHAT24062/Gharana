import 'package:flutter/material.dart';

class AppColors {
  // Pinterest-inspired warm palette
  // Primary: deep terracotta/rust
  static const primary       = Color(0xFFB85C38);
  static const primaryDark   = Color(0xFF8B3E22);
  static const primaryLight  = Color(0xFFD4745A);

  // Accent: warm sage green
  static const accent        = Color(0xFF6B8F71);
  static const accentLight   = Color(0xFF8FB896);

  // Neutrals
  static const background    = Color(0xFFFAF7F4);   // warm off-white
  static const surface       = Color(0xFFFFFFFF);
  static const surfaceWarm   = Color(0xFFF5EFE8);   // warm card bg
  static const divider       = Color(0xFFEDE8E0);

  // Text
  static const textPrimary   = Color(0xFF2C1810);
  static const textSecondary = Color(0xFF8C7B6B);
  static const textLight     = Color(0xFFBFAFA0);

  // Semantic
  static const income        = Color(0xFF6B8F71);
  static const expense       = Color(0xFFB85C38);
  static const warning       = Color(0xFFD4A853);
  static const error         = Color(0xFFC0392B);
  static const success       = Color(0xFF27AE60);

  // Member colors
  static const member1       = Color(0xFFB85C38);  // terracotta
  static const member2       = Color(0xFF6B8F71);  // sage
  static const member3       = Color(0xFF8B6BAE);  // dusty purple

  static const gradientWarm = LinearGradient(
    colors: [Color(0xFFB85C38), Color(0xFFD4745A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientSage = LinearGradient(
    colors: [Color(0xFF5A7A60), Color(0xFF6B8F71)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientCard = LinearGradient(
    colors: [Color(0xFF2C1810), Color(0xFF4A2C1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      background: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceWarm,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins'),
      hintStyle: const TextStyle(color: AppColors.textLight, fontFamily: 'Poppins'),
    ),
  );
}
