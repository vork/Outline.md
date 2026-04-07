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

    final htmlContent = response.body;

    // Convert HTML to markdown
    final markdown = html2md.convert(htmlContent);

    if (markdown.trim().isEmpty) {
      throw Exception('No content extracted from URL');
    }

    return markdown;
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
