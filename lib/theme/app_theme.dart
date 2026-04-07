import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static TextTheme _buildTextTheme(Brightness brightness, {double fontScale = 1.0}) {
    final color = brightness == Brightness.light
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFE8E8E8);

    final headingStyle = GoogleFonts.averiaSerifLibre(color: color);
    final bodyStyle = GoogleFonts.geistMono(color: color);

    double s(double size) => (size * fontScale).roundToDouble();

    return TextTheme(
      displayLarge: headingStyle.copyWith(fontSize: s(57), fontWeight: FontWeight.w700),
      displayMedium: headingStyle.copyWith(fontSize: s(45), fontWeight: FontWeight.w700),
      displaySmall: headingStyle.copyWith(fontSize: s(36), fontWeight: FontWeight.w700),
      headlineLarge: headingStyle.copyWith(fontSize: s(32), fontWeight: FontWeight.w700),
      headlineMedium: headingStyle.copyWith(fontSize: s(28), fontWeight: FontWeight.w700),
      headlineSmall: headingStyle.copyWith(fontSize: s(24), fontWeight: FontWeight.w600),
      titleLarge: headingStyle.copyWith(fontSize: s(22), fontWeight: FontWeight.w600),
      titleMedium: headingStyle.copyWith(fontSize: s(18), fontWeight: FontWeight.w600),
      titleSmall: headingStyle.copyWith(fontSize: s(16), fontWeight: FontWeight.w600),
      bodyLarge: bodyStyle.copyWith(fontSize: s(16)),
      bodyMedium: bodyStyle.copyWith(fontSize: s(14)),
      bodySmall: bodyStyle.copyWith(fontSize: s(12)),
      labelLarge: bodyStyle.copyWith(fontSize: s(14), fontWeight: FontWeight.w500),
      labelMedium: bodyStyle.copyWith(fontSize: s(12), fontWeight: FontWeight.w500),
      labelSmall: bodyStyle.copyWith(fontSize: s(11), fontWeight: FontWeight.w500),
    );
  }

  static String get monoFontFamily => GoogleFonts.geistMono().fontFamily ?? 'monospace';

  static ThemeData light({double fontScale = 1.0}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B7FFF),
      brightness: Brightness.light,
    );
    final textTheme = _buildTextTheme(Brightness.light, fontScale: fontScale);

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

  static ThemeData dark({double fontScale = 1.0}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7B9FFF),
      brightness: Brightness.dark,
    );
    final textTheme = _buildTextTheme(Brightness.dark, fontScale: fontScale);

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
