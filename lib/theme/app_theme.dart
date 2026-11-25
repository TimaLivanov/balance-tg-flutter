import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryDark = Color(0xFF1453C2);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color bgLight = Color(0xFFF6F8FB);
  static const Color bgDark = Color(0xFF0F172A);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF111827);
  static const Color textDark = Color(0xFFF8FAFC);
  static const Color mutedLight = Color(0xFF6B7280);
  static const Color mutedDark = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF334155);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          surface: bgLight,
        ),
        scaffoldBackgroundColor: bgLight,
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          color: cardLight,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: danger),
          ),
          labelStyle: const TextStyle(color: mutedLight, fontSize: 14),
          hintStyle: const TextStyle(color: mutedLight, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        dividerTheme: const DividerThemeData(color: borderLight, space: 1, thickness: 1),
        fontFamily: 'System',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textLight),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textLight),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textLight),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textLight),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textLight),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textLight),
          bodyLarge: TextStyle(fontSize: 16, color: textLight),
          bodyMedium: TextStyle(fontSize: 14, color: textLight),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: mutedLight),
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          surface: cardDark,
        ),
        scaffoldBackgroundColor: bgDark,
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          color: cardDark,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardDark,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: danger),
          ),
          labelStyle: const TextStyle(color: mutedDark, fontSize: 14),
          hintStyle: const TextStyle(color: mutedDark, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        dividerTheme: const DividerThemeData(color: borderDark, space: 1, thickness: 1),
        fontFamily: 'System',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textDark),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textDark),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textDark),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textDark),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
          bodyLarge: TextStyle(fontSize: 16, color: textDark),
          bodyMedium: TextStyle(fontSize: 14, color: textDark),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: mutedDark),
        ),
      );
}
