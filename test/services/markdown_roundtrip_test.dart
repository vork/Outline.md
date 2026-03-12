import 'package:flutter_test/flutter_test.dart';
import 'package:outline_md/services/markdown_parser.dart';
import 'package:outline_md/services/markdown_serializer.dart';

void main() {
  late MarkdownParser parser;
  late MarkdownSerializer serializer;

  setUp(() {
    parser = MarkdownParser();
    serializer = MarkdownSerializer();
  });

  group('Markdown round-trip (parse → serialize)', () {
    test('simple headings survive round-trip', () {
      const input = '# First\n\n## Second\n\n## Third\n';
      final doc = parser.parse(input);
      final output = serializer.serialize(doc);
      expect(output, contains('# First'));
      expect(output, contains('## Second'));
      expect(output, contains('## Third'));
    });

    test('heading with body text survives round-trip', () {
      const input = '# Title\nSome body text.\n';
      final doc = parser.parse(input);
      final output = serializer.serialize(doc);
      expect(output, contains('# Title'));
      expect(output, contains('Some body text.'));
    });

    test('front-matter with columns survives round-trip', () {
      const input =
          '---\ntitle: "My Doc"\ncolumns: [Status, Priority]\n---\n\n# Task | Done | High\n';
      final doc = parser.parse(input);
      final output = serializer.serialize(doc);
      expect(output, contains('title: "My Doc"'));
      expect(output, contains('columns: [Status, Priority]'));
      expect(output, contains('Done'));
      expect(output, contains('High'));
    });

    test('checkbox heading survives round-trip', () {
      const input = '# [ ] A pending task\n';
      final doc = parser.parse(input);
      expect(doc.nodes[0].isCheckbox, true);
      expect(doc.nodes[0].isChecked, false);

      final output = serializer.serialize(doc);
      expect(output, contains('# A pending task'));
    });

    test('nested structure preserves hierarchy', () {
      const input = '# A\n## B\n### C\n## D\n';
      final doc = parser.parse(input);

      expect(doc.nodes.length, 1);
      expect(doc.nodes[0].children.length, 2);
      expect(doc.nodes[0].children[0].children.length, 1);

      final output = serializer.serialize(doc);
      expect(output, contains('# A'));
      expect(output, contains('## B'));
      expect(output, contains('### C'));
      expect(output, contains('## D'));
    });

    test('complex document round-trip', () {
      const input = '''---
title: "Project Plan"
columns: [Status, Owner]
---

# Overview
This is the project overview.

## Goals | Active | Alice
We want to achieve great things.

### Milestone 1 | Done | Bob

### Milestone 2 | Pending | Carol

## Timeline
- Phase 1
- Phase 2
- Phase 3
''';
      final doc = parser.parse(input);
      final output = serializer.serialize(doc);

      expect(output, contains('title: "Project Plan"'));
      expect(output, contains('# Overview'));
      expect(output, contains('## Goals'));
      expect(output, contains('### Milestone 1'));
      expect(output, contains('### Milestone 2'));
      expect(output, contains('## Timeline'));
      expect(output, contains('Alice'));
      expect(output, contains('Bob'));
      expect(output, contains('Carol'));
    });

    test('inline math survives round-trip', () {
      const input = r'# Math Section' '\n'
          r'The quadratic formula is $x = \frac{-b}{2a}$ and $\alpha = 1$.'
          '\n';
      final doc = parser.parse(input);
      final output = serializer.serialize(doc);
      expect(output, contains(r'$x = \frac{-b}{2a}$'));
      expect(output, contains(r'$\alpha = 1$'));
    });

    test('block math survives round-trip', () {
      const input = '# Math\nIntegral:\n\n\$\$\n\\int_0^1 x \\, dx\n\$\$\n';
      final doc = parser.parse(input);
      final output = serializer.serialize(doc);
      expect(output, contains('\$\$'));
      expect(output, contains(r'\int_0^1 x \, dx'));
    });

    test('mixed math and markdown survives round-trip', () {
      const input = '# Notes\n'
          r'Here is **bold** and $a^2 + b^2$ math.' '\n'
          r'Also `code` and $\gamma$.' '\n';
      final doc = parser.parse(input);
      final output = serializer.serialize(doc);
      expect(output, contains('**bold**'));
      expect(output, contains(r'$a^2 + b^2$'));
      expect(output, contains('`code`'));
      expect(output, contains(r'$\gamma$'));
    });
  });
}
