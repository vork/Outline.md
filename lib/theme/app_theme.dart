import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFE8E8E8);

    final headingStyle = GoogleFonts.averiaSerifLibre(color: color);
    final bodyStyle = GoogleFonts.geistMono(color: color);

    return TextTheme(
      displayLarge: headingStyle.copyWith(fontSize: 57, fontWeight: FontWeight.w700),
      displayMedium: headingStyle.copyWith(fontSize: 45, fontWeight: FontWeight.w700),
      displaySmall: headingStyle.copyWith(fontSize: 36, fontWeight: FontWeight.w700),
      headlineLarge: headingStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: headingStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
      headlineSmall: headingStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: headingStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: headingStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleSmall: headingStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: bodyStyle.copyWith(fontSize: 16),
      bodyMedium: bodyStyle.copyWith(fontSize: 14),
      bodySmall: bodyStyle.copyWith(fontSize: 12),
      labelLarge: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: bodyStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
    );
  }

  static String get monoFontFamily => GoogleFonts.geistMono().fontFamily ?? 'monospace';

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B7FFF),
      brightness: Brightness.light,
    );
    final textTheme = _buildTextTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      dividerColor: const Color(0xFFE8E8E8),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 20),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 18,
          padding: const EdgeInsets.all(8),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7B9FFF),
      brightness: Brightness.dark,
    );
    final textTheme = _buildTextTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      dividerColor: const Color(0xFF333333),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 20),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF242424),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 18,
          padding: const EdgeInsets.all(8),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.black),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
