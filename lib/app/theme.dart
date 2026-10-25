import 'package:flutter/material.dart';

/// Operational UI contract: pure black, pure white, Roboto Mono,
/// square corners, no gradients, no shadows.
abstract final class ResqTheme {
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const String fontFamily = 'RobotoMono';

  static const OutlinedBorder _square = RoundedRectangleBorder();
  static const BorderSide _hairline = BorderSide(color: white);

  static ThemeData get monochrome {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: white,
      onPrimary: black,
      secondary: white,
      onSecondary: black,
      error: white,
      onError: black,
      surface: black,
      onSurface: white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: black,
      fontFamily: fontFamily,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: _hairline),
      ),
      cardTheme: const CardThemeData(
        color: black,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(side: _hairline),
      ),
      dividerTheme: const DividerThemeData(color: white, thickness: 1),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: white,
          side: _hairline,
          shape: _square,
          minimumSize: const Size(48, 56),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: white,
          foregroundColor: black,
          shape: _square,
          minimumSize: const Size(48, 56),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: white, width: 2),
        ),
      ),
    );
  }
}
