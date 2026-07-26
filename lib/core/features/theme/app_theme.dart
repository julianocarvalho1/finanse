import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color primary = Color(0xFF3DDC78);
  static const Color darkBackground = Color(0xFF071017);
  static const Color darkSurface = Color(0xFF101A21);

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      secondary: primary,
      surface: darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButtonTheme:
      const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: darkBackground,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF17232B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7F6),
        foregroundColor: Color(0xFF152019),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButtonTheme:
      const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: darkBackground,
      ),
    );
  }
}