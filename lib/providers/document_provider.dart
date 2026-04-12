import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/outline_document.dart';
import '../models/outline_node.dart';
import '../models/column_def.dart';
import '../utils/tree_utils.dart';

final documentProvider =
    NotifierProvider<DocumentNotifier, OutlineDocument>(DocumentNotifier.new);

class DocumentNotifier extends Notifier<OutlineDocument> {
  static const _maxHistory = 100;

  final List<OutlineDocument> _undoStack = [];
  final List<OutlineDocument> _redoStack = [];
  String? _editingNodeId;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void _pushHistory() {
    _undoStack.add(state);
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _resetHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _editingNodeId = null;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(state);
    state = _undoStack.removeLast();
    ref.read(editorStateProvider.notifier).clearEditing();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(state);
    state = _redoStack.removeLast();
    ref.read(editorStateProvider.notifier).clearEditing();
  }

  @override
  OutlineDocument build() {
    return OutlineDocument(
      nodes: [
        OutlineNode.create(content: '# New Outline', headingLevel: 1),
      ],
    );
  }

  void newDocument() {
    _resetHistory();
    state = OutlineDocument(
      nodes: [
        OutlineNode.create(content: '# New Outline', headingLevel: 1),
      ],
    );
  }

  void loadDocument(OutlineDocument doc) {
    _resetHistory();
    state = doc;
  }

  void setFilePath(String? path) {
    state = state.copyWith(filePath: path, isDirty: false);
  }

  void markClean() {
    state = state.copyWith(isDirty: false);
  }

  void _mutate(List<OutlineNode> Function(List<OutlineNode>) fn) {
    _pushHistory();
    state = state.copyWith(nodes: fn(state.nodes), isDirty: true);
  }

  // --- Node CRUD ---

  void addNodeAfter(String afterId, {int headingLevel = 0}) {
    final newNode = OutlineNode.create(headingLevel: headingLevel);
    _mutate((nodes) => insertAfter(nodes, afterId, newNode));
    ref.read(editorStateProvider.notifier).setEditingNode(newNode.id);
  }

  void addNodeAsChild(String parentId, {int headingLevel = 0}) {
    final newNode = OutlineNode.create(headingLevel: headingLevel);
    _mutate((nodes) => addChild(nodes, parentId, newNode));
    ref.read(editorStateProvider.notifier).setEditingNode(newNode.id);
  }

  void addNodeAtEnd({int headingLevel = 0}) {
    _pushHistory();
    final newNode = OutlineNode.create(headingLevel: headingLevel);
    state = state.copyWith(
      nodes: [...state.nodes, newNode],
      isDirty: true,
    );
    ref.read(editorStateProvider.notifier).setEditingNode(newNode.id);
  }

  /// Add a node visually right below the currently active (selected) node.
  /// If the selected node has visible children, the new node becomes its first
  /// child so it appears directly below in the rendered list. Otherwise it is
  /// inserted as a sibling after the selected node.
  void addNodeAfterActive({int headingLevel = 0}) {
    final editorState = ref.read(editorStateProvider);
    var targetId = editorState.selectedNodeId;

    if (targetId != null && findNode(state.nodes, targetId) == null) {
      targetId = null;
    }

    if (targetId == null) {
      final flat = flattenTree(state.nodes);
      targetId = flat.isNotEmpty ? flat.last.id : null;
    }

    if (targetId != null) {
      final target = findNode(state.nodes, targetId);
      if (target != null &&
          !target.isCollapsed &&
          target.children.isNotEmpty) {
        final newNode = OutlineNode.create(headingLevel: headingLevel);
        _mutate((nodes) => prependChild(nodes, targetId!, newNode));
        ref.read(editorStateProvider.notifier).setEditingNode(newNode.id);
      } else {
        addNodeAfter(targetId, headingLevel: headingLevel);
      }
    } else {
      addNodeAtEnd(headingLevel: headingLevel);
    }
  }

  void updateNodeContent(String id, String content) {
    // Only push undo snapshot when editing a *different* node to avoid
    // flooding the stack on every keystroke.
    if (_editingNodeId != id) {
      _pushHistory();
      _editingNodeId = id;
    }
    final newLevel = detectHeadingLevel(content);
    state = state.copyWith(
      nodes: updateNode(
        state.nodes,
        id,
        (n) => n.copyWith(content: content, headingLevel: newLevel),
      ),
      isDirty: true,
    );
  }

  /// Rebuild the tree structure based on heading levels.
  /// Called when editing is committed to restructure nesting.
  void rebuildTree() {
    final flat = flattenTree(state.nodes);
    final rebuilt = buildTreeFromFlat(flat);
    state = state.copyWith(nodes: rebuilt, isDirty: true);
    _editingNodeId = null;
  }

  void deleteNode(String id) {
    _mutate((nodes) => removeNode(nodes, id));
  }

  // --- Heading level ---

  void setHeadingLevel(String id, int level) {
    _mutate(
      (nodes) => updateNode(nodes, id, (n) => n.copyWith(headingLevel: level)),
    );
  }

  void indentNode(String id) {
    final node = findNode(state.nodes, id);
    if (node == null) return;
    if (node.headingLevel < 6) {
      setHeadingLevel(id, node.headingLevel + 1);
    }
  }

  void outdentNode(String id) {
    final node = findNode(state.nodes, id);
    if (node == null) return;
    if (node.headingLevel > 0) {
      setHeadingLevel(id, node.headingLevel - 1);
    }
  }

  // --- Collapse (view-only, not undoable) ---

  void toggleCollapse(String id) {
    state = state.copyWith(
      nodes: updateNode(
          state.nodes, id, (n) => n.copyWith(isCollapsed: !n.isCollapsed)),
    );
  }

  void collapseAll() {
    state = state.copyWith(nodes: setAllCollapsed(state.nodes, true));
  }

  void expandAll() {
    state = state.copyWith(nodes: setAllCollapsed(state.nodes, false));
  }

  // --- Checkbox ---

  void toggleCheckbox(String id) {
    _mutate(
      (nodes) =>
          updateNode(nodes, id, (n) => n.copyWith(isCheckbox: !n.isCheckbox)),
    );
  }

  void toggleChecked(String id) {
    _mutate(
      (nodes) =>
          updateNode(nodes, id, (n) => n.copyWith(isChecked: !n.isChecked)),
    );
  }

  // --- Columns ---

  void addColumn(String name) {
    _pushHistory();
    state = state.copyWith(
      columns: [...state.columns, ColumnDef(name: name)],
      isDirty: true,
    );
  }

  void removeColumn(String name) {
    _pushHistory();
    final cleanedNodes = _removeColumnFromNodes(state.nodes, name);
    state = state.copyWith(
      columns: state.columns.where((c) => c.name != name).toList(),
      nodes: cleanedNodes,
      isDirty: true,
    );
  }

  List<OutlineNode> _removeColumnFromNodes(
    List<OutlineNode> nodes,
    String columnName,
  ) {
    return nodes.map((n) {
      final newCols = Map<String, String>.from(n.columnValues)
        ..remove(columnName);
      return n.copyWith(
        columnValues: newCols,
        children: _removeColumnFromNodes(n.children, columnName),
      );
    }).toList();
  }

  void setColumnValue(String nodeId, String columnName, String value) {
    _mutate(
      (nodes) => updateNode(nodes, nodeId, (n) {
        final newCols = Map<String, String>.from(n.columnValues);
        newCols[columnName] = value;
        return n.copyWith(columnValues: newCols);
      }),
    );
  }

  void renameColumn(String oldName, String newName) {
    _pushHistory();
    state = state.copyWith(
      columns: state.columns
          .map((c) => c.name == oldName ? c.copyWith(name: newName) : c)
          .toList(),
      isDirty: true,
    );
  }

  // --- Reorder / Drag & Drop ---

  void moveNodeBefore(String nodeId, String beforeId) {
    if (nodeId == beforeId) return;
    if (isDescendant(state.nodes, nodeId, beforeId)) return;
    final node = findNode(state.nodes, nodeId);
    final target = findNode(state.nodes, beforeId);
    if (node == null || target == null) return;
    final adjusted = retargetHeadingLevel(node, target.headingLevel);
    _mutate((nodes) {
      final removed = removeNode(nodes, nodeId);
      return insertBefore(removed, beforeId, adjusted);
    });
  }

  void moveNodeAfter(String nodeId, String afterId) {
    if (nodeId == afterId) return;
    if (isDescendant(state.nodes, nodeId, afterId)) return;
    final node = findNode(state.nodes, nodeId);
    final target = findNode(state.nodes, afterId);
    if (node == null || target == null) return;
    final adjusted = retargetHeadingLevel(node, target.headingLevel);
    _mutate((nodes) {
      final removed = removeNode(nodes, nodeId);
      return insertAfter(removed, afterId, adjusted);
    });
  }

  void moveNodeInto(String nodeId, String parentId) {
    if (nodeId == parentId) return;
    if (isDescendant(state.nodes, nodeId, parentId)) return;
    final node = findNode(state.nodes, nodeId);
    if (node == null) return;
    final parent = findNode(state.nodes, parentId);
    if (parent == null) return;
    // Nesting one level below the target: parent+1 for headings; body parents
    // already promote their children via heading level 1.
    final newLevel = (parent.headingLevel + 1).clamp(1, 6);
    final adjusted = retargetHeadingLevel(node, newLevel);
    _mutate((nodes) {
      final removed = removeNode(nodes, nodeId);
      return addChild(removed, parentId, adjusted);
    });
  }

  void moveNodeUp(String id) {
    final flat = flattenTree(state.nodes);
    final idx = flat.indexWhere((n) => n.id == id);
    if (idx <= 0) return;
    moveNodeBefore(id, flat[idx - 1].id);
  }

  void moveNodeDown(String id) {
    final flat = flattenTree(state.nodes);
    final idx = flat.indexWhere((n) => n.id == id);
    if (idx < 0 || idx >= flat.length - 1) return;
    moveNodeAfter(id, flat[idx + 1].id);
  }
}

// --- Editor State ---

final editorStateProvider =
    NotifierProvider<EditorStateNotifier, EditorState>(EditorStateNotifier.new);

class EditorState {
  final String? editingNodeId;
  final String? selectedNodeId;

  const EditorState({this.editingNodeId, this.selectedNodeId});

  EditorState copyWith({
    String? editingNodeId,
    String? selectedNodeId,
    bool clearEditing = false,
    bool clearSelected = false,
  }) {
    return EditorState(
      editingNodeId: clearEditing ? null : (editingNodeId ?? this.editingNodeId),
      selectedNodeId:
          clearSelected ? null : (selectedNodeId ?? this.selectedNodeId),
    );
  }
}

class EditorStateNotifier extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  void setEditingNode(String? id) {
    state = EditorState(editingNodeId: id, selectedNodeId: id);
  }

  void setSelectedNode(String? id) {
    state = state.copyWith(selectedNodeId: id, clearSelected: id == null);
  }

  void clearEditing() {
    state = EditorState(selectedNodeId: state.selectedNodeId);
  }

  void resetTo(String? nodeId) {
    state = EditorState(selectedNodeId: nodeId);
  }
}
