import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/document_provider.dart';
import '../../../services/file_service.dart';

class OutlineKeyboardShortcuts extends ConsumerWidget {
  final Widget child;
  final FileService fileService;

  const OutlineKeyboardShortcuts({
    super.key,
    required this.child,
    required this.fileService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: {
        // File operations
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN):
            const _NewDocumentIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const _NewDocumentIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyO):
            const _OpenFileIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyO):
            const _OpenFileIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS):
            const _SaveFileIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            const _SaveFileIntent(),

        // Undo / Redo
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
            const _UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            const _UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift,
                LogicalKeyboardKey.keyZ):
            const _RedoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
                LogicalKeyboardKey.keyZ):
            const _RedoIntent(),

        // Node operations
        LogicalKeySet(LogicalKeyboardKey.tab): const _IndentIntent(),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
            const _OutdentIntent(),
        LogicalKeySet(
                LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowUp):
            const _MoveUpIntent(),
        LogicalKeySet(
                LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp):
            const _MoveUpIntent(),
        LogicalKeySet(
                LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowDown):
            const _MoveDownIntent(),
        LogicalKeySet(
                LogicalKeyboardKey.control, LogicalKeyboardKey.arrowDown):
            const _MoveDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _AddNodeIntent(),
      },
      child: Actions(
        actions: {
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              ref.read(documentProvider.notifier).undo();
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              ref.read(documentProvider.notifier).redo();
              return null;
            },
          ),
          _NewDocumentIntent: CallbackAction<_NewDocumentIntent>(
            onInvoke: (_) {
              ref.read(documentProvider.notifier).newDocument();
              final doc = ref.read(documentProvider);
              ref.read(editorStateProvider.notifier).resetTo(
                    doc.nodes.isNotEmpty ? doc.nodes.first.id : null,
                  );
              return null;
            },
          ),
          _OpenFileIntent: CallbackAction<_OpenFileIntent>(
            onInvoke: (_) async {
              final loaded = await fileService.openFile();
              if (loaded != null) {
                ref.read(documentProvider.notifier).loadDocument(loaded);
                ref.read(editorStateProvider.notifier).resetTo(
                      loaded.nodes.isNotEmpty ? loaded.nodes.first.id : null,
                    );
              }
              return null;
            },
          ),
          _SaveFileIntent: CallbackAction<_SaveFileIntent>(
            onInvoke: (_) async {
              final doc = ref.read(documentProvider);
              final path = await fileService.saveFile(doc);
              if (path != null) {
                ref.read(documentProvider.notifier).setFilePath(path);
              }
              return null;
            },
          ),
          _IndentIntent: CallbackAction<_IndentIntent>(
            onInvoke: (_) {
              final selected = ref.read(editorStateProvider).selectedNodeId;
              if (selected != null && ref.read(editorStateProvider).editingNodeId == null) {
                ref.read(documentProvider.notifier).indentNode(selected);
              }
              return null;
            },
          ),
          _OutdentIntent: CallbackAction<_OutdentIntent>(
            onInvoke: (_) {
              final selected = ref.read(editorStateProvider).selectedNodeId;
              if (selected != null && ref.read(editorStateProvider).editingNodeId == null) {
                ref.read(documentProvider.notifier).outdentNode(selected);
              }
              return null;
            },
          ),
          _MoveUpIntent: CallbackAction<_MoveUpIntent>(
            onInvoke: (_) {
              final selected = ref.read(editorStateProvider).selectedNodeId;
              if (selected != null) {
                ref.read(documentProvider.notifier).moveNodeUp(selected);
              }
              return null;
            },
          ),
          _MoveDownIntent: CallbackAction<_MoveDownIntent>(
            onInvoke: (_) {
              final selected = ref.read(editorStateProvider).selectedNodeId;
              if (selected != null) {
                ref.read(documentProvider.notifier).moveNodeDown(selected);
              }
              return null;
            },
          ),
          _AddNodeIntent: CallbackAction<_AddNodeIntent>(
            onInvoke: (_) {
              final editorState = ref.read(editorStateProvider);
              if (editorState.editingNodeId != null) {
                // If we're nominally editing but Enter reached the Shortcuts
                // widget (TextField doesn't have focus yet), commit the current
                // cell and create a new node after it.
                ref.read(editorStateProvider.notifier).clearEditing();
                ref.read(documentProvider.notifier).rebuildTree();
              }
              ref.read(documentProvider.notifier).addNodeAfterActive();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _NewDocumentIntent extends Intent {
  const _NewDocumentIntent();
}

class _OpenFileIntent extends Intent {
  const _OpenFileIntent();
}

class _SaveFileIntent extends Intent {
  const _SaveFileIntent();
}

class _IndentIntent extends Intent {
  const _IndentIntent();
}

class _OutdentIntent extends Intent {
  const _OutdentIntent();
}

class _MoveUpIntent extends Intent {
  const _MoveUpIntent();
}

class _MoveDownIntent extends Intent {
  const _MoveDownIntent();
}

class _AddNodeIntent extends Intent {
  const _AddNodeIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}
