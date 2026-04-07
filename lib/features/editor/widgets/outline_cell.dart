import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/outline_node.dart';
import '../../../providers/document_provider.dart';
import '../../../providers/theme_provider.dart';
import 'cell_editor.dart';
import 'cell_renderer.dart';

const double kColumnWidth = 120.0;

class OutlineCell extends ConsumerStatefulWidget {
  final OutlineNode node;
  final int depth;

  const OutlineCell({
    super.key,
    required this.node,
    required this.depth,
  });

  @override
  ConsumerState<OutlineCell> createState() => _OutlineCellState();
}

class _OutlineCellState extends ConsumerState<OutlineCell> {
  _DropZone? _activeDropZone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editorState = ref.watch(editorStateProvider);
    final isEditing = editorState.editingNodeId == widget.node.id;
    final isSelected = editorState.selectedNodeId == widget.node.id;
    final doc = ref.watch(documentProvider);
    final indent = widget.depth * 24.0;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.node.id,
      onAcceptWithDetails: (details) {
        final draggedId = details.data;
        switch (_activeDropZone) {
          case _DropZone.top:
            ref
                .read(documentProvider.notifier)
                .moveNodeBefore(draggedId, widget.node.id);
          case _DropZone.center:
            ref
                .read(documentProvider.notifier)
                .moveNodeInto(draggedId, widget.node.id);
          case _DropZone.bottom || null:
            ref
                .read(documentProvider.notifier)
                .moveNodeAfter(draggedId, widget.node.id);
        }
        setState(() => _activeDropZone = null);
      },
      onLeave: (_) => setState(() => _activeDropZone = null),
      onMove: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localPos = renderBox.globalToLocal(details.offset);
        final height = renderBox.size.height;
        final third = height / 3;

        final zone = localPos.dy < third
            ? _DropZone.top
            : localPos.dy > third * 2
                ? _DropZone.bottom
                : _DropZone.center;

        if (zone != _activeDropZone) {
          setState(() => _activeDropZone = zone);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDraggingOver = candidateData.isNotEmpty;
        final focusMode = ref.watch(focusModeProvider);
        final isActive = isSelected || isEditing;
        final dimmed = focusMode && !isActive;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: dimmed ? 0.25 : 1.0,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.06)
                : isDraggingOver && _activeDropZone == _DropZone.center
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : null,
            border: Border(
              top: BorderSide(
                color: isDraggingOver && _activeDropZone == _DropZone.top
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
              bottom: BorderSide(
                color: isDraggingOver && _activeDropZone == _DropZone.bottom
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withValues(alpha: 0.5),
                width: isDraggingOver && _activeDropZone == _DropZone.bottom
                    ? 2
                    : 0.5,
              ),
            ),
          ),
          child: InkWell(
            canRequestFocus: false,
            onTap: () {
              final currentEditing =
                  ref.read(editorStateProvider).editingNodeId;
              if (currentEditing != null &&
                  currentEditing != widget.node.id) {
                ref.read(editorStateProvider.notifier).clearEditing();
                ref.read(documentProvider.notifier).rebuildTree();
              }
              ref
                  .read(editorStateProvider.notifier)
                  .setSelectedNode(widget.node.id);
            },
            onDoubleTap: () {
              ref
                  .read(editorStateProvider.notifier)
                  .setEditingNode(widget.node.id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content area (indented) — takes remaining space
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: indent),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Draggable<String>(
                            data: widget.node.id,
                            feedback: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 300,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.cardTheme.color ??
                                      theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  widget.node.displayTitle,
                                  style: theme.textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _dragHandleIcon(theme),
                            ),
                            child: _dragHandleIcon(theme),
                          ),

                          if (widget.node.isCollapsible)
                            _CollapseToggle(
                              isCollapsed: widget.node.isCollapsed,
                              onToggle: () {
                                ref
                                    .read(documentProvider.notifier)
                                    .toggleCollapse(widget.node.id);
                              },
                            )
                          else
                            const SizedBox(width: 24),

                          if (widget.node.isCheckbox)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 8, right: 4),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: Focus(
                                  canRequestFocus: false,
                                  descendantsAreFocusable: false,
                                  child: Checkbox(
                                    value: widget.node.isChecked,
                                    onChanged: (_) {
                                      ref
                                          .read(documentProvider.notifier)
                                          .toggleChecked(widget.node.id);
                                    },
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                            ),

                          Expanded(
                            child: isEditing
                                ? CellEditor(
                                    content: widget.node.content,
                                    onChanged: (value) {
                                      ref
                                          .read(documentProvider.notifier)
                                          .updateNodeContent(
                                              widget.node.id, value);
                                    },
                                    onCommit: () {
                                      ref
                                          .read(editorStateProvider.notifier)
                                          .clearEditing();
                                      ref
                                          .read(documentProvider.notifier)
                                          .rebuildTree();
                                    },
                                    onCommitAndContinue: () {
                                      ref
                                          .read(editorStateProvider.notifier)
                                          .clearEditing();
                                      ref
                                          .read(documentProvider.notifier)
                                          .rebuildTree();
                                      ref
                                          .read(documentProvider.notifier)
                                          .addNodeAfter(widget.node.id);
                                    },
                                    onDelete: widget.node.content.isEmpty
                                        ? () {
                                            ref
                                                .read(
                                                    documentProvider.notifier)
                                                .deleteNode(widget.node.id);
                                            ref
                                                .read(editorStateProvider
                                                    .notifier)
                                                .clearEditing();
                                          }
                                        : null,
                                  )
                                : CellRenderer(
                                    content: widget.node.content,
                                    isCollapsed: widget.node.isCollapsed &&
                                        widget.node.hasBody,
                                    documentBasePath: doc.filePath,
                                    fontScale: ref.watch(fontScaleProvider),
                                    onTap: () {
                                      ref
                                          .read(editorStateProvider.notifier)
                                          .setEditingNode(widget.node.id);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Column values — fixed width, not affected by indent
                  for (final col in doc.columns)
                    SizedBox(
                      width: kColumnWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: isEditing
                            ? _EditableColumnCell(
                                value:
                                    widget.node.columnValues[col.name] ?? '',
                                onChanged: (v) {
                                  ref
                                      .read(documentProvider.notifier)
                                      .setColumnValue(
                                          widget.node.id, col.name, v);
                                },
                                theme: theme,
                              )
                            : Text(
                                widget.node.columnValues[col.name] ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ),

                  // Context menu
                  _CellMenu(node: widget.node),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _dragHandleIcon(ThemeData theme) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Icon(
          Icons.drag_indicator,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

enum _DropZone { top, center, bottom }

class _CollapseToggle extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _CollapseToggle({
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: AnimatedRotation(
          turns: isCollapsed ? -0.25 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.expand_more,
            size: 18,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _EditableColumnCell extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final ThemeData theme;

  const _EditableColumnCell({
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  State<_EditableColumnCell> createState() => _EditableColumnCellState();
}

class _EditableColumnCellState extends State<_EditableColumnCell> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: widget.theme.textTheme.bodySmall,
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: widget.theme.dividerColor),
        ),
        hintText: '...',
        hintStyle: TextStyle(
          color:
              widget.theme.colorScheme.onSurface.withValues(alpha: 0.3),
          fontSize: 12,
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _CellMenu extends ConsumerWidget {
  final OutlineNode node;

  const _CellMenu({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: PopupMenuButton<String>(
      iconSize: 16,
      icon: Icon(
        Icons.more_vert,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      padding: EdgeInsets.zero,
      onSelected: (action) {
        final notifier = ref.read(documentProvider.notifier);
        switch (action) {
          case 'add_after':
            notifier.addNodeAfter(node.id);
          case 'add_child':
            notifier.addNodeAsChild(node.id,
                headingLevel: node.headingLevel + 1);
          case 'indent':
            notifier.indentNode(node.id);
          case 'outdent':
            notifier.outdentNode(node.id);
          case 'toggle_checkbox':
            notifier.toggleCheckbox(node.id);
          case 'h1':
            notifier.setHeadingLevel(node.id, 1);
          case 'h2':
            notifier.setHeadingLevel(node.id, 2);
          case 'h3':
            notifier.setHeadingLevel(node.id, 3);
          case 'body':
            notifier.setHeadingLevel(node.id, 0);
          case 'delete':
            notifier.deleteNode(node.id);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'add_after', child: Text('Add Below')),
        const PopupMenuItem(value: 'add_child', child: Text('Add Child')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'h1', child: Text('Heading 1')),
        const PopupMenuItem(value: 'h2', child: Text('Heading 2')),
        const PopupMenuItem(value: 'h3', child: Text('Heading 3')),
        const PopupMenuItem(value: 'body', child: Text('Body Text')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'indent', child: Text('Indent')),
        const PopupMenuItem(value: 'outdent', child: Text('Outdent')),
        PopupMenuItem(
          value: 'toggle_checkbox',
          child:
              Text(node.isCheckbox ? 'Remove Checkbox' : 'Add Checkbox'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
    );
  }
}
