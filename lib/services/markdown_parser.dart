import '../models/column_def.dart';
import '../models/outline_document.dart';
import '../models/outline_node.dart';
import '../utils/tree_utils.dart';

class MarkdownParser {
  /// Parse a markdown string into an OutlineDocument.
  OutlineDocument parse(String markdown, {String? filePath}) {
    final lines = markdown.split('\n');
    final columns = <ColumnDef>[];
    var title = 'Untitled';
    var contentStart = 0;

    // Parse YAML front-matter
    if (lines.isNotEmpty && lines[0].trim() == '---') {
      final endIdx = lines.indexWhere((l) => l.trim() == '---', 1);
      if (endIdx > 0) {
        contentStart = endIdx + 1;
        for (var i = 1; i < endIdx; i++) {
          final line = lines[i].trim();
          if (line.startsWith('title:')) {
            title = line.substring(6).trim().replaceAll('"', '').replaceAll("'", '');
          } else if (line.startsWith('columns:')) {
            // Parse inline columns: [Col1, Col2, Col3]
            final match = RegExp(r'\[(.*)\]').firstMatch(line);
            if (match != null) {
              columns.addAll(
                match.group(1)!.split(',').map(
                      (c) => ColumnDef(name: c.trim()),
                    ),
              );
            }
          } else if (line.startsWith('- ') && columns.isNotEmpty) {
            // YAML list-style columns
            columns.add(ColumnDef(name: line.substring(2).trim()));
          }
        }
      }
    }

    // Parse content lines into flat nodes
    final flatNodes = <OutlineNode>[];
    final contentLines = lines.sublist(contentStart);
    final buffer = StringBuffer();
    int currentLevel = 0;
    bool isCheckbox = false;
    bool isChecked = false;
    Map<String, String> currentColumnValues = {};
    bool hasStartedNode = false;

    void flushBuffer() {
      if (!hasStartedNode) return;
      final content = buffer.toString().trimRight();
      if (content.isNotEmpty) {
        flatNodes.add(OutlineNode.create(
          content: content,
          headingLevel: currentLevel,
          isCheckbox: isCheckbox,
        ).copyWith(
          isChecked: isChecked,
          columnValues: currentColumnValues.isNotEmpty
              ? Map<String, String>.from(currentColumnValues)
              : const {},
        ));
      }
      buffer.clear();
      currentLevel = 0;
      isCheckbox = false;
      isChecked = false;
      currentColumnValues = {};
      hasStartedNode = false;
    }

    var inCodeBlock = false;

    for (final line in contentLines) {
      // Track fenced code blocks so their content isn't parsed as headings
      if (line.trimLeft().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        if (!hasStartedNode) {
          hasStartedNode = true;
          currentLevel = 0;
        }
        buffer.writeln(line);
        continue;
      }

      if (inCodeBlock) {
        if (!hasStartedNode) {
          hasStartedNode = true;
          currentLevel = 0;
        }
        buffer.writeln(line);
        continue;
      }

      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);

      if (headingMatch != null) {
        flushBuffer();
        hasStartedNode = true;
        currentLevel = headingMatch.group(1)!.length;
        var headingText = headingMatch.group(2)!;

        // Check for column values: # Title | val1 | val2
        if (columns.isNotEmpty && headingText.contains('|')) {
          final parts = headingText.split('|').map((p) => p.trim()).toList();
          headingText = parts.first;
          for (var i = 1; i < parts.length && i < columns.length + 1; i++) {
            currentColumnValues[columns[i - 1].name] = parts[i];
          }
        }

        // Check for checkbox in heading
        final cbMatch = RegExp(r'^\[( |x)\]\s*(.*)$').firstMatch(headingText);
        if (cbMatch != null) {
          isCheckbox = true;
          isChecked = cbMatch.group(1) == 'x';
          headingText = cbMatch.group(2)!;
        }

        buffer.writeln('${'#' * currentLevel} $headingText');
      } else if (line.trim().isEmpty && !hasStartedNode) {
        continue; // Skip leading blank lines
      } else {
        if (!hasStartedNode) {
          hasStartedNode = true;
          currentLevel = 0;
        }

        // Check for checkbox bullet
        final cbBullet = RegExp(r'^(\s*)-\s*\[( |x)\]\s*(.*)$').firstMatch(line);
        if (cbBullet != null && buffer.isEmpty) {
          isCheckbox = true;
          isChecked = cbBullet.group(2) == 'x';
        }

        buffer.writeln(line);
      }
    }
    flushBuffer();

    // Build tree from flat heading hierarchy
    if (title == 'Untitled' && flatNodes.isNotEmpty) {
      title = flatNodes.first.displayTitle;
    }

    final tree = buildTreeFromFlat(flatNodes);

    return OutlineDocument(
      title: title,
      columns: columns,
      nodes: tree,
      filePath: filePath,
    );
  }
}
