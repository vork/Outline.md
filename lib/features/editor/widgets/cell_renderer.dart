import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import '../../../theme/markdown_theme.dart';
import 'fullscreen_image_viewer.dart';
import 'mermaid_diagram.dart';

class CellRenderer extends StatelessWidget {
  final String content;
  final VoidCallback? onTap;
  final bool isCollapsed;
  final String? documentBasePath;

  const CellRenderer({
    super.key,
    required this.content,
    this.onTap,
    this.isCollapsed = false,
    this.documentBasePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String effectiveContent;
    if (content.trim().isEmpty) {
      effectiveContent = '_Empty cell_';
    } else if (isCollapsed) {
      effectiveContent = content.split('\n').first;
    } else {
      effectiveContent = content;
    }

    final segments = _parseSegments(effectiveContent);

    final hasOnlyMarkdown =
        segments.length == 1 && segments.first.type == _SegType.markdown;

    return GestureDetector(
      onDoubleTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: hasOnlyMarkdown
            ? _buildMarkdown(context, theme, segments.first.text)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final seg in segments)
                    if (seg.type == _SegType.math)
                      _MathBlock(tex: seg.text, theme: theme)
                    else if (seg.type == _SegType.image)
                      _buildImage(
                          context, seg.imageUri!, seg.imageAlt, theme)
                    else if (seg.text.trim().isNotEmpty)
                      _buildMarkdown(context, theme, seg.text),
                ],
              ),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, ThemeData theme, String data) {
    return MarkdownBody(
      data: data,
      styleSheet: markdownStyleSheet(context),
      selectable: false,
      inlineSyntaxes: [_MathInlineSyntax()],
      builders: {
        'code': _CodeBlockBuilder(theme),
        'math': _MathInlineBuilder(theme),
      },
      onTapLink: (text, href, title) {},
    );
  }

  Widget _buildImage(
      BuildContext context, String src, String? alt, ThemeData theme) {
    Widget image;
    VoidCallback? onTapFullScreen;

    try {
      final uri = Uri.tryParse(src);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        image = Image.network(
          src,
          errorBuilder: (_, err, _) => _imagePlaceholder(theme, alt, err),
        );
        onTapFullScreen = () =>
            FullScreenImageViewer.showNetwork(context, src, alt: alt);
      } else {
        final resolved = documentBasePath != null
            ? p.join(p.dirname(documentBasePath!), src)
            : src;
        final file = File(resolved);
        if (file.existsSync()) {
          image = Image.file(
            file,
            errorBuilder: (_, err, _) => _imagePlaceholder(theme, alt, err),
          );
          onTapFullScreen = () =>
              FullScreenImageViewer.showFile(context, file, alt: alt);
        } else {
          image = _imagePlaceholder(theme, alt, null);
        }
      }
    } catch (e) {
      image = _imagePlaceholder(theme, alt, e);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTapFullScreen,
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: image,
                  ),
                ),
                if (onTapFullScreen != null)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.fullscreen,
                            size: 16, color: Colors.white70),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (alt != null && alt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                alt,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(ThemeData theme, String? alt, Object? error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined,
              color: theme.colorScheme.onSurfaceVariant, size: 32),
          if (alt != null && alt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              alt,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unified segment parser: splits content into markdown, block-math, and images
// ---------------------------------------------------------------------------

enum _SegType { markdown, math, image }

class _Segment {
  final String text;
  final _SegType type;
  final String? imageUri;
  final String? imageAlt;

  const _Segment.markdown(this.text)
      : type = _SegType.markdown,
        imageUri = null,
        imageAlt = null;
  const _Segment.math(this.text)
      : type = _SegType.math,
        imageUri = null,
        imageAlt = null;
  const _Segment.image({required this.imageUri, this.imageAlt})
      : text = '',
        type = _SegType.image;
}

final _imageLineRe = RegExp(r'^[ \t]*!\[([^\]]*)\]\(([^)]+)\)[ \t]*$');

/// Parse content line-by-line into segments, respecting fenced code blocks.
/// Block math ($$ ... $$) and standalone images are extracted; rest is markdown.
List<_Segment> _parseSegments(String content) {
  final lines = content.split('\n');
  final segments = <_Segment>[];
  final buf = StringBuffer();
  bool inCode = false;
  bool inMath = false;
  final mathBuf = StringBuffer();

  void flushMarkdown() {
    final text = buf.toString();
    buf.clear();
    if (text.trim().isNotEmpty) {
      segments.add(_Segment.markdown(text));
    }
  }

  for (final line in lines) {
    // Track fenced code blocks so we don't extract images/math inside them
    if (line.trimLeft().startsWith('```') && !inMath) {
      inCode = !inCode;
      buf.writeln(line);
      continue;
    }

    if (inCode) {
      buf.writeln(line);
      continue;
    }

    // Block math: $$ on its own line
    if (line.trim() == r'$$') {
      if (!inMath) {
        flushMarkdown();
        inMath = true;
      } else {
        inMath = false;
        segments.add(_Segment.math(mathBuf.toString().trim()));
        mathBuf.clear();
      }
      continue;
    }

    if (inMath) {
      mathBuf.writeln(line);
      continue;
    }

    // Standalone image line
    final imgMatch = _imageLineRe.firstMatch(line);
    if (imgMatch != null) {
      flushMarkdown();
      segments.add(_Segment.image(
        imageAlt: imgMatch.group(1),
        imageUri: imgMatch.group(2),
      ));
      continue;
    }

    // Regular markdown line
    buf.writeln(line);
  }

  flushMarkdown();
  if (segments.isEmpty) {
    segments.add(_Segment.markdown(content));
  }
  return segments;
}

class _MathBlock extends StatelessWidget {
  final String tex;
  final ThemeData theme;

  const _MathBlock({required this.tex, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            tex,
            textStyle: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
            onErrorFallback: (err) => Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tex,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline math: $...$  (parsed as markdown inline syntax)
// ---------------------------------------------------------------------------

class _MathInlineSyntax extends md.InlineSyntax {
  // Match $...$ but not $$ — content must not contain $ or newlines
  _MathInlineSyntax() : super(r'(?<!\$)\$(?!\$)([^\$\n]+?)(?<!\$)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!));
    return true;
  }
}

class _MathInlineBuilder extends MarkdownElementBuilder {
  final ThemeData theme;
  _MathInlineBuilder(this.theme);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Math.tex(
      element.textContent,
      textStyle: TextStyle(
        fontSize: (parentStyle?.fontSize ?? 14),
        color: theme.colorScheme.onSurface,
      ),
      onErrorFallback: (err) => Text(
        '\$${element.textContent}\$',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Code block builder — renders mermaid via WebView, falls back for others
// ---------------------------------------------------------------------------

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final ThemeData theme;

  _CodeBlockBuilder(this.theme);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final className = element.attributes['class'] ?? '';
    if (className.contains('mermaid')) {
      return MermaidDiagram(
        source: element.textContent.trim(),
        brightness: theme.brightness,
      );
    }
    return null;
  }
}
