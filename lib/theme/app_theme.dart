import 'package:flutter/material.dart';

class AppTheme {
  static const Color _primaryDefault = Color(0xFF1F6FEB);
  static Color _accent = _primaryDefault;
  static bool _dark = false;

  /// Акцент из настроек (аналог accent из HTML-версии).
  static Color get primary => _accent;

  /// Тема из настроек: true — тёмная, false — светлая.
  static bool get isDark => _dark;

  static void applyAccent(String? key) {
    switch (key) {
      case 'emerald':
        _accent = const Color(0xFF10B981);
        break;
      case 'sky':
        _accent = const Color(0xFF0EA5E9);
        break;
      case 'violet':
        _accent = const Color(0xFF8B5CF6);
        break;
      default:
        _accent = _primaryDefault;
    }
  }

  static void applyTheme(String? key) {
    _dark = key == 'dark';
  }

  static const Color primaryDark = Color(0xFF1453C2);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static const Color _bgLight = Color(0xFFF6F8FB);
  static const Color _bgDark = Color(0xFF0F172A);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _cardDark = Color(0xFF1E293B);
  static const Color _textLight = Color(0xFF111827);
  static const Color _textDark = Color(0xFFF8FAFC);
  static const Color _mutedLight = Color(0xFF6B7280);
  static const Color _mutedDark = Color(0xFF94A3B8);
  static const Color _borderLight = Color(0xFFE5E7EB);
  static const Color _borderDark = Color(0xFF334155);

  /// Активные цвета — зависят от выбранной темы.
  static Color get bg => _dark ? _bgDark : _bgLight;
  static Color get card => _dark ? _cardDark : _cardLight;
  static Color get text => _dark ? _textDark : _textLight;
  static Color get muted => _dark ? _mutedDark : _mutedLight;
  static Color get border => _dark ? _borderDark : _borderLight;

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: _bgLight,
    ),
    scaffoldBackgroundColor: _bgLight,
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      color: _cardLight,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _cardLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger),
      ),
      labelStyle: const TextStyle(color: _mutedLight, fontSize: 14),
      hintStyle: const TextStyle(color: _mutedLight, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: _borderLight,
      space: 1,
      thickness: 1,
    ),
    fontFamily: 'System',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: _textLight,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: _textLight,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: _textLight,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _textLight,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _textLight,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textLight,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: _textLight),
      bodyMedium: TextStyle(fontSize: 14, color: _textLight),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _mutedLight,
      ),
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: _cardDark,
    ),
    scaffoldBackgroundColor: _bgDark,
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      color: _cardDark,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _cardDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger),
      ),
      labelStyle: const TextStyle(color: _mutedDark, fontSize: 14),
      hintStyle: const TextStyle(color: _mutedDark, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: _borderDark,
      space: 1,
      thickness: 1,
    ),
    fontFamily: 'System',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: _textDark,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: _textDark,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: _textDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _textDark,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _textDark,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textDark,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: _textDark),
      bodyMedium: TextStyle(fontSize: 14, color: _textDark),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _mutedDark,
      ),
    ),
  );
}
