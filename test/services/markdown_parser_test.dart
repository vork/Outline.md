import 'package:flutter_test/flutter_test.dart';
import 'package:outline_md/services/markdown_parser.dart';

void main() {
  late MarkdownParser parser;

  setUp(() {
    parser = MarkdownParser();
  });

  group('MarkdownParser', () {
    group('front-matter parsing', () {
      test('parses title from YAML front-matter', () {
        const md = '---\ntitle: "My Document"\n---\n\n# Heading';
        final doc = parser.parse(md);
        expect(doc.title, 'My Document');
      });

      test('parses title without quotes', () {
        const md = '---\ntitle: My Document\n---\n\n# Heading';
        final doc = parser.parse(md);
        expect(doc.title, 'My Document');
      });

      test('parses inline columns from front-matter', () {
        const md = '---\ntitle: "Test"\ncolumns: [Status, Priority]\n---\n\n# Heading';
        final doc = parser.parse(md);
        expect(doc.columns.length, 2);
        expect(doc.columns[0].name, 'Status');
        expect(doc.columns[1].name, 'Priority');
      });

      test('parses list-style columns from front-matter', () {
        const md = '---\ntitle: "Test"\ncolumns: [Status]\n- Priority\n---\n\n# Heading';
        final doc = parser.parse(md);
        expect(doc.columns.length, 2);
        expect(doc.columns[0].name, 'Status');
        expect(doc.columns[1].name, 'Priority');
      });

      test('uses first heading as title when no front-matter title', () {
        const md = '# My Heading\n\nSome text';
        final doc = parser.parse(md);
        expect(doc.title, 'My Heading');
      });

      test('falls back to first node content as title when no front-matter', () {
        const md = 'Just some body text.';
        final doc = parser.parse(md);
        expect(doc.title, 'Just some body text.');
      });

      test('defaults to Untitled for empty document', () {
        final doc = parser.parse('');
        expect(doc.title, 'Untitled');
      });
    });

    group('heading parsing', () {
      test('parses single heading', () {
        const md = '# Hello';
        final doc = parser.parse(md);
        expect(doc.nodes.length, 1);
        expect(doc.nodes[0].headingLevel, 1);
        expect(doc.nodes[0].displayTitle, 'Hello');
      });

      test('parses multiple heading levels', () {
        const md = '# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6';
        final doc = parser.parse(md);
        final flat = _flattenNodes(doc.nodes);
        expect(flat.length, 6);
        for (var i = 0; i < 6; i++) {
          expect(flat[i].headingLevel, i + 1);
        }
      });

      test('nests lower headings under higher ones', () {
        const md = '# Parent\n## Child 1\n## Child 2';
        final doc = parser.parse(md);
        expect(doc.nodes.length, 1);
        expect(doc.nodes[0].children.length, 2);
        expect(doc.nodes[0].children[0].displayTitle, 'Child 1');
        expect(doc.nodes[0].children[1].displayTitle, 'Child 2');
      });

      test('handles deep nesting', () {
        const md = '# L1\n## L2\n### L3\n#### L4';
        final doc = parser.parse(md);
        expect(doc.nodes.length, 1);
        expect(doc.nodes[0].children.length, 1);
        expect(doc.nodes[0].children[0].children.length, 1);
        expect(doc.nodes[0].children[0].children[0].children.length, 1);
      });

      test('handles sibling headings at same level', () {
        const md = '## A\n## B\n## C';
        final doc = parser.parse(md);
        expect(doc.nodes.length, 3);
      });
    });

    group('body text parsing', () {
      test('attaches body text to preceding heading', () {
        const md = '# Heading\nBody text here.';
        final doc = parser.parse(md);
        expect(doc.nodes.length, 1);
        expect(doc.nodes[0].content, contains('Body text here.'));
      });

      test('handles body text without any heading', () {
        const md = 'Just body text\nwith multiple lines.';
        final doc = parser.parse(md);
        expect(doc.nodes.length, 1);
        expect(doc.nodes[0].headingLevel, 0);
      });

      test('skips leading blank lines', () {
        const md = '\n\n\n# Heading';
        final doc = parser.parse(md);
        expect(doc.nodes.length, 1);
        expect(doc.nodes[0].headingLevel, 1);
      });
    });

    group('checkbox parsing', () {
      test('parses checkbox in heading', () {
        const md = '# [ ] Todo item';
        final doc = parser.parse(md);
        expect(doc.nodes[0].isCheckbox, true);
        expect(doc.nodes[0].isChecked, false);
        expect(doc.nodes[0].displayTitle, 'Todo item');
      });

      test('parses checked checkbox in heading', () {
        const md = '# [x] Done item';
        final doc = parser.parse(md);
        expect(doc.nodes[0].isCheckbox, true);
        expect(doc.nodes[0].isChecked, true);
        expect(doc.nodes[0].displayTitle, 'Done item');
      });

      test('parses standalone checkbox bullet as body node', () {
        const md = '- [ ] A task';
        final doc = parser.parse(md);
        expect(doc.nodes.length, 1);
        expect(doc.nodes[0].isCheckbox, true);
        expect(doc.nodes[0].isChecked, false);
      });

      test('parses standalone checked checkbox bullet', () {
        const md = '- [x] Done task';
        final doc = parser.parse(md);
        expect(doc.nodes.length, 1);
        expect(doc.nodes[0].isCheckbox, true);
        expect(doc.nodes[0].isChecked, true);
      });

      test('checkbox bullet after heading becomes body text in heading node', () {
        const md = '# Heading\n- [ ] A task';
        final doc = parser.parse(md);
        final flat = _flattenNodes(doc.nodes);
        expect(flat.length, 1);
        expect(flat[0].content, contains('- [ ] A task'));
      });
    });

    group('column value parsing', () {
      test('parses column values from heading', () {
        const md = '---\ntitle: "Test"\ncolumns: [Status, Priority]\n---\n\n# Task | Done | High';
        final doc = parser.parse(md);
        expect(doc.nodes[0].columnValues['Status'], 'Done');
        expect(doc.nodes[0].columnValues['Priority'], 'High');
        expect(doc.nodes[0].displayTitle, 'Task');
      });

      test('ignores pipes when no columns defined', () {
        const md = '# Title | with pipe';
        final doc = parser.parse(md);
        expect(doc.nodes[0].columnValues, isEmpty);
        expect(doc.nodes[0].displayTitle, 'Title | with pipe');
      });
    });

    group('round-trip sanity', () {
      test('preserves file path', () {
        const md = '# Hello';
        final doc = parser.parse(md, filePath: '/test/file.md');
        expect(doc.filePath, '/test/file.md');
      });

      test('empty document produces empty nodes', () {
        final doc = parser.parse('');
        expect(doc.nodes, isEmpty);
      });
    });

    group('math expressions', () {
      test('inline math is preserved as part of body content', () {
        const input = r'# Formulas' '\n'
            r'The equation $E = mc^2$ is famous.' '\n';
        final doc = parser.parse(input);
        expect(doc.nodes[0].content, contains(r'$E = mc^2$'));
      });

      test('multiple inline math expressions in one line', () {
        const input = r'# Math' '\n'
            r'Both $\alpha$ and $\beta$ are Greek letters.' '\n';
        final doc = parser.parse(input);
        expect(doc.nodes[0].content, contains(r'$\alpha$'));
        expect(doc.nodes[0].content, contains(r'$\beta$'));
      });

      test('block math delimiters are preserved in body content', () {
        const input =
            '# Calculus\nThe integral:\n\n\$\$\n\\int_0^1 f(x) dx\n\$\$\n';
        final doc = parser.parse(input);
        expect(doc.nodes[0].content, contains('\$\$'));
        expect(doc.nodes[0].content, contains(r'\int_0^1 f(x) dx'));
      });

      test('block math across multiple lines is preserved', () {
        const input = '# Proof\n\$\$\na^2 + b^2 = c^2\n\$\$\n';
        final doc = parser.parse(input);
        expect(doc.nodes[0].content, contains('a^2 + b^2 = c^2'));
      });

      test('inline math with special characters in heading body', () {
        const input = r'# Notes' '\n'
            r'Given $\frac{a}{b} \cdot \sqrt{c}$ then $x_1 + x_2 = S$.'
            '\n';
        final doc = parser.parse(input);
        expect(doc.nodes[0].content, contains(r'$\frac{a}{b} \cdot \sqrt{c}$'));
        expect(doc.nodes[0].content, contains(r'$x_1 + x_2 = S$'));
      });

      test('body-only math content is preserved', () {
        const input = r'$a + b = c$' '\n' r'$d \neq e$' '\n';
        final doc = parser.parse(input);
        expect(doc.nodes[0].content, contains(r'$a + b = c$'));
        expect(doc.nodes[0].content, contains(r'$d \neq e$'));
      });
    });
  });
}

List<_FlatNode> _flattenNodes(List nodes) {
  final result = <_FlatNode>[];
  for (final node in nodes) {
    result.add(_FlatNode(node));
    result.addAll(_flattenNodes(node.children));
  }
  return result;
}

class _FlatNode {
  final dynamic node;
  _FlatNode(this.node);

  int get headingLevel => node.headingLevel;
  bool get isCheckbox => node.isCheckbox;
  bool get isChecked => node.isChecked;
  String get displayTitle => node.displayTitle;
  String get content => node.content;
  Map<String, String> get columnValues => node.columnValues;
}
