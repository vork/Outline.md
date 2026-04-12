import '../models/outline_node.dart';

/// Flatten a tree of nodes into a flat list (depth-first).
List<OutlineNode> flattenTree(List<OutlineNode> nodes) {
  final result = <OutlineNode>[];
  for (final node in nodes) {
    result.add(node);
    if (node.children.isNotEmpty) {
      result.addAll(flattenTree(node.children));
    }
  }
  return result;
}

/// Get the depth of a node in the tree.
int nodeDepth(List<OutlineNode> roots, String nodeId) {
  int search(List<OutlineNode> nodes, int depth) {
    for (final node in nodes) {
      if (node.id == nodeId) return depth;
      final found = search(node.children, depth + 1);
      if (found >= 0) return found;
    }
    return -1;
  }
  return search(roots, 0);
}

/// Find a node by ID in the tree.
OutlineNode? findNode(List<OutlineNode> nodes, String id) {
  for (final node in nodes) {
    if (node.id == id) return node;
    final found = findNode(node.children, id);
    if (found != null) return found;
  }
  return null;
}

/// Find the parent of a node by ID.
OutlineNode? findParent(List<OutlineNode> nodes, String childId) {
  for (final node in nodes) {
    for (final child in node.children) {
      if (child.id == childId) return node;
    }
    final found = findParent(node.children, childId);
    if (found != null) return found;
  }
  return null;
}

/// Remove a node from the tree and return the updated tree.
List<OutlineNode> removeNode(List<OutlineNode> nodes, String id) {
  return nodes
      .where((n) => n.id != id)
      .map((n) => n.copyWith(children: removeNode(n.children, id)))
      .toList();
}

/// Update a node in the tree by ID.
List<OutlineNode> updateNode(
  List<OutlineNode> nodes,
  String id,
  OutlineNode Function(OutlineNode) updater,
) {
  return nodes.map((n) {
    if (n.id == id) return updater(n);
    return n.copyWith(children: updateNode(n.children, id, updater));
  }).toList();
}

/// Insert a node after another node at the same level.
List<OutlineNode> insertAfter(
  List<OutlineNode> nodes,
  String afterId,
  OutlineNode newNode,
) {
  final result = <OutlineNode>[];
  for (final node in nodes) {
    if (node.id == afterId) {
      result.add(node);
      result.add(newNode);
    } else {
      result.add(
        node.copyWith(children: insertAfter(node.children, afterId, newNode)),
      );
    }
  }
  return result;
}

/// Insert a node before another node at the same level.
List<OutlineNode> insertBefore(
  List<OutlineNode> nodes,
  String beforeId,
  OutlineNode newNode,
) {
  final result = <OutlineNode>[];
  for (final node in nodes) {
    if (node.id == beforeId) {
      result.add(newNode);
      result.add(node);
    } else {
      result.add(
        node.copyWith(
          children: insertBefore(node.children, beforeId, newNode),
        ),
      );
    }
  }
  return result;
}

/// Add a node as a child of a target node (appends at end).
List<OutlineNode> addChild(
  List<OutlineNode> nodes,
  String parentId,
  OutlineNode child,
) {
  return nodes.map((n) {
    if (n.id == parentId) {
      return n.copyWith(children: [...n.children, child]);
    }
    return n.copyWith(children: addChild(n.children, parentId, child));
  }).toList();
}

/// Add a node as the first child of a target node (prepends at start).
List<OutlineNode> prependChild(
  List<OutlineNode> nodes,
  String parentId,
  OutlineNode child,
) {
  return nodes.map((n) {
    if (n.id == parentId) {
      return n.copyWith(children: [child, ...n.children]);
    }
    return n.copyWith(children: prependChild(n.children, parentId, child));
  }).toList();
}

/// Check if a node is a descendant of another node.
bool isDescendant(List<OutlineNode> nodes, String ancestorId, String nodeId) {
  final ancestor = findNode(nodes, ancestorId);
  if (ancestor == null) return false;
  return findNode(ancestor.children, nodeId) != null;
}

/// Collect all visible nodes (respecting collapse state).
List<(OutlineNode, int)> visibleNodes(List<OutlineNode> nodes, [int depth = 0]) {
  final result = <(OutlineNode, int)>[];
  for (final node in nodes) {
    result.add((node, depth));
    if (!node.isCollapsed && node.children.isNotEmpty) {
      result.addAll(visibleNodes(node.children, depth + 1));
    }
  }
  return result;
}

/// Set collapse state for all nodes in the tree.
List<OutlineNode> setAllCollapsed(List<OutlineNode> nodes, bool collapsed) {
  return nodes.map((n) {
    return n.copyWith(
      isCollapsed: n.hasChildren ? collapsed : n.isCollapsed,
      children: setAllCollapsed(n.children, collapsed),
    );
  }).toList();
}

/// Detect heading level from markdown content.
/// Returns 0 for body text, 1-6 for headings.
int detectHeadingLevel(String content) {
  final firstLine = content.split('\n').first.trimLeft();
  final match = RegExp(r'^(#{1,6})\s').firstMatch(firstLine);
  if (match != null) return match.group(1)!.length;
  return 0;
}

/// Rewrite the first line's `#` prefix so it matches [level].
/// [level] == 0 strips the prefix; 1-6 replaces/adds it.
String syncHeadingPrefix(String content, int level) {
  if (content.isEmpty) {
    return level > 0 ? '${'#' * level} ' : content;
  }
  final newlineIdx = content.indexOf('\n');
  final firstLine =
      newlineIdx >= 0 ? content.substring(0, newlineIdx) : content;
  final rest = newlineIdx >= 0 ? content.substring(newlineIdx) : '';
  final stripped = firstLine.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
  final clamped = level.clamp(0, 6);
  final newFirst =
      clamped > 0 ? '${'#' * clamped} $stripped' : stripped;
  return '$newFirst$rest';
}

/// Return [node] with its heading level retargeted to [newLevel], shifting all
/// heading descendants by the same delta so the nested structure stays
/// consistent. Body-level (0) descendants are left untouched.
OutlineNode retargetHeadingLevel(OutlineNode node, int newLevel) {
  final clamped = newLevel.clamp(0, 6);
  final delta = clamped - node.headingLevel;
  if (delta == 0) return node;
  return _shiftHeadingLevels(node, delta, isRoot: true, rootLevel: clamped);
}

OutlineNode _shiftHeadingLevels(
  OutlineNode node,
  int delta, {
  bool isRoot = false,
  int rootLevel = 0,
}) {
  final newLevel = isRoot
      ? rootLevel
      : node.headingLevel > 0
          ? (node.headingLevel + delta).clamp(1, 6)
          : 0;
  final newContent = node.headingLevel > 0 || newLevel > 0
      ? syncHeadingPrefix(node.content, newLevel)
      : node.content;
  return node.copyWith(
    headingLevel: newLevel,
    content: newContent,
    children:
        node.children.map((c) => _shiftHeadingLevels(c, delta)).toList(),
  );
}

/// Rebuild tree hierarchy from a flat list of nodes based on heading levels.
/// Preserves collapse state from the old tree.
List<OutlineNode> buildTreeFromFlat(List<OutlineNode> flat) {
  if (flat.isEmpty) return [];

  // Strip children from all nodes (we rebuild the tree)
  final stripped = flat.map((n) => n.copyWith(children: const [])).toList();

  final roots = <OutlineNode>[];
  final stack = <_StackEntry>[];

  for (final node in stripped) {
    final level = node.headingLevel;

    if (level == 0) {
      // Body text attaches to the most recent heading
      if (stack.isNotEmpty) {
        stack.last.children.add(node);
      } else {
        roots.add(node);
      }
    } else {
      // Pop stack until we find a parent with strictly lower heading level
      while (stack.isNotEmpty && stack.last.level >= level) {
        final completed = stack.removeLast();
        final finishedNode =
            completed.node.copyWith(children: completed.children);
        if (stack.isNotEmpty) {
          stack.last.children.add(finishedNode);
        } else {
          roots.add(finishedNode);
        }
      }

      stack.add(_StackEntry(node: node, level: level));
    }
  }

  // Flush remaining stack
  while (stack.isNotEmpty) {
    final completed = stack.removeLast();
    final finishedNode =
        completed.node.copyWith(children: completed.children);
    if (stack.isNotEmpty) {
      stack.last.children.add(finishedNode);
    } else {
      roots.add(finishedNode);
    }
  }

  return roots;
}

class _StackEntry {
  final OutlineNode node;
  final int level;
  final List<OutlineNode> children = [];

  _StackEntry({required this.node, required this.level});
}
