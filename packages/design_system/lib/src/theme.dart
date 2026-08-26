import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class Planext4uTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: Planext4uColors.teal,
          brightness: brightness,
        ).copyWith(
          primary: Planext4uColors.teal,
          secondary: Planext4uColors.amber,
          error: Planext4uColors.danger,
          surface: isDark ? Planext4uColors.navy : Planext4uColors.surface,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF001521)
          : Planext4uColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: Planext4uColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF0A2A3F) : Planext4uColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Planext4uRadii.card),
          side: BorderSide(
            color: isDark ? const Color(0xFF23475C) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Planext4uRadii.control),
          ),
        ),
      ),
    );
  }
}
