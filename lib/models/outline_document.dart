import 'column_def.dart';
import 'outline_node.dart';

class OutlineDocument {
  final String title;
  final List<ColumnDef> columns;
  final List<OutlineNode> nodes;
  final String? filePath;
  final bool isDirty;

  const OutlineDocument({
    this.title = 'Untitled',
    this.columns = const [],
    this.nodes = const [],
    this.filePath,
    this.isDirty = false,
  });

  OutlineDocument copyWith({
    String? title,
    List<ColumnDef>? columns,
    List<OutlineNode>? nodes,
    String? filePath,
    bool? isDirty,
  }) {
    return OutlineDocument(
      title: title ?? this.title,
      columns: columns ?? this.columns,
      nodes: nodes ?? this.nodes,
      filePath: filePath ?? this.filePath,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  bool get hasColumns => columns.isNotEmpty;
}
