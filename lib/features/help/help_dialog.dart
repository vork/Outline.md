import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

void showHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const _HelpDialog(),
  );
}

class _HelpDialog extends StatelessWidget {
  const _HelpDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.article_outlined,
                      color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'How to Use Outline.md',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section(theme, 'Getting Started', [
                      'Each cell is a block of markdown. Double-tap a cell to edit it.',
                      'Use # for headings: # H1, ## H2, ### H3, and so on.',
                      'Headings automatically nest: ## under #, ### under ##.',
                      'When you finish editing, the cell renders your markdown beautifully.',
                    ]),
                    _section(theme, 'Outline Structure', [
                      'The sidebar shows your document outline based on headings.',
                      'Click any sidebar item to jump to that section.',
                      'Collapse/expand sections with the arrow toggle on each cell.',
                      'Use Collapse All / Expand All in the toolbar.',
                    ]),
                    _section(theme, 'Drag & Drop', [
                      'Long-press the drag handle (dots icon) to reorder cells.',
                      'Drop a cell onto another to move it below that cell.',
                      'Use the cell menu to nest or change heading levels.',
                    ]),
                    _section(theme, 'Columns', [
                      'Add columns via the column icon in the toolbar.',
                      'Columns appear next to each cell.',
                      'Great for adding Time, Status, Priority fields.',
                    ]),
                    _section(theme, 'Checkboxes', [
                      'Use the cell menu (three dots) to add a checkbox to any item.',
                      'Or write - [ ] or - [x] in markdown.',
                    ]),
                    _section(theme, 'Files', [
                      'Save and load standard .md markdown files.',
                      'Export to LaTeX (.tex) with all formatting preserved.',
                      'Images are referenced with ![alt](path) markdown syntax.',
                    ]),
                    if (isDesktop)
                      _section(theme, 'Keyboard Shortcuts', [
                        '$platformModifierKey+N  New document',
                        '$platformModifierKey+O  Open file',
                        '$platformModifierKey+S  Save file',
                        '$platformModifierKey+Enter  Commit cell',
                        'Escape  Commit cell',
                        'Tab  Indent (increase heading level)',
                        'Shift+Tab  Outdent (decrease heading level)',
                        '$platformModifierKey+Up  Move section up',
                        '$platformModifierKey+Down  Move section down',
                        'Enter  Add new cell below',
                      ]),
                    if (isMobile)
                      _section(theme, 'Touch Gestures', [
                        'Tap a cell to select it.',
                        'Double-tap to enter edit mode.',
                        'Tap outside a cell to commit your changes.',
                        'Long-press the drag handle to reorder.',
                        'Use the three-dot menu for more options.',
                      ]),
                    _section(theme, 'Mermaid Diagrams', [
                      'Use ```mermaid code blocks to add diagrams.',
                      'Diagrams are shown as a preview in the rendered view.',
                    ]),
                    _section(theme, 'Themes', [
                      'Click the theme icon to cycle: System, Light, Dark.',
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
