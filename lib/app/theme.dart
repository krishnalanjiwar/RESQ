import 'package:flutter/material.dart';

import '../ui/brand.dart';

/// RES-Q design system on Material 3.
///
/// Light mode is clean white with Google's four accents: blue (primary),
/// yellow (warnings), green (good news) and red, reserved for emergencies.
/// Inter gives crisp typography; headings are heavier with tight tracking.
abstract final class ResqTheme {
  static const String fontFamily = 'Inter';

  /// Monospace for identifiers that people compare character by character.
  static const String monoFamily = 'RobotoMono';

  /// Content never stretches wider than this on tablets / landscape.
  static const double maxContentWidth = 640;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static TextTheme _type(TextTheme base) {
    TextStyle? h(TextStyle? s, FontWeight w, double tracking) =>
        s?.copyWith(fontFamily: fontFamily, fontWeight: w, letterSpacing: tracking);
    return base
        .apply(fontFamily: fontFamily)
        .copyWith(
          displaySmall: h(base.displaySmall, FontWeight.w800, -1.0),
          headlineLarge: h(base.headlineLarge, FontWeight.w800, -0.8),
          headlineMedium: h(base.headlineMedium, FontWeight.w700, -0.6),
          headlineSmall: h(base.headlineSmall, FontWeight.w700, -0.4),
          titleLarge: h(base.titleLarge, FontWeight.w700, -0.3),
          titleMedium: h(base.titleMedium, FontWeight.w600, -0.1),
          titleSmall: h(base.titleSmall, FontWeight.w600, 0),
          labelLarge: h(base.labelLarge, FontWeight.w600, 0.1),
          bodyLarge: base.bodyLarge?.copyWith(fontFamily: fontFamily, height: 1.45),
          bodyMedium: base.bodyMedium?.copyWith(fontFamily: fontFamily, height: 1.45),
          bodySmall: base.bodySmall?.copyWith(fontFamily: fontFamily, height: 1.4),
        );
  }

  static ThemeData _build(Brightness brightness) {
    final seeded = ColorScheme.fromSeed(
      seedColor: Brand.blue,
      brightness: brightness,
      error: brightness == Brightness.light ? Brand.signalRed : const Color(0xFFFFB4AB),
    );
    final scheme = brightness == Brightness.dark
        ? seeded
        : seeded.copyWith(
            primary: Brand.gBlue,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFD2E3FC),
            onPrimaryContainer: const Color(0xFF174EA6),
            secondary: Brand.gYellow,
            onSecondary: const Color(0xFF202124),
            secondaryContainer: const Color(0xFFFEF7E0),
            onSecondaryContainer: const Color(0xFF7A4F01),
            tertiary: Brand.gGreen,
            onTertiary: Colors.white,
            tertiaryContainer: const Color(0xFFE6F4EA),
            onTertiaryContainer: const Color(0xFF0D652D),
            error: Brand.gRed,
            onError: Colors.white,
            errorContainer: const Color(0xFFFCE8E6),
            onErrorContainer: const Color(0xFFA50E0E),
            surface: Colors.white,
            onSurface: const Color(0xFF202124),
            onSurfaceVariant: const Color(0xFF5F6368),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFF8F9FA),
            surfaceContainer: const Color(0xFFF1F3F4),
            surfaceContainerHigh: const Color(0xFFECEEF0),
            surfaceContainerHighest: const Color(0xFFE8EAED),
            outline: const Color(0xFFBDC1C6),
            outlineVariant: const Color(0xFFDADCE0),
          );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final text = _type(base.textTheme);
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.light ? Colors.white : scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: text.labelLarge)),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: text.labelLarge,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(textStyle: WidgetStatePropertyAll(text.labelLarge)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: text.titleSmall?.copyWith(color: scheme.onSurface),
      ),
      tabBarTheme: TabBarThemeData(labelStyle: text.labelLarge, unselectedLabelStyle: text.labelLarge),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surface),
    );
  }
}
