import 'package:flutter_test/flutter_test.dart';
import 'package:outline_md/models/column_def.dart';
import 'package:outline_md/models/outline_document.dart';
import 'package:outline_md/models/outline_node.dart';
import 'package:outline_md/services/markdown_serializer.dart';

void main() {
  late MarkdownSerializer serializer;

  setUp(() {
    serializer = MarkdownSerializer();
  });

  group('MarkdownSerializer', () {
    group('heading serialization', () {
      test('serializes single heading node', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(id: '1', content: '# Hello', headingLevel: 1),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md.trim(), '# Hello');
      });

      test('serializes nested headings', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(
              id: '1',
              content: '# Parent',
              headingLevel: 1,
              children: [
                OutlineNode(id: '2', content: '## Child', headingLevel: 2),
              ],
            ),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md, contains('# Parent'));
        expect(md, contains('## Child'));
      });

      test('separates sibling nodes with blank lines', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(id: '1', content: '# First', headingLevel: 1),
            OutlineNode(id: '2', content: '# Second', headingLevel: 1),
          ],
        );
        final md = serializer.serialize(doc);
        final lines = md.split('\n');
        final firstIdx = lines.indexOf('# First');
        final secondIdx = lines.indexOf('# Second');
        expect(secondIdx - firstIdx, greaterThan(1));
      });

      test('serializes heading with body text', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(
              id: '1',
              content: '# Title\nBody text here.',
              headingLevel: 1,
            ),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md, contains('# Title'));
        expect(md, contains('Body text here.'));
      });
    });

    group('body node serialization', () {
      test('serializes plain body text', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(id: '1', content: 'Plain text', headingLevel: 0),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md.trim(), 'Plain text');
      });

      test('serializes unchecked checkbox body node', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(
              id: '1',
              content: 'A task',
              headingLevel: 0,
              isCheckbox: true,
              isChecked: false,
            ),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md.trim(), '- [ ] A task');
      });

      test('serializes checked checkbox body node', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(
              id: '1',
              content: 'Done task',
              headingLevel: 0,
              isCheckbox: true,
              isChecked: true,
            ),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md.trim(), '- [x] Done task');
      });

      test('preserves existing checkbox format in content', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(
              id: '1',
              content: '- [x] Already formatted',
              headingLevel: 0,
              isCheckbox: true,
              isChecked: true,
            ),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md.trim(), '- [x] Already formatted');
      });
    });

    group('column serialization', () {
      test('writes front-matter when columns exist', () {
        final doc = OutlineDocument(
          title: 'My Doc',
          columns: [
            ColumnDef(name: 'Status'),
            ColumnDef(name: 'Priority'),
          ],
          nodes: [
            OutlineNode(id: '1', content: '# Task', headingLevel: 1),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md, contains('---'));
        expect(md, contains('title: "My Doc"'));
        expect(md, contains('columns: [Status, Priority]'));
      });

      test('serializes column values in heading lines', () {
        final doc = OutlineDocument(
          columns: [ColumnDef(name: 'Status')],
          nodes: [
            OutlineNode(
              id: '1',
              content: '# Task',
              headingLevel: 1,
              columnValues: {'Status': 'Done'},
            ),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md, contains('# Task | Done'));
      });

      test('skips front-matter when no columns', () {
        final doc = OutlineDocument(
          title: 'No Columns',
          nodes: [
            OutlineNode(id: '1', content: '# Hello', headingLevel: 1),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md, isNot(contains('---')));
      });
    });

    group('empty content handling', () {
      test('skips nodes with empty content', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(id: '1', content: '', headingLevel: 1),
            OutlineNode(id: '2', content: '# Real', headingLevel: 1),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md, isNot(contains('#  ')));
        expect(md, contains('# Real'));
      });

      test('output ends with newline', () {
        final doc = OutlineDocument(
          nodes: [
            OutlineNode(id: '1', content: '# Hello', headingLevel: 1),
          ],
        );
        final md = serializer.serialize(doc);
        expect(md.endsWith('\n'), true);
      });
    });
  });
}
