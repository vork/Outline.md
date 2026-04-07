import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/document_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/file_service.dart';
import '../../services/latex_exporter.dart';
import '../../services/web_import_service.dart';
import '../../services/doc_import_service.dart';
import '../../services/markdown_parser.dart';
import '../../utils/platform_utils.dart';
import 'package:file_picker/file_picker.dart';
import '../help/help_dialog.dart';

class OutlineToolbar extends ConsumerWidget {
  final FileService fileService;

  const OutlineToolbar({super.key, required this.fileService});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentProvider);
    final themeMode = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final sidebarVisible = ref.watch(sidebarVisibleProvider);

    return GestureDetector(
      // Allow dragging the window from the toolbar on desktop
      behavior: HitTestBehavior.translucent,
      child: Container(
        padding: EdgeInsets.only(
          left: isDesktop && isMacOS ? 78 : 8, // space for traffic lights
          right: 8,
          top: isDesktop ? 6 : 4,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Row(
          children: [
            // Sidebar toggle
            _ToolbarButton(
              icon: sidebarVisible ? Icons.menu_open : Icons.menu,
              tooltip: 'Toggle Sidebar',
              onPressed: () {
                ref.read(sidebarVisibleProvider.notifier).state =
                    !sidebarVisible;
              },
            ),
            const SizedBox(width: 4),

            // File operations
            _ToolbarButton(
              icon: Icons.note_add_outlined,
              tooltip: 'New ($platformModifierKey+N)',
              onPressed: () => _newDocument(ref, context),
            ),
            _ToolbarButton(
              icon: Icons.folder_open_outlined,
              tooltip: 'Open ($platformModifierKey+O)',
              onPressed: () => _openFile(ref, context),
            ),
            _ToolbarButton(
              icon: Icons.save_outlined,
              tooltip: 'Save ($platformModifierKey+S)',
              onPressed: doc.isDirty ? () => _saveFile(ref, context) : null,
            ),

            const VerticalDivider(width: 16),

            // Undo / Redo
            _ToolbarButton(
              icon: Icons.undo,
              tooltip: 'Undo ($platformModifierKey+Z)',
              onPressed: ref.read(documentProvider.notifier).canUndo
                  ? () => ref.read(documentProvider.notifier).undo()
                  : null,
            ),
            _ToolbarButton(
              icon: Icons.redo,
              tooltip: 'Redo ($platformModifierKey+Shift+Z)',
              onPressed: ref.read(documentProvider.notifier).canRedo
                  ? () => ref.read(documentProvider.notifier).redo()
                  : null,
            ),

            const VerticalDivider(width: 16),

            // Add node
            _ToolbarButton(
              icon: Icons.add,
              tooltip: 'Add Node',
              onPressed: () {
                ref.read(documentProvider.notifier).addNodeAfterActive();
              },
            ),

            const VerticalDivider(width: 16),

            // Collapse/Expand
            _ToolbarButton(
              icon: Icons.unfold_less,
              tooltip: 'Collapse All',
              onPressed: () {
                ref.read(documentProvider.notifier).collapseAll();
              },
            ),
            _ToolbarButton(
              icon: Icons.unfold_more,
              tooltip: 'Expand All',
              onPressed: () {
                ref.read(documentProvider.notifier).expandAll();
              },
            ),

            const VerticalDivider(width: 16),

            // Columns menu
            PopupMenuButton<String>(
              tooltip: 'Columns',
              icon: Icon(
                Icons.view_column_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onSelected: (action) {
                if (action == 'add') {
                  _showAddColumnDialog(context, ref);
                } else if (action.startsWith('remove:')) {
                  ref
                      .read(documentProvider.notifier)
                      .removeColumn(action.substring(7));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'add', child: Text('Add Column...')),
                if (doc.columns.isNotEmpty) const PopupMenuDivider(),
                ...doc.columns.map(
                  (col) => PopupMenuItem(
                    value: 'remove:${col.name}',
                    child: Row(
                      children: [
                        const Icon(Icons.close, size: 14),
                        const SizedBox(width: 8),
                        Text(col.name),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Title (centered in toolbar, acts as drag area on macOS)
            Expanded(
              flex: 2,
              child: GestureDetector(
                onPanStart: (_) {
                  // Window drag handled by window_manager
                },
                child: Center(
                  child: Text(
                    '${doc.title}${doc.isDirty ? ' *' : ''}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Import
            PopupMenuButton<String>(
              tooltip: 'Import',
              icon: Icon(
                Icons.download_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onSelected: (action) {
                if (action == 'url') {
                  _importFromUrl(ref, context);
                } else if (action == 'pdf_docx') {
                  _importDocument(ref, context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'url',
                  child: Row(
                    children: [
                      Icon(Icons.language, size: 16),
                      SizedBox(width: 8),
                      Text('Import from URL...'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf_docx',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 16),
                      SizedBox(width: 8),
                      Text('Import PDF / DOCX...'),
                    ],
                  ),
                ),
              ],
            ),

            // Export
            PopupMenuButton<String>(
              tooltip: 'Export',
              icon: Icon(
                Icons.ios_share_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onSelected: (action) {
                if (action == 'latex') {
                  _exportLatex(ref, context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'latex',
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Export to LaTeX'),
                    ],
                  ),
                ),
              ],
            ),

            // Focus mode toggle
            _ToolbarButton(
              icon: ref.watch(focusModeProvider)
                  ? Icons.center_focus_strong
                  : Icons.center_focus_weak,
              tooltip: ref.watch(focusModeProvider)
                  ? 'Focus Mode: On'
                  : 'Focus Mode: Off',
              onPressed: () {
                ref.read(focusModeProvider.notifier).state =
                    !ref.read(focusModeProvider);
              },
            ),

            // Theme toggle
            _ToolbarButton(
              icon: switch (themeMode) {
                ThemeMode.system => Icons.brightness_auto,
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
              },
              tooltip: 'Theme: ${themeMode.name}',
              onPressed: () {
                ref.read(themeProvider.notifier).toggle();
              },
            ),

            const SizedBox(width: 4),

            // Font size slider (hide on narrow windows)
            if (MediaQuery.of(context).size.width > 900)
              _FontSizeControl(),

            // Help
            _ToolbarButton(
              icon: Icons.help_outline,
              tooltip: 'How to Use',
              onPressed: () => showHelpDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _newDocument(WidgetRef ref, BuildContext context) async {
    final doc = ref.read(documentProvider);
    if (doc.isDirty) {
      final result = await _showUnsavedDialog(context);
      if (result == null) return;
      if (result && context.mounted) await _saveFile(ref, context);
    }
    ref.read(documentProvider.notifier).newDocument();
    final newDoc = ref.read(documentProvider);
    ref.read(editorStateProvider.notifier).resetTo(
          newDoc.nodes.isNotEmpty ? newDoc.nodes.first.id : null,
        );
  }

  Future<void> _openFile(WidgetRef ref, BuildContext context) async {
    final doc = ref.read(documentProvider);
    if (doc.isDirty) {
      final result = await _showUnsavedDialog(context);
      if (result == null) return;
      if (result && context.mounted) await _saveFile(ref, context);
    }

    final loaded = await fileService.openFile();
    if (loaded != null) {
      ref.read(documentProvider.notifier).loadDocument(loaded);
      ref.read(editorStateProvider.notifier).resetTo(
            loaded.nodes.isNotEmpty ? loaded.nodes.first.id : null,
          );
    }
  }

  Future<void> _saveFile(WidgetRef ref, BuildContext context) async {
    final doc = ref.read(documentProvider);
    final path = await fileService.saveFile(doc);
    if (path != null) {
      ref.read(documentProvider.notifier).setFilePath(path);
    }
  }

  Future<void> _exportLatex(WidgetRef ref, BuildContext context) async {
    final doc = ref.read(documentProvider);
    final outputDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose export location',
    );
    if (outputDir == null) return;

    final exporter = LatexExporter();
    final texPath = await exporter.export(doc, outputDir);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to $texPath')),
      );
    }
  }

  Future<void> _importDocument(WidgetRef ref, BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc'],
      dialogTitle: 'Import Document',
    );

    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Importing document...')),
    );

    try {
      final service = DocImportService();
      final text = await service.importFile(filePath);
      final parser = MarkdownParser();
      final doc = parser.parse(text);

      ref.read(documentProvider.notifier).loadDocument(doc);
      ref.read(editorStateProvider.notifier).resetTo(
            doc.nodes.isNotEmpty ? doc.nodes.first.id : null,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported: ${doc.title}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _importFromUrl(WidgetRef ref, BuildContext context) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/article',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.language),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;
    if (!context.mounted) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Importing from URL...')),
    );

    try {
      final service = WebImportService();
      final markdown = await service.importUrl(url);
      final parser = MarkdownParser();
      final doc = parser.parse(markdown);

      ref.read(documentProvider.notifier).loadDocument(doc);
      ref.read(editorStateProvider.notifier).resetTo(
            doc.nodes.isNotEmpty ? doc.nodes.first.id : null,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported: ${doc.title}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<bool?> _showUnsavedDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Save changes before continuing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Don't Save"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddColumnDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Column'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Column name (e.g., Time, Status)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref.read(documentProvider.notifier).addColumn(value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                ref.read(documentProvider.notifier).addColumn(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _FontSizeControl extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(fontScaleProvider);
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.text_fields, size: 16, color: color),
        SizedBox(
          width: 90,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              thumbColor: theme.colorScheme.primary,
            ),
            child: Slider(
              value: scale,
              min: minFontScale,
              max: maxFontScale,
              onChanged: (v) {
                ref.read(fontScaleProvider.notifier).state =
                    (v * 20).roundToDouble() / 20; // snap to 0.05 increments
              },
            ),
          ),
        ),
        Text(
          '${(scale * 100).round()}%',
          style: TextStyle(fontSize: 10, color: color),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 16,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
