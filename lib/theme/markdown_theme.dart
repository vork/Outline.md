import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

MarkdownStyleSheet markdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final codeBackground =
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
  final codeBorder =
      isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD);
  final monoStyle = GoogleFonts.geistMono(
    fontSize: 13,
    color: theme.colorScheme.onSurface,
  );

  return MarkdownStyleSheet(
    h1: theme.textTheme.headlineMedium,
    h2: theme.textTheme.titleLarge,
    h3: theme.textTheme.titleMedium,
    h4: theme.textTheme.titleSmall,
    h5: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    h6: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    p: theme.textTheme.bodyMedium,
    code: monoStyle.copyWith(backgroundColor: codeBackground),
    codeblockDecoration: BoxDecoration(
      color: codeBackground,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: codeBorder),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 3,
        ),
      ),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
    listBullet: theme.textTheme.bodyMedium,
    tableHead:
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    tableBody: theme.textTheme.bodyMedium,
    tableBorder: TableBorder.all(color: codeBorder, width: 1),
    tableHeadAlign: TextAlign.left,
    tableCellsPadding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: theme.dividerColor, width: 1),
      ),
    ),
  );
}
