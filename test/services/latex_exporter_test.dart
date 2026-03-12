import 'package:flutter_test/flutter_test.dart';
import 'package:outline_md/models/column_def.dart';
import 'package:outline_md/models/outline_document.dart';
import 'package:outline_md/models/outline_node.dart';
import 'package:outline_md/services/latex_exporter.dart';

void main() {
  late LatexExporter exporter;

  setUp(() {
    exporter = LatexExporter();
  });

  group('LatexExporter.generateTex', () {
    test('generates valid LaTeX document structure', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(id: '1', content: '# Section One', headingLevel: 1),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\documentclass'));
      expect(tex, contains(r'\begin{document}'));
      expect(tex, contains(r'\end{document}'));
      expect(tex, contains(r'\maketitle'));
      expect(tex, contains(r'\tableofcontents'));
    });

    test('includes required LaTeX packages', () {
      final doc = OutlineDocument(title: 'Test', nodes: []);
      final tex = exporter.generateTex(doc);
      for (final pkg in [
        'inputenc', 'fontenc', 'lmodern', 'graphicx',
        'hyperref', 'enumitem', 'listings', 'xcolor',
        'booktabs', 'amssymb', 'geometry',
      ]) {
        expect(tex, contains(pkg), reason: 'Missing package: $pkg');
      }
    });

    test('maps heading levels to LaTeX section commands', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: '# H1',
            headingLevel: 1,
            children: [
              OutlineNode(
                id: '2',
                content: '## H2',
                headingLevel: 2,
                children: [
                  OutlineNode(
                    id: '3',
                    content: '### H3',
                    headingLevel: 3,
                    children: [
                      OutlineNode(id: '4', content: '#### H4', headingLevel: 4),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\section{H1}'));
      expect(tex, contains(r'\subsection{H2}'));
      expect(tex, contains(r'\subsubsection{H3}'));
      expect(tex, contains(r'\paragraph{H4}'));
    });

    test('renders unchecked checkbox in heading', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: '# Todo',
            headingLevel: 1,
            isCheckbox: true,
            isChecked: false,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\unchecked'));
      expect(tex, contains(r'\section'));
    });

    test('renders checked checkbox in heading', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: '# Done',
            headingLevel: 1,
            isCheckbox: true,
            isChecked: true,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\checked'));
    });

    test('renders column values as tabular', () {
      final doc = OutlineDocument(
        title: 'Test',
        columns: [ColumnDef(name: 'Status'), ColumnDef(name: 'Priority')],
        nodes: [
          OutlineNode(
            id: '1',
            content: '# Task',
            headingLevel: 1,
            columnValues: {'Status': 'Done', 'Priority': 'High'},
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\begin{tabular}'));
      expect(tex, contains(r'\end{tabular}'));
      expect(tex, contains('Done'));
      expect(tex, contains('High'));
      expect(tex, contains(r'\textbf{Status}'));
    });

    test('escapes special LaTeX characters in title', () {
      final doc = OutlineDocument(
        title: 'Test & Report #1',
        nodes: [],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'Test \& Report \#1'));
    });

    test('renders bullet lists as itemize', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: '- Item one\n- Item two\n- Item three',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\begin{itemize}'));
      expect(tex, contains(r'\end{itemize}'));
      expect(tex, contains(r'\item'));
    });

    test('renders checkbox in bullet list', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: '- [x] Done item\n- [ ] Pending item',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\checked'));
      expect(tex, contains(r'\unchecked'));
    });

    test('renders fenced code blocks as lstlisting', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: '```dart\nvoid main() {}\n```',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\begin{lstlisting}'));
      expect(tex, contains(r'\end{lstlisting}'));
      expect(tex, contains('void main() {}'));
    });

    test('renders mermaid blocks with comment', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: '```mermaid\ngraph TD\n```',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains('Mermaid'));
      expect(tex, contains(r'\begin{lstlisting}'));
    });

    test('renders images as figures', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: '![A photo](images/photo.png)',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\begin{figure}'));
      expect(tex, contains(r'\includegraphics'));
      expect(tex, contains('photo.png'));
      expect(tex, contains(r'\caption{A photo}'));
    });

    test('renders bold and italic markdown', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: 'This is **bold** and *italic* and `code`.',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\textbf{bold}'));
      expect(tex, contains(r'\textit{italic}'));
      expect(tex, contains(r'\texttt{code}'));
    });

    test('escapes all special LaTeX characters', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: r'Price is $10 & 50% off #sale {today} ~end^',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\$'));
      expect(tex, contains(r'\&'));
      expect(tex, contains(r'\%'));
      expect(tex, contains(r'\#'));
      expect(tex, contains(r'\{'));
      expect(tex, contains(r'\}'));
      expect(tex, contains(r'\textasciitilde{}'));
      expect(tex, contains(r'\textasciicircum{}'));
    });

    test('empty document produces valid LaTeX', () {
      final doc = OutlineDocument(title: 'Empty', nodes: []);
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\begin{document}'));
      expect(tex, contains(r'\end{document}'));
    });

    test('heading H5 and H6 map to subparagraph', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(id: '1', content: '##### H5', headingLevel: 5),
          OutlineNode(id: '2', content: '###### H6', headingLevel: 6),
        ],
      );
      final tex = exporter.generateTex(doc);
      final subparagraphCount =
          RegExp(r'\\subparagraph').allMatches(tex).length;
      expect(subparagraphCount, 2);
    });

    // ── Math support ─────────────────────────────────────────────

    test('includes amsmath package', () {
      final doc = OutlineDocument(title: 'Math Test', nodes: []);
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\usepackage{amsmath}'));
    });

    test('preserves inline math without escaping dollar signs', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: r'The formula $E = mc^2$ is famous.',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'$E = mc^2$'));
      expect(tex, isNot(contains(r'\$E = mc^2\$')));
    });

    test('escapes dollar sign when not part of math expression', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: r'Price is $10',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\$'));
    });

    test('converts block math delimiters to display math', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: 'Text before\n\$\$\nx^2 + y^2 = z^2\n\$\$\nText after',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\['));
      expect(tex, contains(r'\]'));
      expect(tex, contains('x^2 + y^2 = z^2'));
    });

    test('preserves complex inline math expressions', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: r'Given $\frac{a}{b} + \sqrt{c}$ we derive $\alpha$.',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'$\frac{a}{b} + \sqrt{c}$'));
      expect(tex, contains(r'$\alpha$'));
    });

    test('handles multiple inline math expressions on one line', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: r'Both $a+b$ and $c+d$ are sums.',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'$a+b$'));
      expect(tex, contains(r'$c+d$'));
    });

    test('escapes text between math expressions', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: r'$a$ & $b$ are 100% valid',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'$a$'));
      expect(tex, contains(r'$b$'));
      expect(tex, contains(r'\&'));
      expect(tex, contains(r'\%'));
    });

    test('inline math in bullet list is preserved', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: r'- Sum: $a + b = c$' '\n' r'- Product: $a \cdot b$',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'$a + b = c$'));
      expect(tex, contains(r'$a \cdot b$'));
    });

    test('block math with complex multi-line content', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content:
                'The integral:\n\$\$\n\\int_0^1 f(x) \\, dx\n\$\$\nresult.',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\['));
      expect(tex, contains(r'\int_0^1 f(x) \, dx'));
      expect(tex, contains(r'\]'));
    });

    test('does not confuse code blocks containing dollar signs with math', () {
      final doc = OutlineDocument(
        title: 'Test',
        nodes: [
          OutlineNode(
            id: '1',
            content: '```bash\necho \$HOME\n```',
            headingLevel: 0,
          ),
        ],
      );
      final tex = exporter.generateTex(doc);
      expect(tex, contains(r'\begin{lstlisting}'));
      expect(tex, contains(r'echo $HOME'));
    });
  });
}
