import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

class NovaColors {
  static const Color bgDeep = Color(0xFF05070F);
  static const Color navy = Color(0xFF0B1226);
  static const Color navyLight = Color(0xFF131C3A);
  static const Color purple = Color(0xFF9B5CFF);
  static const Color blue = Color(0xFF2EC4FF);
  static const Color pink = Color(0xFFFF4FD8);
  static const Color success = Color(0xFF3DFFA2);
  static const Color danger = Color(0xFFFF5470);
  static const Color textPrimary = Color(0xFFF2F5FF);
  static const Color textSecondary = Color(0xFFA7B0D0);
}

class NovaText {
  /// Futuristic display type (Orbitron). Falls back to the system font for
  /// scripts Orbitron does not cover, such as Persian.
  static TextStyle display(
    double size, {
    Color color = NovaColors.textPrimary,
    double spacing = 1.2,
  }) {
    return TextStyle(
      fontFamily: 'Orbitron',
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      fontWeight: FontWeight.w700,
      fontVariations: const <FontVariation>[FontVariation('wght', 700)],
    );
  }

  static TextStyle body(
    double size, {
    Color color = NovaColors.textPrimary,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(fontSize: size, color: color, fontWeight: weight);
  }

  static TextStyle muted(double size) =>
      TextStyle(fontSize: size, color: NovaColors.textSecondary);
}

ThemeData buildNovaTheme({required bool fa}) {
  const scheme = ColorScheme.dark(
    primary: NovaColors.purple,
    secondary: NovaColors.blue,
    surface: NovaColors.navy,
    error: NovaColors.danger,
    onPrimary: Colors.white,
    onSecondary: Color(0xFF021018),
    onSurface: NovaColors.textPrimary,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: NovaColors.navy,
    fontFamily: fa ? 'Vazirmatn' : null,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: NovaColors.textPrimary,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NovaColors.navyLight,
      contentTextStyle: TextStyle(color: NovaColors.textPrimary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.selected)
            ? NovaColors.blue
            : NovaColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.selected)
            ? NovaColors.purple.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.12),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: NovaColors.blue,
      thumbColor: NovaColors.blue,
      inactiveTrackColor: Colors.white24,
    ),
  );
}
