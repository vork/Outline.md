import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import '../models/outline_document.dart';
import '../models/outline_node.dart';

class LatexExporter {
  /// Export the document to a LaTeX file with images.
  /// Returns the path to the generated .tex file.
  Future<String> export(OutlineDocument doc, String outputDir) async {
    final baseName = doc.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final exportDir = Directory(p.join(outputDir, '${baseName}_export'));
    await exportDir.create(recursive: true);

    final imagesDir = Directory(p.join(exportDir.path, 'images'));
    await imagesDir.create(recursive: true);

    await _copyImages(doc.nodes, doc.filePath, imagesDir.path);

    final tex = generateTex(doc);

    final texPath = p.join(exportDir.path, '$baseName.tex');
    await File(texPath).writeAsString(tex);

    return texPath;
  }

  @visibleForTesting
  String generateTex(OutlineDocument doc) {
    final buf = StringBuffer();

    buf.writeln(r'\documentclass[11pt,a4paper]{article}');
    buf.writeln();
    buf.writeln(r'\usepackage[utf8]{inputenc}');
    buf.writeln(r'\usepackage[T1]{fontenc}');
    buf.writeln(r'\usepackage{lmodern}');
    buf.writeln(r'\usepackage{graphicx}');
    buf.writeln(r'\usepackage{hyperref}');
    buf.writeln(r'\usepackage{enumitem}');
    buf.writeln(r'\usepackage{listings}');
    buf.writeln(r'\usepackage{xcolor}');
    buf.writeln(r'\usepackage{booktabs}');
    buf.writeln(r'\usepackage{amssymb}');
    buf.writeln(r'\usepackage{amsmath}');
    buf.writeln(r'\usepackage[margin=1in]{geometry}');
    buf.writeln();
    buf.writeln(r'% Checkbox commands');
    buf.writeln(r'\newcommand{\unchecked}{$\square$}');
    buf.writeln(r'\newcommand{\checked}{$\boxtimes$}');
    buf.writeln();
    buf.writeln(r'% Code listing style');
    buf.writeln(r'\lstset{');
    buf.writeln(r'  basicstyle=\ttfamily\small,');
    buf.writeln(r'  breaklines=true,');
    buf.writeln(r'  frame=single,');
    buf.writeln(r'  backgroundcolor=\color{gray!10},');
    buf.writeln(r'  numbers=left,');
    buf.writeln(r'  numberstyle=\tiny\color{gray},');
    buf.writeln(r'}');
    buf.writeln();
    buf.writeln(r'\title{' + _escapeLatex(doc.title) + r'}');
    buf.writeln(r'\date{\today}');
    buf.writeln();
    buf.writeln(r'\begin{document}');
    buf.writeln(r'\maketitle');
    buf.writeln(r'\tableofcontents');
    buf.writeln(r'\newpage');
    buf.writeln();

    // Write column headers as a table if columns exist
    if (doc.hasColumns) {
      buf.writeln(r'% Column definitions: ' + doc.columns.map((c) => c.name).join(', '));
      buf.writeln();
    }

    _writeNodes(buf, doc.nodes, doc);

    buf.writeln();
    buf.writeln(r'\end{document}');

    return buf.toString();
  }

  void _writeNodes(
    StringBuffer buf,
    List<OutlineNode> nodes,
    OutlineDocument doc,
  ) {
    for (final node in nodes) {
      if (node.isHeading) {
        _writeHeading(buf, node, doc);
      } else {
        _writeBody(buf, node, doc);
      }

      if (node.children.isNotEmpty) {
        _writeNodes(buf, node.children, doc);
      }
    }
  }

  void _writeHeading(StringBuffer buf, OutlineNode node, OutlineDocument doc) {
    final title = _escapeLatex(node.displayTitle);
    final prefix = node.isCheckbox
        ? (node.isChecked ? r'\checked{} ' : r'\unchecked{} ')
        : '';

    final sectionCmd = switch (node.headingLevel) {
      1 => r'\section',
      2 => r'\subsection',
      3 => r'\subsubsection',
      4 => r'\paragraph',
      5 => r'\subparagraph',
      _ => r'\subparagraph',
    };

    buf.writeln('$sectionCmd{$prefix$title}');

    // Write column values as a table row if applicable
    if (doc.hasColumns && node.columnValues.isNotEmpty) {
      buf.writeln();
      buf.writeln('\\begin{tabular}{${'l' * doc.columns.length}}');
      buf.writeln(r'\toprule');
      buf.writeln('${doc.columns.map((c) => '\\textbf{${_escapeLatex(c.name)}}').join(' & ')} \\\\');
      buf.writeln(r'\midrule');
      buf.writeln('${doc.columns.map((c) => _escapeLatex(node.columnValues[c.name] ?? '')).join(' & ')} \\\\');
      buf.writeln(r'\bottomrule');
      buf.writeln(r'\end{tabular}');
      buf.writeln();
    }

    buf.writeln();

    // Write body text that follows the heading line (multi-line heading cells)
    final lines = node.content.trimRight().split('\n');
    if (lines.length > 1) {
      // Create a temporary body node with the remaining lines
      final bodyContent = lines.sublist(1).join('\n').trimLeft();
      if (bodyContent.trim().isNotEmpty) {
        final bodyNode = OutlineNode(
          id: '',
          content: bodyContent,
        );
        _writeBody(buf, bodyNode, doc);
      }
    }
  }

  void _writeBody(StringBuffer buf, OutlineNode node, OutlineDocument doc) {
    final content = node.content.trim();
    if (content.isEmpty) return;

    final lines = content.split('\n');
    var inList = false;
    var inCodeBlock = false;
    var inMathBlock = false;
    String? codeLanguage;

    for (final line in lines) {
      // Code blocks
      if (line.trimLeft().startsWith('```') && !inMathBlock) {
        if (!inCodeBlock) {
          inCodeBlock = true;
          codeLanguage = line.trimLeft().substring(3).trim();
          if (codeLanguage == 'mermaid') {
            buf.writeln(r'% Mermaid diagram (render separately and include as image)');
            buf.writeln(r'\begin{lstlisting}[language={},title=Mermaid Diagram]');
          } else {
            final lang = codeLanguage.isNotEmpty ? '[language=$codeLanguage]' : '';
            buf.writeln(r'\begin{lstlisting}' + lang);
          }
        } else {
          inCodeBlock = false;
          buf.writeln(r'\end{lstlisting}');
          codeLanguage = null;
        }
        continue;
      }

      if (inCodeBlock) {
        buf.writeln(line);
        continue;
      }

      // Block math: $$ ... $$
      if (line.trim() == r'$$' && !inCodeBlock) {
        if (!inMathBlock) {
          if (inList) {
            buf.writeln(r'\end{itemize}');
            inList = false;
          }
          inMathBlock = true;
          buf.writeln(r'\[');
        } else {
          inMathBlock = false;
          buf.writeln(r'\]');
        }
        continue;
      }

      if (inMathBlock) {
        buf.writeln(line);
        continue;
      }

      // Images
      final imgMatch = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').firstMatch(line);
      if (imgMatch != null) {
        final alt = imgMatch.group(1) ?? '';
        var path = imgMatch.group(2)!;
        if (path.contains('/')) {
          path = path.split('/').last;
        }
        buf.writeln(r'\begin{figure}[htbp]');
        buf.writeln(r'  \centering');
        buf.writeln('  \\includegraphics[width=0.8\\textwidth]{images/$path}');
        if (alt.isNotEmpty) {
          buf.writeln('  \\caption{${_escapeLatex(alt)}}');
        }
        buf.writeln(r'\end{figure}');
        continue;
      }

      // Bullet lists
      final bulletMatch = RegExp(r'^(\s*)[*-]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        if (!inList) {
          buf.writeln(r'\begin{itemize}');
          inList = true;
        }
        var text = bulletMatch.group(2)!;

        final cbMatch = RegExp(r'^\[( |x)\]\s*(.*)$').firstMatch(text);
        if (cbMatch != null) {
          final checked = cbMatch.group(1) == 'x';
          text =
              '${checked ? r'\checked' : r'\unchecked'} ${_escapeLatexPreserveMath(cbMatch.group(2)!)}';
          buf.writeln('  \\item $text');
        } else {
          buf.writeln('  \\item ${_escapeLatexPreserveMath(text)}');
        }
        continue;
      } else if (inList) {
        buf.writeln(r'\end{itemize}');
        inList = false;
      }

      // Regular text: escape while preserving inline math, then handle
      // bold, italic, and inline code in non-math segments.
      var processed = _escapeLatexPreserveMath(line);
      processed = processed.replaceAllMapped(
        RegExp(r'\*\*(.+?)\*\*'),
        (m) => '\\textbf{${m.group(1)!}}',
      );
      processed = processed.replaceAllMapped(
        RegExp(r'\*(.+?)\*'),
        (m) => '\\textit{${m.group(1)!}}',
      );
      processed = processed.replaceAllMapped(
        RegExp(r'`(.+?)`'),
        (m) => '\\texttt{${m.group(1)!}}',
      );

      if (processed.trim().isNotEmpty) {
        buf.writeln(processed);
      } else {
        buf.writeln();
      }
    }

    if (inList) {
      buf.writeln(r'\end{itemize}');
    }
    buf.writeln();
  }

  /// Escape special LaTeX characters but preserve inline math ($...$).
  String _escapeLatexPreserveMath(String text) {
    final buf = StringBuffer();
    final regex = RegExp(r'\$([^\$\n]+?)\$');
    var last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        buf.write(_escapeLatex(text.substring(last, match.start)));
      }
      buf.write('\$${match.group(1)}\$');
      last = match.end;
    }
    if (last < text.length) {
      buf.write(_escapeLatex(text.substring(last)));
    }
    return buf.toString();
  }

  String _escapeLatex(String text) {
    return text
        .replaceAll(r'\', r'\textbackslash{}')
        .replaceAll('&', r'\&')
        .replaceAll('%', r'\%')
        .replaceAll(r'$', r'\$')
        .replaceAll('#', r'\#')
        .replaceAll('_', r'\_')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('~', r'\textasciitilde{}')
        .replaceAll('^', r'\textasciicircum{}');
  }

  Future<void> _copyImages(
    List<OutlineNode> nodes,
    String? sourceFilePath,
    String targetImagesDir,
  ) async {
    final sourceDir =
        sourceFilePath != null ? p.dirname(sourceFilePath) : null;

    for (final node in nodes) {
      final imgMatches = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)')
          .allMatches(node.content);

      for (final match in imgMatches) {
        final imagePath = match.group(2)!;

        if (imagePath.startsWith('http://') ||
            imagePath.startsWith('https://')) {
          await _downloadImage(imagePath, targetImagesDir);
        } else if (sourceDir != null) {
          final sourcePath = p.isAbsolute(imagePath)
              ? imagePath
              : p.join(sourceDir, imagePath);
          final sourceFile = File(sourcePath);
          if (await sourceFile.exists()) {
            final targetPath =
                p.join(targetImagesDir, p.basename(imagePath));
            await sourceFile.copy(targetPath);
          }
        }
      }

      if (node.children.isNotEmpty) {
        await _copyImages(node.children, sourceFilePath, targetImagesDir);
      }
    }
  }

  Future<void> _downloadImage(String url, String targetDir) async {
    try {
      final uri = Uri.parse(url);
      var filename = p.basename(uri.path);
      if (filename.isEmpty || !filename.contains('.')) {
        filename = 'image_${url.hashCode.abs()}.png';
      }
      final targetPath = p.join(targetDir, filename);
      if (await File(targetPath).exists()) return;

      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await response.fold<List<int>>(
              <int>[], (prev, chunk) => prev..addAll(chunk));
          await File(targetPath).writeAsBytes(bytes);
        }
      } finally {
        client.close();
      }
    } catch (_) {
      // Network unavailable or download failed — skip gracefully
    }
  }
}
