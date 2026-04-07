import 'package:html2md/html2md.dart' as html2md;
import 'package:http/http.dart' as http;

class WebImportService {
  /// Fetches a URL and converts the HTML content to markdown.
  /// Returns the markdown string or throws on error.
  Future<String> importUrl(String url) async {
    // Normalize URL
    var uri = Uri.tryParse(url);
    if (uri == null) throw ArgumentError('Invalid URL: $url');
    if (!uri.hasScheme) {
      uri = Uri.parse('https://$url');
    }

    final response = await http.get(uri, headers: {
      'User-Agent': 'Outline.md/1.0',
      'Accept': 'text/html,application/xhtml+xml',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch URL (${response.statusCode})');
    }

    var htmlContent = response.body;

    // Pre-process: resolve relative image URLs to absolute
    htmlContent = _resolveImageUrls(htmlContent, uri);

    // Order matters: convert display equations first (they contain <math> tags
    // inside <table>s that we don't want the inline pass to grab).
    htmlContent = _convertDisplayEquations(htmlContent);
    htmlContent = _convertMathJaxScripts(htmlContent);
    htmlContent = _convertKaTeXAnnotations(htmlContent);
    // Inline math last — only picks up remaining <math> tags
    htmlContent = _convertMathElements(htmlContent);

    // Convert HTML to markdown
    var markdown = html2md.convert(htmlContent);

    // Post-process: html2md escapes backslashes (\→\\) which breaks LaTeX.
    // Restore single backslashes inside math delimiters.
    markdown = _unescapeBackslashesInMath(markdown);

    // Post-process: convert MathJax delimiters to $/$$ syntax
    markdown = _convertMathJaxDelimiters(markdown);

    // Post-process: normalize single-line $$ content $$ to multi-line
    markdown = _normalizeDisplayMath(markdown);

    // Post-process: catch any remaining relative image URLs in markdown
    markdown = _resolveMarkdownImageUrls(markdown, uri);

    // Post-process: collapse triple+ newlines to double (paragraph breaks)
    markdown = markdown.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    if (markdown.trim().isEmpty) {
      throw Exception('No content extracted from URL');
    }

    return markdown;
  }

  /// Whether an alttext string looks like real LaTeX math worth wrapping in $.
  /// Rejects trivial content like single characters, punctuation, or plain numbers.
  static bool _isNonTrivialLatex(String latex) {
    final trimmed = latex.trim();
    if (trimmed.isEmpty) return false;
    // Single character or symbol — not worth wrapping
    if (trimmed.length <= 2) return false;
    // Contains LaTeX commands (backslash), subscripts, superscripts, or fractions
    if (trimmed.contains(r'\') ||
        trimmed.contains('_') ||
        trimmed.contains('^') ||
        trimmed.contains('{')) {
      return true;
    }
    // Multi-character expressions with operators or parens
    if (RegExp(r'[a-zA-Z].*[=+\-*/(<>]').hasMatch(trimmed)) return true;
    // Plain number or single word — not math
    if (RegExp(r'^[\w.]+$').hasMatch(trimmed)) return false;
    // Has multiple tokens separated by spaces/operators — likely math
    if (trimmed.contains(' ') && trimmed.length > 4) return true;
    return false;
  }

  /// Replace remaining `<math alttext="...">` elements with inline LaTeX `$...$`.
  /// Only wraps content that looks like real LaTeX, not trivial symbols or numbers.
  String _convertMathElements(String html) {
    final mathRegex = RegExp(
      r'<math[^>]*\balttext="([^"]*)"[^>]*>.*?</math>',
      dotAll: true,
    );

    return html.replaceAllMapped(mathRegex, (match) {
      final latex = _unescapeHtml(match.group(1)!);
      if (_isNonTrivialLatex(latex)) {
        return '\$$latex\$';
      }
      // For trivial content, just output the text without math delimiters
      return latex;
    });
  }

  /// Replace display equation tables with `$$ ... $$` blocks.
  /// Handles both `ltx_equation` and `ltx_equationgroup` tables.
  String _convertDisplayEquations(String html) {
    // Process equation groups and equations. Use a regex that finds the
    // opening tag and then manually finds the balanced closing </table>.
    final openTagRegex = RegExp(
      r'<table[^>]*class="ltx_equation(?:group)?[^"]*"[^>]*>',
    );

    // Work through the HTML finding each equation table
    final buffer = StringBuffer();
    var lastEnd = 0;

    for (final openMatch in openTagRegex.allMatches(html)) {
      // Find the balanced closing </table> (accounting for nested tables)
      final tableStart = openMatch.start;
      final afterOpen = openMatch.end;
      var depth = 1;
      var pos = afterOpen;

      while (depth > 0 && pos < html.length) {
        final nextOpen = html.indexOf('<table', pos);
        final nextClose = html.indexOf('</table>', pos);

        if (nextClose == -1) break; // malformed HTML

        if (nextOpen != -1 && nextOpen < nextClose) {
          depth++;
          pos = nextOpen + 6;
        } else {
          depth--;
          if (depth == 0) {
            final tableEnd = nextClose + '</table>'.length;
            final tableHtml = html.substring(tableStart, tableEnd);

            buffer.write(html.substring(lastEnd, tableStart));

            // Extract alttext from all math elements inside
            final altRegex = RegExp(r'alttext="([^"]*)"');
            final altMatches = altRegex.allMatches(tableHtml).toList();

            if (altMatches.isNotEmpty) {
              final latex = altMatches
                  .map((m) => _unescapeHtml(m.group(1)!))
                  .join(' ');
              buffer.write('\n\n\$\$\n$latex\n\$\$\n\n');
            } else {
              buffer.write(tableHtml);
            }

            lastEnd = tableEnd;
          }
          pos = nextClose + '</table>'.length;
        }
      }
    }

    buffer.write(html.substring(lastEnd));
    return buffer.toString();
  }

  /// Convert `<script type="math/tex">` (older MathJax) to `$` delimiters.
  String _convertMathJaxScripts(String html) {
    // Display math
    html = html.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex;\s*mode=display"[^>]*>(.*?)</script>',
        dotAll: true,
      ),
      (m) => '\n\n\$\$\n${_unescapeHtml(m.group(1)!)}\n\$\$\n\n',
    );
    // Inline math
    html = html.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex"[^>]*>(.*?)</script>',
        dotAll: true,
      ),
      (m) => ' \$${_unescapeHtml(m.group(1)!)}\$ ',
    );
    return html;
  }

  /// Convert KaTeX rendered output back to LaTeX source.
  /// KaTeX stores the source in `<annotation encoding="application/x-tex">`.
  String _convertKaTeXAnnotations(String html) {
    // Display KaTeX
    html = html.replaceAllMapped(
      RegExp(
        r'<span[^>]*class="katex-display"[^>]*>.*?<annotation[^>]*encoding="application/x-tex"[^>]*>(.*?)</annotation>.*?</span>',
        dotAll: true,
      ),
      (m) => '\n\n\$\$\n${_unescapeHtml(m.group(1)!)}\n\$\$\n\n',
    );
    // Inline KaTeX
    html = html.replaceAllMapped(
      RegExp(
        r'<span[^>]*class="katex"[^>]*>.*?<annotation[^>]*encoding="application/x-tex"[^>]*>(.*?)</annotation>.*?</span>',
        dotAll: true,
      ),
      (m) => ' \$${_unescapeHtml(m.group(1)!)}\$ ',
    );
    return html;
  }

  /// Resolve relative src attributes in `<img>` tags to absolute URLs.
  String _resolveImageUrls(String html, Uri baseUri) {
    final imgRegex = RegExp(r'(<img[^>]*\bsrc=")([^"]+)(")', dotAll: true);
    return html.replaceAllMapped(imgRegex, (match) {
      final prefix = match.group(1)!;
      final src = match.group(2)!;
      final suffix = match.group(3)!;
      final resolved = baseUri.resolve(src).toString();
      return '$prefix$resolved$suffix';
    });
  }

  /// Resolve relative image URLs in markdown `![alt](url)` syntax.
  String _resolveMarkdownImageUrls(String markdown, Uri baseUri) {
    final imgRegex = RegExp(r'(!\[[^\]]*\]\()([^)]+)(\))');
    return markdown.replaceAllMapped(imgRegex, (match) {
      final prefix = match.group(1)!;
      final src = match.group(2)!;
      final suffix = match.group(3)!;
      if (src.startsWith('http://') || src.startsWith('https://')) {
        return match.group(0)!;
      }
      final resolved = baseUri.resolve(src).toString();
      return '$prefix$resolved$suffix';
    });
  }

  /// Restore single backslashes inside math delimiters.
  /// html2md escapes `\` to `\\` which breaks LaTeX rendering.
  String _unescapeBackslashesInMath(String text) {
    // Display math: $$...$$
    text = text.replaceAllMapped(
      RegExp(r'\$\$(.*?)\$\$', dotAll: true),
      (m) => '\$\$${m.group(1)!.replaceAll(r'\\', r'\')}\$\$',
    );
    // Inline math: $...$  (but not $$)
    text = text.replaceAllMapped(
      RegExp(r'(?<!\$)\$(?!\$)(.*?)(?<!\$)\$(?!\$)'),
      (m) => '\$${m.group(1)!.replaceAll(r'\\', r'\')}\$',
    );
    return text;
  }

  /// Normalize single-line `$$ content $$` to multi-line format so the
  /// cell renderer can parse it as block math.
  String _normalizeDisplayMath(String text) {
    return text.replaceAllMapped(
      RegExp(r'\$\$\s+(.+?)\s+\$\$'),
      (m) => '\$\$\n${m.group(1)!.trim()}\n\$\$',
    );
  }

  /// Convert MathJax `\(...\)` to `$...$` and `\[...\]` to `$$...$$`.
  /// Only converts if the content looks like LaTeX math, not escaped markdown.
  String _convertMathJaxDelimiters(String text) {
    // Display: \[...\] — only if content contains LaTeX commands
    text = text.replaceAllMapped(
      RegExp(r'\\\[(.*?)\\\]', dotAll: true),
      (m) {
        final content = m.group(1)!;
        // Skip if it looks like markdown links [text](url) rather than LaTeX
        if (content.contains('](') || !content.contains(r'\')) {
          return m.group(0)!;
        }
        return '\n\$\$\n${content.trim()}\n\$\$\n';
      },
    );
    // Inline: \(...\) — only if content contains LaTeX commands
    text = text.replaceAllMapped(
      RegExp(r'\\\((.*?)\\\)', dotAll: true),
      (m) {
        final content = m.group(1)!;
        if (!content.contains(r'\') && !_isNonTrivialLatex(content)) {
          return m.group(0)!;
        }
        return '\$$content\$';
      },
    );
    return text;
  }

  /// Unescape common HTML entities in math alttext.
  String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  /// Extracts a title from the markdown content (first H1, or first line).
  String extractTitle(String markdown) {
    for (final line in markdown.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        return trimmed.substring(2).trim();
      }
      if (trimmed.isNotEmpty) {
        return trimmed.length > 60 ? '${trimmed.substring(0, 60)}...' : trimmed;
      }
    }
    return 'Imported Page';
  }
}
