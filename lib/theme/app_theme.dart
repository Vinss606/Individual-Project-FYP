import 'package:flutter/material.dart';

/// Central place for the MyKasih visual language so every screen
/// stays consistent with the high-fidelity prototype.
class AppColors {
  AppColors._();

  static const Color primaryDark = Color(0xFF163A2E); // deep green header
  static const Color primary = Color(0xFF1F5C43); // buttons / accents
  static const Color primaryLight = Color(0xFFE3F0E7); // pale green chip bg
  static const Color gold = Color(0xFFE0A94A); // star / highlight
  static const Color background = Color(0xFFF4F6F5);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color danger = Color(0xFFC0392B);
  static const Color warningBg = Color(0xFFFFF6E0);
  static const Color warningBorder = Color(0xFFF0D98C);
  static const Color chartGreen = Color(0xFF1F5C43);
  static const Color chartGold = Color(0xFFD79A3B);
  static const Color chartBlue = Color(0xFF3E8ED0);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        background: AppColors.background,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.primaryLight.withOpacity(0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Reusable rounded card decoration used across every screen.
BoxDecoration appCardDecoration({double radius = 16}) {
  return BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}
