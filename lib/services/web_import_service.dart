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

    // Pre-process: convert math from various sources to LaTeX delimiters
    htmlContent = _convertMathElements(htmlContent);       // MathML alttext
    htmlContent = _convertDisplayEquations(htmlContent);   // arxiv ltx_equation tables
    htmlContent = _convertMathJaxScripts(htmlContent);     // <script type="math/tex">
    htmlContent = _convertKaTeXAnnotations(htmlContent);   // KaTeX <annotation>

    // Convert HTML to markdown
    var markdown = html2md.convert(htmlContent);

    // Post-process: convert MathJax \(...\) and \[...\] delimiters to $/$$ syntax
    markdown = _convertMathJaxDelimiters(markdown);

    // Post-process: catch any remaining relative image URLs in markdown
    markdown = _resolveMarkdownImageUrls(markdown, uri);

    if (markdown.trim().isEmpty) {
      throw Exception('No content extracted from URL');
    }

    return markdown;
  }

  /// Replace <math alttext="...">...</math> with inline LaTeX $...$
  /// This handles arxiv-style MathML with alttext containing LaTeX source.
  String _convertMathElements(String html) {
    // Match <math ... alttext="LATEX" ...>...</math>
    final mathRegex = RegExp(
      r'<math[^>]*\balttext="([^"]*)"[^>]*>.*?</math>',
      dotAll: true,
    );

    return html.replaceAllMapped(mathRegex, (match) {
      final latex = match.group(1)!;
      // Unescape HTML entities in the alttext
      final unescaped = _unescapeHtml(latex);
      return ' \$$unescaped\$ ';
    });
  }

  /// Replace <table class="ltx_equation ...">...<math alttext="...">...</table>
  /// with display math $$ ... $$
  String _convertDisplayEquations(String html) {
    // Match equation tables that contain math with alttext
    final eqnRegex = RegExp(
      r'<table[^>]*class="ltx_equation[^"]*"[^>]*>.*?</table>',
      dotAll: true,
    );

    return html.replaceAllMapped(eqnRegex, (match) {
      final tableHtml = match.group(0)!;
      // Extract all alttext values from math elements inside
      final altRegex = RegExp(r'alttext="([^"]*)"');
      final altMatches = altRegex.allMatches(tableHtml);
      if (altMatches.isEmpty) return tableHtml;

      // Join all math fragments (some equations have multiple <math> in one row)
      final latex = altMatches
          .map((m) => _unescapeHtml(m.group(1)!))
          .join(' ');
      return '\n\n\$\$\n$latex\n\$\$\n\n';
    });
  }

  /// Convert <script type="math/tex">...</script> (older MathJax) to $ delimiters.
  String _convertMathJaxScripts(String html) {
    // Display math: <script type="math/tex; mode=display">
    html = html.replaceAllMapped(
      RegExp(
        r'<script[^>]*type="math/tex;\s*mode=display"[^>]*>(.*?)</script>',
        dotAll: true,
      ),
      (m) => '\n\n\$\$\n${_unescapeHtml(m.group(1)!)}\n\$\$\n\n',
    );
    // Inline math: <script type="math/tex">
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
  /// KaTeX stores the source in <annotation encoding="application/x-tex">
  String _convertKaTeXAnnotations(String html) {
    // Find <span class="katex-display">...<annotation encoding="application/x-tex">LATEX</annotation>...</span>
    // and <span class="katex">...<annotation>...</span>
    // Replace the entire katex span with the LaTeX from the annotation.

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

  /// Resolve relative src attributes in <img> tags to absolute URLs.
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

  /// Resolve relative image URLs in markdown ![alt](url) syntax.
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

  /// Convert MathJax \(...\) → $...$ and \[...\] → $$...$$ delimiters in text.
  String _convertMathJaxDelimiters(String text) {
    // Display: \[...\]
    text = text.replaceAllMapped(
      RegExp(r'\\\[(.*?)\\\]', dotAll: true),
      (m) => '\n\$\$\n${m.group(1)!.trim()}\n\$\$\n',
    );
    // Inline: \(...\)
    text = text.replaceAllMapped(
      RegExp(r'\\\((.*?)\\\)', dotAll: true),
      (m) => '\$${m.group(1)!}\$',
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
