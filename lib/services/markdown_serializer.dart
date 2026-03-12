import '../models/outline_document.dart';
import '../models/outline_node.dart';

class MarkdownSerializer {
  /// Serialize an OutlineDocument back to a markdown string.
  String serialize(OutlineDocument doc) {
    final buffer = StringBuffer();

    // Write front-matter if we have columns
    if (doc.columns.isNotEmpty) {
      buffer.writeln('---');
      buffer.writeln('title: "${doc.title}"');
      buffer.write('columns: [');
      buffer.write(doc.columns.map((c) => c.name).join(', '));
      buffer.writeln(']');
      buffer.writeln('---');
      buffer.writeln();
    }

    // Write nodes
    _writeNodes(buffer, doc.nodes, doc, isTopLevel: true);

    return '${buffer.toString().trimRight()}\n';
  }

  void _writeNodes(
    StringBuffer buffer,
    List<OutlineNode> nodes,
    OutlineDocument doc, {
    bool isTopLevel = false,
  }) {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];

      if (node.isHeading) {
        _writeHeadingNode(buffer, node, doc);
      } else {
        _writeBodyNode(buffer, node, doc);
      }

      // Write children
      if (node.children.isNotEmpty) {
        _writeNodes(buffer, node.children, doc);
      }

      // Add blank line between sibling sections
      if (i < nodes.length - 1) {
        buffer.writeln();
      }
    }
  }

  void _writeHeadingNode(
    StringBuffer buffer,
    OutlineNode node,
    OutlineDocument doc,
  ) {
    final content = node.content.trimRight();
    if (content.isEmpty) return;

    final lines = content.split('\n');
    var firstLine = lines.first;

    // If the first line already has # prefix, use it as-is but handle columns
    if (doc.hasColumns && node.columnValues.isNotEmpty) {
      // Strip existing column values from the line if any, then re-add
      final colValues =
          doc.columns.map((c) => node.columnValues[c.name] ?? '').join(' | ');
      // Remove any trailing pipe values from the first line
      final cleanFirst = firstLine.replaceFirst(RegExp(r'\s*\|.*$'), '');
      buffer.writeln('$cleanFirst | $colValues');
    } else {
      buffer.writeln(firstLine);
    }

    // Write remaining lines of the heading cell (body text in same cell)
    for (var i = 1; i < lines.length; i++) {
      buffer.writeln(lines[i]);
    }
  }

  void _writeBodyNode(
    StringBuffer buffer,
    OutlineNode node,
    OutlineDocument doc,
  ) {
    final content = node.content.trimRight();
    if (content.isEmpty) return;

    if (node.isCheckbox) {
      final lines = content.split('\n');
      for (var j = 0; j < lines.length; j++) {
        if (j == 0) {
          var line = lines[j];
          // Ensure checkbox format on first line if not already present
          if (!line.contains(RegExp(r'\[[ x]\]'))) {
            line = '- [${node.isChecked ? 'x' : ' '}] $line';
          }
          buffer.writeln(line);
        } else {
          buffer.writeln(lines[j]);
        }
      }
    } else {
      buffer.writeln(content);
    }
  }
}
