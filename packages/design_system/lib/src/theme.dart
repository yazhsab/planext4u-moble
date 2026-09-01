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
          // Navy on brand teal is 4.91:1; white on brand teal is only 3.49:1.
          onPrimary: Planext4uColors.navy,
          secondary: Planext4uColors.amber,
          onSecondary: Planext4uColors.navy,
          error: Planext4uColors.danger,
          surface: isDark
              ? Planext4uColors.darkSurface
              : Planext4uColors.surface,
          onSurface: isDark ? Colors.white : Planext4uColors.navy,
          outline: isDark ? Planext4uColors.darkBorder : Planext4uColors.border,
          surfaceContainerLow: isDark
              ? Planext4uColors.darkCanvas
              : Planext4uColors.softSurface,
        );
    final baseTextTheme = ThemeData(
      brightness: brightness,
    ).textTheme.apply(fontFamily: Planext4uTypography.bodyFamily);
    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontFamily: Planext4uTypography.displayFamily,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontFamily: Planext4uTypography.displayFamily,
        fontWeight: FontWeight.w800,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontFamily: Planext4uTypography.displayFamily,
        fontWeight: FontWeight.w800,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontFamily: Planext4uTypography.displayFamily,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: Planext4uTypography.displayFamily,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontFamily: Planext4uTypography.displayFamily,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: Planext4uTypography.displayFamily,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Planext4uRadii.control),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: Planext4uTypography.bodyFamily,
      fontFamilyFallback: const [Planext4uTypography.tamilFallbackFamily],
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark
          ? Planext4uColors.darkCanvas
          : Planext4uColors.canvas,
      focusColor: Planext4uColors.amber,
      appBarTheme: AppBarTheme(
        backgroundColor: Planext4uColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Planext4uRadii.card),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: Planext4uSpacing.x5,
            vertical: Planext4uSpacing.x3,
          ),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: Planext4uSpacing.x5,
            vertical: Planext4uSpacing.x3,
          ),
          shape: controlShape,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Planext4uSpacing.x4,
          vertical: Planext4uSpacing.x4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Planext4uRadii.control),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Planext4uRadii.control),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Planext4uRadii.control),
          borderSide: const BorderSide(color: Planext4uColors.teal, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: Planext4uColors.teal.withValues(alpha: 0.16),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Planext4uRadii.pill),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Planext4uRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Planext4uRadii.hero),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _Planext4uPageTransitionsBuilder(),
          TargetPlatform.iOS: _Planext4uPageTransitionsBuilder(),
          TargetPlatform.macOS: _Planext4uPageTransitionsBuilder(),
          TargetPlatform.linux: _Planext4uPageTransitionsBuilder(),
          TargetPlatform.windows: _Planext4uPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _Planext4uPageTransitionsBuilder(),
        },
      ),
    );
  }
}

final class _Planext4uPageTransitionsBuilder extends PageTransitionsBuilder {
  const _Planext4uPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(opacity: animation, child: child);
  }
}
