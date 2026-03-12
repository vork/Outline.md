import 'package:flutter_test/flutter_test.dart';
import 'package:outline_md/models/outline_node.dart';

void main() {
  group('OutlineNode', () {
    group('factory create', () {
      test('generates unique IDs', () {
        final a = OutlineNode.create();
        final b = OutlineNode.create();
        expect(a.id, isNot(b.id));
      });

      test('sets defaults correctly', () {
        final node = OutlineNode.create();
        expect(node.content, '');
        expect(node.headingLevel, 0);
        expect(node.isCollapsed, false);
        expect(node.isCheckbox, false);
        expect(node.isChecked, false);
        expect(node.columnValues, isEmpty);
        expect(node.children, isEmpty);
      });

      test('accepts optional parameters', () {
        final node = OutlineNode.create(
          content: 'Test',
          headingLevel: 2,
          isCheckbox: true,
        );
        expect(node.content, 'Test');
        expect(node.headingLevel, 2);
        expect(node.isCheckbox, true);
      });
    });

    group('copyWith', () {
      test('copies all fields', () {
        final original = OutlineNode(
          id: 'abc',
          content: 'Hello',
          headingLevel: 1,
          isCollapsed: true,
          isCheckbox: true,
          isChecked: true,
          columnValues: {'A': '1'},
          children: [OutlineNode(id: 'child', content: 'C')],
        );
        final copy = original.copyWith(content: 'Updated');
        expect(copy.id, 'abc');
        expect(copy.content, 'Updated');
        expect(copy.headingLevel, 1);
        expect(copy.isCollapsed, true);
        expect(copy.isCheckbox, true);
        expect(copy.isChecked, true);
        expect(copy.columnValues, {'A': '1'});
        expect(copy.children.length, 1);
      });

      test('preserves unchanged fields', () {
        final node = OutlineNode(id: 'x', content: 'Test', headingLevel: 3);
        final copy = node.copyWith();
        expect(copy.id, node.id);
        expect(copy.content, node.content);
        expect(copy.headingLevel, node.headingLevel);
      });
    });

    group('computed properties', () {
      test('isHeading returns true for levels 1-6', () {
        for (var i = 1; i <= 6; i++) {
          expect(OutlineNode(id: '$i', headingLevel: i).isHeading, true);
        }
      });

      test('isHeading returns false for level 0', () {
        expect(const OutlineNode(id: '0', headingLevel: 0).isHeading, false);
      });

      test('hasChildren is true when children exist', () {
        final node = OutlineNode(
          id: '1',
          children: [const OutlineNode(id: '2')],
        );
        expect(node.hasChildren, true);
      });

      test('hasChildren is false when no children', () {
        expect(const OutlineNode(id: '1').hasChildren, false);
      });

      test('hasBody is true for multi-line content', () {
        final node = OutlineNode(id: '1', content: 'Line 1\nLine 2');
        expect(node.hasBody, true);
      });

      test('hasBody is false for single-line content', () {
        final node = OutlineNode(id: '1', content: 'Single line');
        expect(node.hasBody, false);
      });

      test('hasBody is false for empty content', () {
        expect(const OutlineNode(id: '1', content: '').hasBody, false);
      });

      test('isCollapsible with children', () {
        final node = OutlineNode(
          id: '1',
          children: [const OutlineNode(id: '2')],
        );
        expect(node.isCollapsible, true);
      });

      test('isCollapsible with body', () {
        final node = OutlineNode(id: '1', content: 'Line 1\nLine 2');
        expect(node.isCollapsible, true);
      });

      test('not collapsible when single line and no children', () {
        final node = OutlineNode(id: '1', content: 'Single');
        expect(node.isCollapsible, false);
      });
    });

    group('displayTitle', () {
      test('strips heading prefix', () {
        final node = OutlineNode(id: '1', content: '## My Title');
        expect(node.displayTitle, 'My Title');
      });

      test('strips checkbox prefix', () {
        final node = OutlineNode(id: '1', content: '- [x] Task');
        expect(node.displayTitle, 'Task');
      });

      test('returns Untitled for empty content', () {
        expect(const OutlineNode(id: '1', content: '').displayTitle, 'Untitled');
      });

      test('uses first line only', () {
        final node = OutlineNode(id: '1', content: '# Title\nBody text');
        expect(node.displayTitle, 'Title');
      });

      test('handles plain text', () {
        final node = OutlineNode(id: '1', content: 'Plain text');
        expect(node.displayTitle, 'Plain text');
      });
    });
  });
}
