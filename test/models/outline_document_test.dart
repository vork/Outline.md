import 'package:flutter_test/flutter_test.dart';
import 'package:outline_md/models/column_def.dart';
import 'package:outline_md/models/outline_document.dart';
import 'package:outline_md/models/outline_node.dart';

void main() {
  group('OutlineDocument', () {
    test('has sensible defaults', () {
      const doc = OutlineDocument();
      expect(doc.title, 'Untitled');
      expect(doc.columns, isEmpty);
      expect(doc.nodes, isEmpty);
      expect(doc.filePath, isNull);
      expect(doc.isDirty, false);
    });

    test('hasColumns returns true when columns exist', () {
      final doc = OutlineDocument(
        columns: [ColumnDef(name: 'Status')],
      );
      expect(doc.hasColumns, true);
    });

    test('hasColumns returns false when no columns', () {
      const doc = OutlineDocument();
      expect(doc.hasColumns, false);
    });

    group('copyWith', () {
      test('updates title', () {
        const doc = OutlineDocument(title: 'Old');
        final copy = doc.copyWith(title: 'New');
        expect(copy.title, 'New');
      });

      test('updates isDirty', () {
        const doc = OutlineDocument();
        final dirty = doc.copyWith(isDirty: true);
        expect(dirty.isDirty, true);
      });

      test('updates filePath', () {
        const doc = OutlineDocument();
        final withPath = doc.copyWith(filePath: '/test.md');
        expect(withPath.filePath, '/test.md');
      });

      test('updates nodes', () {
        const doc = OutlineDocument();
        final withNodes = doc.copyWith(
          nodes: [OutlineNode(id: '1', content: 'Hello')],
        );
        expect(withNodes.nodes.length, 1);
      });

      test('preserves unchanged fields', () {
        final doc = OutlineDocument(
          title: 'Title',
          columns: [ColumnDef(name: 'Col')],
          nodes: [OutlineNode(id: '1')],
          filePath: '/path.md',
          isDirty: true,
        );
        final copy = doc.copyWith();
        expect(copy.title, doc.title);
        expect(copy.columns.length, doc.columns.length);
        expect(copy.nodes.length, doc.nodes.length);
        expect(copy.filePath, doc.filePath);
        expect(copy.isDirty, doc.isDirty);
      });
    });
  });
}
