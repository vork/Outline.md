import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:outline_md/models/outline_node.dart';
import 'package:outline_md/services/latex_exporter.dart';
import 'package:outline_md/services/markdown_parser.dart';
import 'package:outline_md/services/markdown_serializer.dart';
import 'package:outline_md/utils/tree_utils.dart';

/// Recursively flatten a tree into a list of nodes.
List<OutlineNode> flatten(List<OutlineNode> nodes) => flattenTree(nodes);

/// Find the first node whose displayTitle contains [substring].
OutlineNode? findByTitle(List<OutlineNode> nodes, String substring) {
  return flatten(nodes).cast<OutlineNode?>().firstWhere(
        (n) => n!.displayTitle.contains(substring),
        orElse: () => null,
      );
}

void main() {
  late MarkdownParser parser;
  late MarkdownSerializer serializer;
  late LatexExporter latexExporter;

  setUp(() {
    parser = MarkdownParser();
    serializer = MarkdownSerializer();
    latexExporter = LatexExporter();
  });

  // ─────────────────────────────────────────────────────────────────
  // Fixture 1: full_features.md — columns, checkboxes, code, mermaid,
  //            images, deep nesting H1–H6
  // ─────────────────────────────────────────────────────────────────
  group('full_features.md', () {
    late String source;
    setUp(() {
      source = File('test/fixtures/full_features.md').readAsStringSync();
    });

    // ── Document-level metadata ──────────────────────────────────

    test('parses title from front-matter', () {
      final doc = parser.parse(source);
      expect(doc.title, 'Project Alpha');
    });

    test('parses column definitions', () {
      final doc = parser.parse(source);
      expect(doc.columns.length, 2);
      expect(doc.columns[0].name, 'Status');
      expect(doc.columns[1].name, 'Owner');
    });

    // ── Top-level tree structure ─────────────────────────────────

    test('has five H1 root nodes', () {
      final doc = parser.parse(source);
      expect(doc.nodes.length, 5);
      expect(doc.nodes.every((n) => n.headingLevel == 1), true);
    });

    test('root node titles are correct', () {
      final doc = parser.parse(source);
      final titles = doc.nodes.map((n) => n.displayTitle).toList();
      expect(titles, [
        'Overview',
        'Architecture',
        'Tasks',
        'Math & Formulas',
        'Deep Nesting',
      ]);
    });

    // ── Column values ────────────────────────────────────────────

    test('Overview heading has column values', () {
      final doc = parser.parse(source);
      final overview = doc.nodes[0];
      expect(overview.columnValues['Status'], 'Planning');
      expect(overview.columnValues['Owner'], 'Team');
    });

    test('child headings have column values', () {
      final doc = parser.parse(source);
      final goals = findByTitle(doc.nodes, 'Goals')!;
      expect(goals.columnValues['Status'], 'Active');
      expect(goals.columnValues['Owner'], 'Alice');
    });

    test('headings without column values have empty map', () {
      final doc = parser.parse(source);
      final timeline = findByTitle(doc.nodes, 'Timeline')!;
      expect(timeline.columnValues, isEmpty);
    });

    // ── Checkbox headings ────────────────────────────────────────

    test('parses checked checkbox heading (Milestone 1)', () {
      final doc = parser.parse(source);
      final m1 = findByTitle(doc.nodes, 'Milestone 1')!;
      expect(m1.isCheckbox, true);
      expect(m1.isChecked, true);
      expect(m1.headingLevel, 3);
      expect(m1.columnValues['Status'], 'Done');
      expect(m1.columnValues['Owner'], 'Bob');
    });

    test('parses unchecked checkbox heading (Milestone 2)', () {
      final doc = parser.parse(source);
      final m2 = findByTitle(doc.nodes, 'Milestone 2')!;
      expect(m2.isCheckbox, true);
      expect(m2.isChecked, false);
      expect(m2.columnValues['Status'], 'Pending');
    });

    test('non-checkbox heading is not a checkbox (Milestone 3)', () {
      final doc = parser.parse(source);
      final m3 = findByTitle(doc.nodes, 'Milestone 3')!;
      expect(m3.isCheckbox, false);
    });

    test('task headings with checkboxes', () {
      final doc = parser.parse(source);
      final design = findByTitle(doc.nodes, 'Design')!;
      final impl = findByTitle(doc.nodes, 'Implementation')!;
      final testing = findByTitle(doc.nodes, 'Testing')!;

      expect(design.isCheckbox, true);
      expect(design.isChecked, true);

      expect(impl.isCheckbox, true);
      expect(impl.isChecked, false);

      expect(testing.isCheckbox, true);
      expect(testing.isChecked, false);
    });

    // ── Nesting structure ────────────────────────────────────────

    test('Overview has Goals and Timeline as children', () {
      final doc = parser.parse(source);
      final overview = doc.nodes[0];
      final childTitles =
          overview.children.map((n) => n.displayTitle).toList();
      expect(childTitles, contains('Goals'));
      expect(childTitles, contains('Timeline'));
    });

    test('Goals has three milestone children', () {
      final doc = parser.parse(source);
      final goals = findByTitle(doc.nodes, 'Goals')!;
      expect(goals.children.length, 3);
      expect(goals.children[0].displayTitle, 'Milestone 1');
      expect(goals.children[1].displayTitle, 'Milestone 2');
      expect(goals.children[2].displayTitle, 'Milestone 3');
    });

    test('Architecture has Backend, Frontend, System Diagram children', () {
      final doc = parser.parse(source);
      final arch = doc.nodes[1];
      final childTitles = arch.children.map((n) => n.displayTitle).toList();
      expect(childTitles, contains('Backend'));
      expect(childTitles, contains('Frontend'));
      expect(childTitles, contains('System Diagram'));
    });

    test('Deep Nesting goes H1 → H2 → H3 → H4 → H5 → H6', () {
      final doc = parser.parse(source);
      final deep = doc.nodes[4];
      expect(deep.headingLevel, 1);

      final l2 = deep.children.first;
      expect(l2.headingLevel, 2);
      expect(l2.displayTitle, 'Level 2');

      final l3 = l2.children.first;
      expect(l3.headingLevel, 3);
      expect(l3.displayTitle, 'Level 3');

      final l4 = l3.children.first;
      expect(l4.headingLevel, 4);
      expect(l4.displayTitle, 'Level 4');

      final l5 = l4.children.first;
      expect(l5.headingLevel, 5);
      expect(l5.displayTitle, 'Level 5');

      final l6 = l5.children.first;
      expect(l6.headingLevel, 6);
      expect(l6.displayTitle, 'Level 6');
    });

    // ── Rich content preserved in node content ───────────────────

    test('body text with markdown formatting is preserved', () {
      final doc = parser.parse(source);
      final overview = doc.nodes[0];
      expect(overview.content, contains('**project overview**'));
      expect(overview.content, contains('*italic emphasis*'));
      expect(overview.content, contains('`inline code`'));
    });

    test('image references are preserved in content', () {
      final doc = parser.parse(source);
      final backend = findByTitle(doc.nodes, 'Backend')!;
      expect(
          backend.content, contains('![Backend Diagram - No just a raccoon](images/banjo.jpg)'));
    });

    test('fenced code blocks are preserved in content', () {
      final doc = parser.parse(source);
      final backend = findByTitle(doc.nodes, 'Backend')!;
      expect(backend.content, contains('```rust'));
      expect(backend.content, contains('async fn main()'));

      final frontend = findByTitle(doc.nodes, 'Frontend')!;
      expect(frontend.content, contains('```typescript'));
      expect(frontend.content, contains('function App()'));
    });

    test('mermaid diagram is preserved in content', () {
      final doc = parser.parse(source);
      final diagram = findByTitle(doc.nodes, 'System Diagram')!;
      expect(diagram.content, contains('```mermaid'));
      expect(diagram.content, contains('graph TD'));
      expect(diagram.content, contains('API Gateway'));
    });

    test('bullet list is preserved in content', () {
      final doc = parser.parse(source);
      final timeline = findByTitle(doc.nodes, 'Timeline')!;
      expect(timeline.content, contains('- Phase 1: Research'));
      expect(timeline.content, contains('- Phase 2: Development'));
      expect(timeline.content, contains('- Phase 3: Launch'));
    });

    test('deep level 6 content has rich formatting and image', () {
      final doc = parser.parse(source);
      final l6 = findByTitle(doc.nodes, 'Level 6')!;
      expect(l6.content, contains('**bold**'));
      expect(l6.content, contains('*italic*'));
      expect(l6.content, contains('`code`'));
      expect(l6.content, contains('![Deep Image](images/shark.jpg)'));
    });

    // ── Math content ──────────────────────────────────────────────

    test('Math & Formulas section has children', () {
      final doc = parser.parse(source);
      final math = findByTitle(doc.nodes, 'Math & Formulas')!;
      final childTitles = math.children.map((n) => n.displayTitle).toList();
      expect(childTitles, contains('Inline Math'));
      expect(childTitles, contains('Block Math'));
      expect(childTitles, contains('Mixed Content'));
    });

    test('inline math is preserved in content', () {
      final doc = parser.parse(source);
      final inlineMath = findByTitle(doc.nodes, 'Inline Math')!;
      expect(inlineMath.content,
          contains(r'$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$'));
      expect(inlineMath.content, contains(r'$e^{i\pi} + 1 = 0$'));
    });

    test('block math delimiters are preserved in content', () {
      final doc = parser.parse(source);
      final blockMath = findByTitle(doc.nodes, 'Block Math')!;
      expect(blockMath.content, contains(r'$$'));
      expect(blockMath.content, contains(r'\int_{-\infty}^{\infty}'));
      expect(blockMath.content, contains(r'\sqrt{\pi}'));
      expect(blockMath.content, contains(r"f'(x) = \lim_{h \to 0}"));
    });

    test('mixed content has inline math alongside markdown', () {
      final doc = parser.parse(source);
      final mixed = findByTitle(doc.nodes, 'Mixed Content')!;
      expect(mixed.content, contains(r'$\alpha + \beta = \gamma$'));
      expect(mixed.content, contains('**bold text**'));
      expect(mixed.content, contains('`code`'));
      expect(mixed.content, contains(r'$a^2 + b^2 = c^2$'));
    });

    // ── Total node count ─────────────────────────────────────────

    test('total flattened node count', () {
      final doc = parser.parse(source);
      final all = flatten(doc.nodes);
      expect(all.length, greaterThanOrEqualTo(18));
    });

    // ── Markdown round-trip ──────────────────────────────────────

    test('serialize → parse preserves root count', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);
      expect(doc2.nodes.length, doc.nodes.length);
    });

    test('serialize → parse preserves title and columns', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);
      expect(doc2.title, doc.title);
      expect(doc2.columns.length, doc.columns.length);
      expect(doc2.columns.map((c) => c.name).toList(),
          doc.columns.map((c) => c.name).toList());
    });

    test('serialize → parse preserves column values', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);
      final overview2 = doc2.nodes[0];
      expect(overview2.columnValues['Status'], 'Planning');
      expect(overview2.columnValues['Owner'], 'Team');
    });

    test('serialize → parse preserves total node count', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);
      expect(flatten(doc2.nodes).length, flatten(doc.nodes).length);
    });

    test('checkbox state survives initial parse', () {
      final doc = parser.parse(source);

      final m1 = findByTitle(doc.nodes, 'Milestone 1')!;
      expect(m1.isCheckbox, true);
      expect(m1.isChecked, true);

      final m2 = findByTitle(doc.nodes, 'Milestone 2')!;
      expect(m2.isCheckbox, true);
      expect(m2.isChecked, false);
    });

    test('heading checkbox state is lost on round-trip (known limitation)', () {
      // The serializer writes heading content as-is without re-injecting
      // the [x]/[ ] prefix, so checkbox state on headings doesn't survive
      // a serialize→parse cycle. Body-level checkboxes do survive.
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);

      final m1 = findByTitle(doc2.nodes, 'Milestone 1')!;
      expect(m1.isCheckbox, false,
          reason: 'heading checkbox prefix not re-serialized');
    });

    test('serialize preserves code blocks and mermaid', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      expect(md, contains('```rust'));
      expect(md, contains('```typescript'));
      expect(md, contains('```mermaid'));
      expect(md, contains('graph TD'));
    });

    test('serialize preserves images', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      expect(md, contains('![Backend Diagram - No just a raccoon](images/banjo.jpg)'));
      expect(md, contains('![Deep Image](images/shark.jpg)'));
    });

    test('serialize preserves inline math', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      expect(md, contains(r'$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$'));
      expect(md, contains(r'$e^{i\pi} + 1 = 0$'));
    });

    test('serialize preserves block math', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      expect(md, contains(r'$$'));
      expect(md, contains(r'\int_{-\infty}^{\infty}'));
      expect(md, contains(r'\sqrt{\pi}'));
    });

    test('round-trip preserves inline math in node content', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);
      final inlineMath2 = findByTitle(doc2.nodes, 'Inline Math')!;
      expect(inlineMath2.content,
          contains(r'$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$'));
    });

    // ── LaTeX export ─────────────────────────────────────────────

    test('LaTeX contains all section levels', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\section{'));
      expect(tex, contains(r'\subsection{'));
      expect(tex, contains(r'\subsubsection{'));
      expect(tex, contains(r'\paragraph{'));
      expect(tex, contains(r'\subparagraph{'));
    });

    test('LaTeX contains checkbox symbols', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\checked'));
      expect(tex, contains(r'\unchecked'));
    });

    test('LaTeX contains column tables', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\begin{tabular}'));
      expect(tex, contains(r'\textbf{Status}'));
      expect(tex, contains(r'\textbf{Owner}'));
      expect(tex, contains('Planning'));
    });

    test('LaTeX contains code listings', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\begin{lstlisting}'));
      expect(tex, contains(r'\end{lstlisting}'));
      expect(tex, contains('async fn main()'));
    });

    test('LaTeX contains mermaid block', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains('Mermaid'));
      expect(tex, contains('graph TD'));
    });

    test('LaTeX contains image figures', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\begin{figure}'));
      expect(tex, contains(r'\includegraphics'));
      expect(tex, contains('banjo.jpg'));
    });

    test('LaTeX contains bullet itemize lists', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\begin{itemize}'));
      expect(tex, contains(r'\item'));
    });

    test('LaTeX has valid document wrapper', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\begin{document}'));
      expect(tex, contains(r'\end{document}'));
      expect(tex, contains(r'\maketitle'));
      expect(tex, contains(r'\tableofcontents'));
    });

    test('LaTeX includes amsmath package for math', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\usepackage{amsmath}'));
    });

    test('LaTeX preserves inline math expressions', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'$e^{i\pi} + 1 = 0$'));
      expect(tex, contains(r'$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$'));
    });

    test('LaTeX converts block math to display math', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\['));
      expect(tex, contains(r'\]'));
      expect(tex, contains(r'\int_{-\infty}^{\infty}'));
      expect(tex, contains(r'\sqrt{\pi}'));
    });

    test('LaTeX does not escape dollar signs inside math', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, isNot(contains(r'\$e^')));
      expect(tex, isNot(contains(r'\$\alpha')));
    });

    test('LaTeX handles mixed math and markdown on same line', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'$\alpha + \beta = \gamma$'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Fixture 2: simple_notes.md — no columns, no front-matter,
  //            code blocks, mermaid, images, checkboxes in body
  // ─────────────────────────────────────────────────────────────────
  group('simple_notes.md', () {
    late String source;
    setUp(() {
      source = File('test/fixtures/simple_notes.md').readAsStringSync();
    });

    // ── Document-level metadata ──────────────────────────────────

    test('title falls back to first heading', () {
      final doc = parser.parse(source);
      expect(doc.title, 'Meeting Notes');
    });

    test('no columns defined', () {
      final doc = parser.parse(source);
      expect(doc.columns, isEmpty);
      expect(doc.hasColumns, false);
    });

    // ── Top-level structure ──────────────────────────────────────

    test('has three H1 root nodes', () {
      final doc = parser.parse(source);
      expect(doc.nodes.length, 3);
      expect(doc.nodes[0].displayTitle, 'Meeting Notes');
      expect(doc.nodes[1].displayTitle, 'Technical Details');
      expect(doc.nodes[2].displayTitle, 'References');
    });

    test('Meeting Notes has correct H2 children', () {
      final doc = parser.parse(source);
      final meeting = doc.nodes[0];
      final childTitles =
          meeting.children.map((n) => n.displayTitle).toList();
      expect(childTitles, [
        'Action Items',
        'Discussion Points',
        'Decisions',
        'Next Steps',
      ]);
    });

    // ── Nested headings ──────────────────────────────────────────

    test('Discussion Points has H3 children', () {
      final doc = parser.parse(source);
      final discussion = findByTitle(doc.nodes, 'Discussion Points')!;
      final childTitles =
          discussion.children.map((n) => n.displayTitle).toList();
      expect(childTitles, contains('Performance'));
      expect(childTitles, contains('Design'));
      expect(childTitles, contains('Architecture'));
    });

    test('Next Steps has Assignments child', () {
      final doc = parser.parse(source);
      final nextSteps = findByTitle(doc.nodes, 'Next Steps')!;
      expect(nextSteps.children.length, 1);
      expect(nextSteps.children[0].displayTitle, 'Assignments');
    });

    // ── Rich content ─────────────────────────────────────────────

    test('Action Items contains checkbox bullets in content', () {
      final doc = parser.parse(source);
      final actions = findByTitle(doc.nodes, 'Action Items')!;
      expect(actions.content, contains('- [x] Review the proposal'));
      expect(actions.content, contains('- [ ] Send follow-up email'));
      expect(actions.content, contains('- [ ] Schedule next meeting'));
    });

    test('Performance section has dart code block', () {
      final doc = parser.parse(source);
      final perf = findByTitle(doc.nodes, 'Performance')!;
      expect(perf.content, contains('```dart'));
      expect(perf.content, contains('class PerformanceMonitor'));
      expect(perf.content, contains('Stopwatch'));
    });

    test('Performance section has bullet list', () {
      final doc = parser.parse(source);
      final perf = findByTitle(doc.nodes, 'Performance')!;
      expect(perf.content, contains('- Virtual scrolling'));
      expect(perf.content, contains('- Image lazy loading'));
    });

    test('Design section has image', () {
      final doc = parser.parse(source);
      final design = findByTitle(doc.nodes, 'Design')!;
      expect(design.content, contains('![Mockup](assets/mockup_v2.png)'));
    });

    test('Architecture section has mermaid sequence diagram', () {
      final doc = parser.parse(source);
      final arch = findByTitle(doc.nodes, 'Architecture')!;
      expect(arch.content, contains('```mermaid'));
      expect(arch.content, contains('sequenceDiagram'));
      expect(arch.content, contains('FileService'));
      expect(arch.content, contains('OutlineDocument'));
    });

    test('Assignments contains mixed checkbox bullets', () {
      final doc = parser.parse(source);
      final assignments = findByTitle(doc.nodes, 'Assignments')!;
      expect(assignments.content, contains('- [x] Alice'));
      expect(assignments.content, contains('- [ ] Bob'));
      expect(assignments.content, contains('- [ ] Carol'));
    });

    test('References section has inline formatting', () {
      final doc = parser.parse(source);
      final refs = doc.nodes[2];
      expect(refs.content, contains('*official documentation*'));
      expect(refs.content, contains('`code snippets`'));
      expect(refs.content, contains('**important notes**'));
    });

    test('Next Steps has bold and inline code', () {
      final doc = parser.parse(source);
      final next = findByTitle(doc.nodes, 'Next Steps')!;
      expect(next.content, contains('**Tuesday**'));
      expect(next.content, contains('`10:00 AM`'));
    });

    // ── Math content ─────────────────────────────────────────────

    test('Technical Details section has children', () {
      final doc = parser.parse(source);
      final tech = findByTitle(doc.nodes, 'Technical Details')!;
      final childTitles = tech.children.map((n) => n.displayTitle).toList();
      expect(childTitles, contains('Complexity Analysis'));
      expect(childTitles, contains('Physics Notes'));
    });

    test('Complexity Analysis has inline math', () {
      final doc = parser.parse(source);
      final complexity = findByTitle(doc.nodes, 'Complexity Analysis')!;
      expect(complexity.content, contains(r'$O(n \log n)$'));
      expect(complexity.content, contains(r'$O(n)$'));
      expect(complexity.content, contains(r'$T(n) = O(n \log n)$'));
    });

    test('Complexity Analysis has block math', () {
      final doc = parser.parse(source);
      final complexity = findByTitle(doc.nodes, 'Complexity Analysis')!;
      expect(complexity.content, contains(r'$$'));
      expect(complexity.content, contains(r'T(n) = 2T(n/2) + O(n)'));
    });

    test('Physics Notes has inline and block math', () {
      final doc = parser.parse(source);
      final physics = findByTitle(doc.nodes, 'Physics Notes')!;
      expect(physics.content, contains(r'$E = mc^2$'));
      expect(physics.content, contains(r'$$'));
      expect(physics.content, contains(r'i\hbar'));
      expect(physics.content, contains(r'\Psi(x,t)'));
    });

    // ── Total count ──────────────────────────────────────────────

    test('total flattened node count', () {
      final doc = parser.parse(source);
      final all = flatten(doc.nodes);
      expect(all.length, greaterThanOrEqualTo(8));
    });

    // ── Markdown round-trip ──────────────────────────────────────

    test('round-trip preserves root count', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);
      expect(doc2.nodes.length, doc.nodes.length);
    });

    test('round-trip preserves total node count', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);
      expect(flatten(doc2.nodes).length, flatten(doc.nodes).length);
    });

    test('round-trip preserves heading levels', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);
      final levels1 = flatten(doc.nodes).map((n) => n.headingLevel).toList();
      final levels2 = flatten(doc2.nodes).map((n) => n.headingLevel).toList();
      expect(levels2, levels1);
    });

    test('round-trip preserves code blocks', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      expect(md, contains('```dart'));
      expect(md, contains('class PerformanceMonitor'));
    });

    test('round-trip preserves mermaid diagram', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      expect(md, contains('```mermaid'));
      expect(md, contains('sequenceDiagram'));
    });

    test('round-trip preserves images', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      expect(md, contains('![Mockup](assets/mockup_v2.png)'));
    });

    test('no front-matter in serialized output (no columns)', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      expect(md, isNot(contains('---')));
    });

    test('round-trip preserves inline math', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      final doc2 = parser.parse(md);
      final complexity2 = findByTitle(doc2.nodes, 'Complexity Analysis')!;
      expect(complexity2.content, contains(r'$O(n \log n)$'));
      expect(complexity2.content, contains(r'$O(n)$'));
    });

    test('round-trip preserves block math', () {
      final doc = parser.parse(source);
      final md = serializer.serialize(doc);
      expect(md, contains(r'$$'));
      expect(md, contains(r'T(n) = 2T(n/2) + O(n)'));
      expect(md, contains(r'i\hbar'));
    });

    // ── LaTeX export ─────────────────────────────────────────────

    test('LaTeX has sections and subsections', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\section{Meeting Notes}'));
      expect(tex, contains(r'\subsection{'));
      expect(tex, contains(r'\subsubsection{'));
    });

    test('LaTeX has code listing for dart', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\begin{lstlisting}[language=dart]'));
      expect(tex, contains('PerformanceMonitor'));
    });

    test('LaTeX has mermaid block', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains('Mermaid'));
      expect(tex, contains('sequenceDiagram'));
    });

    test('LaTeX has image figure', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\includegraphics'));
      expect(tex, contains('mockup_v2.png'));
    });

    test('LaTeX has itemize lists with checkboxes', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\begin{itemize}'));
      expect(tex, contains(r'\checked'));
      expect(tex, contains(r'\unchecked'));
    });

    test('LaTeX has bold and italic formatting', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\textbf{'));
      expect(tex, contains(r'\textit{'));
      expect(tex, contains(r'\texttt{'));
    });

    test('LaTeX has no column tables (no columns defined)', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, isNot(contains(r'\begin{tabular}')));
    });

    test('LaTeX preserves inline math from simple notes', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'$O(n \log n)$'));
      expect(tex, contains(r'$E = mc^2$'));
    });

    test('LaTeX converts block math to display math', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'\['));
      expect(tex, contains(r'\]'));
      expect(tex, contains(r'T(n) = 2T(n/2) + O(n)'));
    });

    test('LaTeX handles Schrödinger equation block math', () {
      final doc = parser.parse(source);
      final tex = latexExporter.generateTex(doc);
      expect(tex, contains(r'i\hbar'));
      expect(tex, contains(r'\Psi(x,t)'));
    });
  });
}
