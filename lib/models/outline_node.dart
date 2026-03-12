import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class OutlineNode {
  final String id;
  final String content;
  final int headingLevel; // 0 = body/bullet, 1-6 = heading
  final bool isCollapsed;
  final bool isCheckbox;
  final bool isChecked;
  final Map<String, String> columnValues;
  final List<OutlineNode> children;

  const OutlineNode({
    required this.id,
    this.content = '',
    this.headingLevel = 0,
    this.isCollapsed = false,
    this.isCheckbox = false,
    this.isChecked = false,
    this.columnValues = const {},
    this.children = const [],
  });

  factory OutlineNode.create({
    String? content,
    int headingLevel = 0,
    bool isCheckbox = false,
  }) {
    return OutlineNode(
      id: _uuid.v4(),
      content: content ?? '',
      headingLevel: headingLevel,
      isCheckbox: isCheckbox,
    );
  }

  OutlineNode copyWith({
    String? id,
    String? content,
    int? headingLevel,
    bool? isCollapsed,
    bool? isCheckbox,
    bool? isChecked,
    Map<String, String>? columnValues,
    List<OutlineNode>? children,
  }) {
    return OutlineNode(
      id: id ?? this.id,
      content: content ?? this.content,
      headingLevel: headingLevel ?? this.headingLevel,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      isCheckbox: isCheckbox ?? this.isCheckbox,
      isChecked: isChecked ?? this.isChecked,
      columnValues: columnValues ?? this.columnValues,
      children: children ?? this.children,
    );
  }

  bool get isHeading => headingLevel > 0;
  bool get hasChildren => children.isNotEmpty;

  /// Whether the content has multiple lines (body text below the first line).
  bool get hasBody {
    final trimmed = content.trimRight();
    if (trimmed.isEmpty) return false;
    final lines = trimmed.split('\n');
    // For headings, body starts after the heading line
    // For body nodes, any multi-line content counts
    return lines.length > 1;
  }

  /// Whether this node can be collapsed (has children or body text).
  bool get isCollapsible => hasChildren || hasBody;

  String get displayTitle {
    if (content.isEmpty) return 'Untitled';
    final firstLine = content.split('\n').first;
    // Strip markdown heading prefix
    final stripped = firstLine.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    // Strip checkbox prefix
    return stripped.replaceFirst(RegExp(r'^-\s*\[[ x]\]\s*'), '').trim();
  }
}
