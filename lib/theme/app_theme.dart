import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const canvas = Color(0xFFF0F4F8);
  static const surface = Color(0xFFFFFFFF);
  static const smartBlue = Color(0xFF0466C8);
  static const steelAzure = Color(0xFF0353A4);
  static const primaryText = Color(0xFF002855);
  static const coolSteel = Color(0xFF979DAC);
  static const slateGrey = Color(0xFF7D8597);
  static const blueSlate = Color(0xFF5C677D);
  static const outline = slateGrey;
  static const oceanGradientEnd = Color(0xFF5C677D);

  // Compatibility aliases used throughout the existing component library.
  static const alabaster = canvas;
  static const forest = smartBlue;
  static const terracotta = smartBlue;
  static const charcoal = primaryText;
  static const slate = coolSteel;
  static const warmSurface = surface;
  static const warmField = Color(0x1F979DAC);
  static const warmOutline = Color(0x337D8597);
  static const sand = coolSteel;
  static const sage = blueSlate;
}

abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppPalette.smartBlue,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD8E9FA),
      onPrimaryContainer: AppPalette.primaryText,
      secondary: AppPalette.steelAzure,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE5EDF5),
      onSecondaryContainer: AppPalette.primaryText,
      surface: AppPalette.surface,
      onSurface: AppPalette.primaryText,
      surfaceContainerHighest: AppPalette.canvas,
      onSurfaceVariant: AppPalette.blueSlate,
      outline: AppPalette.slateGrey,
      outlineVariant: AppPalette.coolSteel,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
    );

    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    final textTheme = base.textTheme.apply(
      bodyColor: AppPalette.charcoal,
      displayColor: AppPalette.charcoal,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppPalette.alabaster,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: textTheme.copyWith(
        displaySmall: textTheme.displaySmall?.copyWith(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          height: 1.05,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          height: 1.08,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppPalette.warmSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.warmSurface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.warmOutline,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.steelAzure,
          foregroundColor: Colors.white,
        ),
      ),
      iconTheme: const IconThemeData(color: AppPalette.coolSteel),
    );
  }
}
