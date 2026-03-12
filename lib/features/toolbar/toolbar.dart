import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/document_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/file_service.dart';
import '../../services/latex_exporter.dart';
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
                ref.read(documentProvider.notifier).addNodeAtEnd();
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
    ref.read(editorStateProvider.notifier).clearEditing();
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
      ref.read(editorStateProvider.notifier).clearEditing();
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
