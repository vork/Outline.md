import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../providers/document_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/file_service.dart';
import '../../utils/tree_utils.dart';
import '../sidebar/sidebar_panel.dart';
import '../toolbar/toolbar.dart';
import 'helpers/keyboard_shortcuts.dart';
import 'widgets/column_header.dart';
import 'widgets/node_tree_view.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _fileService = FileService();
  final _scrollController = ScrollController();
  final _editorFocusNode = FocusNode(debugLabel: 'EditorContent');
  final Map<String, GlobalKey> _nodeKeys = {};
  bool _isDragOver = false;

  GlobalKey _keyForNode(String nodeId) {
    return _nodeKeys.putIfAbsent(nodeId, () => GlobalKey());
  }

  void _scrollToNode(String nodeId) {
    // Wait two frames to ensure the widget tree has rebuilt and laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _nodeKeys[nodeId];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.3,
          );
        }
      });
    });
  }

  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    setState(() => _isDragOver = false);
    for (final file in details.files) {
      final path = file.path;
      if (path.endsWith('.md') || path.endsWith('.markdown') || path.endsWith('.txt')) {
        try {
          final doc = await _fileService.loadFromPath(path);
          ref.read(documentProvider.notifier).loadDocument(doc);
          ref.read(editorStateProvider.notifier).resetTo(
                doc.nodes.isNotEmpty ? doc.nodes.first.id : null,
              );
        } catch (_) {}
        return;
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final editorState = ref.read(editorStateProvider);
    final isEditing = editorState.editingNodeId != null;
    final key = event.logicalKey;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final hasCmdCtrl = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    if (isEditing || hasCmdCtrl) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowUp) {
      _selectAdjacentNode(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _selectAdjacentNode(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && isShift) {
      final selected = editorState.selectedNodeId;
      if (selected != null) {
        ref.read(editorStateProvider.notifier).setEditingNode(selected);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      ref.read(documentProvider.notifier).addNodeAfterActive();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _deleteSelectedNode();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab && isShift) {
      final selected = editorState.selectedNodeId;
      if (selected != null) {
        ref.read(documentProvider.notifier).outdentNode(selected);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      final selected = editorState.selectedNodeId;
      if (selected != null) {
        ref.read(documentProvider.notifier).indentNode(selected);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _selectAdjacentNode(int delta) {
    final doc = ref.read(documentProvider);
    final visible = visibleNodes(doc.nodes).map((e) => e.$1).toList();
    if (visible.isEmpty) return;
    final selected = ref.read(editorStateProvider).selectedNodeId;
    final idx = visible.indexWhere((n) => n.id == selected);
    if (idx < 0) {
      ref
          .read(editorStateProvider.notifier)
          .setSelectedNode(delta > 0 ? visible.first.id : visible.last.id);
    } else {
      final next = idx + delta;
      if (next >= 0 && next < visible.length) {
        ref
            .read(editorStateProvider.notifier)
            .setSelectedNode(visible[next].id);
      }
    }
  }

  void _deleteSelectedNode() {
    final editorState = ref.read(editorStateProvider);
    final selected = editorState.selectedNodeId;
    if (selected == null) return;
    final doc = ref.read(documentProvider);
    final visible = visibleNodes(doc.nodes).map((e) => e.$1).toList();
    final idx = visible.indexWhere((n) => n.id == selected);
    String? nextId;
    if (idx >= 0) {
      if (idx + 1 < visible.length) {
        nextId = visible[idx + 1].id;
      } else if (idx > 0) {
        nextId = visible[idx - 1].id;
      }
    }
    ref.read(documentProvider.notifier).deleteNode(selected);
    ref.read(editorStateProvider.notifier).setSelectedNode(nextId);
  }

  @override
  void initState() {
    super.initState();
    _loadInitialFile();
    // Listen for files opened while the app is already running (macOS)
    onFileOpened = _openFileFromPath;
  }

  Future<void> _loadInitialFile() async {
    final path = initialFilePath;
    if (path == null) return;
    initialFilePath = null; // consume it
    await _openFileFromPath(path);
  }

  Future<void> _openFileFromPath(String path) async {
    try {
      final doc = await _fileService.loadFromPath(path);
      ref.read(documentProvider.notifier).loadDocument(doc);
      ref.read(editorStateProvider.notifier).resetTo(
            doc.nodes.isNotEmpty ? doc.nodes.first.id : null,
          );
    } catch (_) {}
  }

  @override
  void dispose() {
    onFileOpened = null;
    _scrollController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(documentProvider);
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    final theme = Theme.of(context);

    // Reclaim focus on the editor area when editing is cleared, so that
    // keyboard shortcuts (like Enter → add node) keep working.
    ref.listen(editorStateProvider, (previous, next) {
      if (previous?.editingNodeId != null && next.editingNodeId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_editorFocusNode.hasPrimaryFocus) {
            _editorFocusNode.requestFocus();
          }
        });
      }
      if (next.editingNodeId == null &&
          next.selectedNodeId != null &&
          next.selectedNodeId != previous?.selectedNodeId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_editorFocusNode.hasPrimaryFocus) {
            _editorFocusNode.requestFocus();
          }
        });
        _scrollToNode(next.selectedNodeId!);
      }
    });

    return OutlineKeyboardShortcuts(
      fileService: _fileService,
      child: DropTarget(
        onDragEntered: (_) => setState(() => _isDragOver = true),
        onDragExited: (_) => setState(() => _isDragOver = false),
        onDragDone: _handleDroppedFiles,
        child: Stack(
          children: [
            Scaffold(
              body: Column(
                children: [
                  OutlineToolbar(fileService: _fileService),
                  Expanded(
                    child: Row(
                      children: [
                        if (sidebarVisible) ...[
                          SidebarPanel(
                            onItemTap: _scrollToNode,
                            width: ref.watch(sidebarWidthProvider),
                          ),
                          _SidebarResizeHandle(),
                        ],
                        Expanded(
                          child: Listener(
                            onPointerDown: (_) {
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                if (mounted &&
                                    ref.read(editorStateProvider).editingNodeId ==
                                        null &&
                                    !_editorFocusNode.hasPrimaryFocus) {
                                  _editorFocusNode.requestFocus();
                                }
                              });
                            },
                            child: Focus(
                              focusNode: _editorFocusNode,
                              autofocus: true,
                              onKeyEvent: _handleKeyEvent,
                              child: GestureDetector(
                              onTap: () {
                                final wasEditing = ref.read(editorStateProvider).editingNodeId != null;
                                ref.read(editorStateProvider.notifier).clearEditing();
                                if (wasEditing) {
                                  ref.read(documentProvider.notifier).rebuildTree();
                                }
                                _editorFocusNode.requestFocus();
                              },
                              behavior: HitTestBehavior.translucent,
                              child: Column(
                                children: [
                                  const ColumnHeader(),
                                  Expanded(
                                    child: doc.nodes.isEmpty
                                        ? _EmptyState(
                                            onAddNode: () {
                                              ref
                                                  .read(documentProvider.notifier)
                                                  .addNodeAtEnd(headingLevel: 1);
                                            },
                                          )
                                        : NodeTreeView(
                                            nodes: doc.nodes,
                                            scrollController: _scrollController,
                                            nodeKeyFactory: _keyForNode,
                                          ),
                                  ),
                                  _BottomBar(theme: theme),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isDragOver)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(alpha: 0.15),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.file_open_outlined,
                                color: theme.colorScheme.primary, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Drop .md file to open',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddNode;

  const _EmptyState({required this.onAddNode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.article_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Start your outline',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a heading to begin, or open an existing .md file',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddNode,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Heading'),
          ),
        ],
      ),
    );
  }
}

class _SidebarResizeHandle extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends ConsumerState<_SidebarResizeHandle> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final current = ref.read(sidebarWidthProvider);
          final newWidth = (current + details.delta.dx)
              .clamp(minSidebarWidth, maxSidebarWidth);
          ref.read(sidebarWidthProvider.notifier).state = newWidth;
        },
        child: Container(
          width: 4,
          color: _isHovering
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final ThemeData theme;

  const _BottomBar({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final doc = ref.watch(documentProvider);
        final stats = _computeStats(doc.nodes);

        final statStyle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          fontSize: 11,
        );
        final divider = Text(
          '  |  ',
          style: statStyle?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              Text('${stats.nodeCount} items', style: statStyle),
              divider,
              Text('${_formatNumber(stats.wordCount)} words', style: statStyle),
              divider,
              Text('${_formatNumber(stats.charCount)} chars', style: statStyle),
              divider,
              Text('${stats.lineCount} lines', style: statStyle),
              divider,
              Text('~${stats.readTimeMinutes} min read', style: statStyle),
              const Spacer(),
              // Add node button
              TextButton.icon(
                onPressed: () {
                  ref.read(documentProvider.notifier).addNodeAfterActive();
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _DocStats _computeStats(List nodes) {
    final buffer = StringBuffer();
    _collectContent(nodes, buffer);
    final text = buffer.toString();

    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).length;
    final chars = text.length;
    final lines = text.isEmpty ? 0 : text.split('\n').length;
    final nodeCount = _countNodes(nodes);
    final readTime = (words / 200).ceil().clamp(1, 9999);

    return _DocStats(
      nodeCount: nodeCount,
      wordCount: words,
      charCount: chars,
      lineCount: lines,
      readTimeMinutes: text.trim().isEmpty ? 0 : readTime,
    );
  }

  void _collectContent(List nodes, StringBuffer buffer) {
    for (final node in nodes) {
      final content = (node as dynamic).content as String;
      if (content.isNotEmpty) {
        buffer.writeln(content);
      }
      if (node.children.isNotEmpty) {
        _collectContent(node.children, buffer);
      }
    }
  }

  int _countNodes(List nodes) {
    int count = 0;
    for (final node in nodes) {
      count++;
      if ((node as dynamic).children.isNotEmpty) {
        count += _countNodes(node.children);
      }
    }
    return count;
  }

  String _formatNumber(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k < 10 ? 1 : 0)}k';
    }
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

class _DocStats {
  final int nodeCount;
  final int wordCount;
  final int charCount;
  final int lineCount;
  final int readTimeMinutes;

  const _DocStats({
    required this.nodeCount,
    required this.wordCount,
    required this.charCount,
    required this.lineCount,
    required this.readTimeMinutes,
  });
}
