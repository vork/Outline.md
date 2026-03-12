import 'package:flutter_test/flutter_test.dart';
import 'package:outline_md/models/outline_node.dart';
import 'package:outline_md/utils/tree_utils.dart';

void main() {
  OutlineNode _node(String id, {int level = 0, List<OutlineNode>? children}) {
    return OutlineNode(
      id: id,
      content: level > 0 ? '${'#' * level} Node $id' : 'Node $id',
      headingLevel: level,
      children: children ?? const [],
    );
  }

  group('flattenTree', () {
    test('returns empty list for empty input', () {
      expect(flattenTree([]), isEmpty);
    });

    test('flattens single node', () {
      final nodes = [_node('1')];
      expect(flattenTree(nodes).length, 1);
    });

    test('flattens nested tree depth-first', () {
      final tree = [
        _node('1', children: [
          _node('1a', children: [_node('1a1')]),
          _node('1b'),
        ]),
        _node('2'),
      ];
      final flat = flattenTree(tree);
      expect(flat.map((n) => n.id).toList(), ['1', '1a', '1a1', '1b', '2']);
    });
  });

  group('nodeDepth', () {
    test('returns 0 for root node', () {
      final tree = [_node('1')];
      expect(nodeDepth(tree, '1'), 0);
    });

    test('returns correct depth for nested node', () {
      final tree = [
        _node('1', children: [
          _node('2', children: [_node('3')]),
        ]),
      ];
      expect(nodeDepth(tree, '2'), 1);
      expect(nodeDepth(tree, '3'), 2);
    });

    test('returns -1 for non-existent node', () {
      final tree = [_node('1')];
      expect(nodeDepth(tree, 'missing'), -1);
    });
  });

  group('findNode', () {
    test('finds root node', () {
      final tree = [_node('1'), _node('2')];
      expect(findNode(tree, '2')?.id, '2');
    });

    test('finds deeply nested node', () {
      final tree = [
        _node('1', children: [
          _node('2', children: [_node('3')]),
        ]),
      ];
      expect(findNode(tree, '3')?.id, '3');
    });

    test('returns null for non-existent node', () {
      final tree = [_node('1')];
      expect(findNode(tree, 'nope'), isNull);
    });
  });

  group('findParent', () {
    test('finds parent of child node', () {
      final tree = [
        _node('parent', children: [_node('child')]),
      ];
      expect(findParent(tree, 'child')?.id, 'parent');
    });

    test('returns null for root node', () {
      final tree = [_node('root')];
      expect(findParent(tree, 'root'), isNull);
    });

    test('finds parent at deeper level', () {
      final tree = [
        _node('1', children: [
          _node('2', children: [_node('3')]),
        ]),
      ];
      expect(findParent(tree, '3')?.id, '2');
    });
  });

  group('removeNode', () {
    test('removes root node', () {
      final tree = [_node('1'), _node('2')];
      final result = removeNode(tree, '1');
      expect(result.length, 1);
      expect(result[0].id, '2');
    });

    test('removes nested node', () {
      final tree = [
        _node('1', children: [_node('2'), _node('3')]),
      ];
      final result = removeNode(tree, '2');
      expect(result[0].children.length, 1);
      expect(result[0].children[0].id, '3');
    });

    test('no-op when node not found', () {
      final tree = [_node('1')];
      final result = removeNode(tree, 'missing');
      expect(result.length, 1);
      expect(result[0].id, '1');
    });
  });

  group('updateNode', () {
    test('updates root node', () {
      final tree = [_node('1')];
      final result = updateNode(tree, '1', (n) => n.copyWith(content: 'Updated'));
      expect(result[0].content, 'Updated');
    });

    test('updates nested node', () {
      final tree = [
        _node('1', children: [_node('2')]),
      ];
      final result =
          updateNode(tree, '2', (n) => n.copyWith(content: 'Changed'));
      expect(result[0].children[0].content, 'Changed');
    });
  });

  group('insertAfter', () {
    test('inserts after target at root level', () {
      final tree = [_node('1'), _node('2')];
      final result = insertAfter(tree, '1', _node('new'));
      expect(result.length, 3);
      expect(result[1].id, 'new');
    });

    test('inserts after target in children', () {
      final tree = [
        _node('1', children: [_node('a'), _node('b')]),
      ];
      final result = insertAfter(tree, 'a', _node('new'));
      expect(result[0].children.length, 3);
      expect(result[0].children[1].id, 'new');
    });
  });

  group('insertBefore', () {
    test('inserts before target at root level', () {
      final tree = [_node('1'), _node('2')];
      final result = insertBefore(tree, '2', _node('new'));
      expect(result.length, 3);
      expect(result[1].id, 'new');
      expect(result[2].id, '2');
    });

    test('inserts before target in children', () {
      final tree = [
        _node('1', children: [_node('a'), _node('b')]),
      ];
      final result = insertBefore(tree, 'b', _node('new'));
      expect(result[0].children.length, 3);
      expect(result[0].children[1].id, 'new');
    });
  });

  group('addChild', () {
    test('adds child to target node', () {
      final tree = [_node('1')];
      final result = addChild(tree, '1', _node('child'));
      expect(result[0].children.length, 1);
      expect(result[0].children[0].id, 'child');
    });

    test('appends to existing children', () {
      final tree = [
        _node('1', children: [_node('existing')]),
      ];
      final result = addChild(tree, '1', _node('new'));
      expect(result[0].children.length, 2);
      expect(result[0].children[1].id, 'new');
    });
  });

  group('isDescendant', () {
    test('returns true for direct child', () {
      final tree = [
        _node('parent', children: [_node('child')]),
      ];
      expect(isDescendant(tree, 'parent', 'child'), true);
    });

    test('returns true for deeply nested descendant', () {
      final tree = [
        _node('1', children: [
          _node('2', children: [_node('3')]),
        ]),
      ];
      expect(isDescendant(tree, '1', '3'), true);
    });

    test('returns false for non-descendant', () {
      final tree = [_node('1'), _node('2')];
      expect(isDescendant(tree, '1', '2'), false);
    });
  });

  group('visibleNodes', () {
    test('returns all nodes when nothing collapsed', () {
      final tree = [
        _node('1', children: [_node('2'), _node('3')]),
      ];
      final visible = visibleNodes(tree);
      expect(visible.length, 3);
    });

    test('hides children of collapsed node', () {
      final tree = [
        OutlineNode(
          id: '1',
          content: 'Node 1',
          isCollapsed: true,
          children: [_node('2'), _node('3')],
        ),
      ];
      final visible = visibleNodes(tree);
      expect(visible.length, 1);
      expect(visible[0].$1.id, '1');
    });

    test('provides correct depth values', () {
      final tree = [
        _node('1', children: [
          _node('2', children: [_node('3')]),
        ]),
      ];
      final visible = visibleNodes(tree);
      expect(visible[0].$2, 0);
      expect(visible[1].$2, 1);
      expect(visible[2].$2, 2);
    });
  });

  group('setAllCollapsed', () {
    test('collapses all nodes with children', () {
      final tree = [
        _node('1', children: [_node('2')]),
        _node('3'),
      ];
      final result = setAllCollapsed(tree, true);
      expect(result[0].isCollapsed, true);
      expect(result[1].isCollapsed, false);
    });

    test('expands all nodes', () {
      final tree = [
        OutlineNode(
          id: '1',
          content: 'Node 1',
          isCollapsed: true,
          children: [_node('2')],
        ),
      ];
      final result = setAllCollapsed(tree, false);
      expect(result[0].isCollapsed, false);
    });
  });

  group('detectHeadingLevel', () {
    test('detects H1 through H6', () {
      expect(detectHeadingLevel('# Title'), 1);
      expect(detectHeadingLevel('## Title'), 2);
      expect(detectHeadingLevel('### Title'), 3);
      expect(detectHeadingLevel('#### Title'), 4);
      expect(detectHeadingLevel('##### Title'), 5);
      expect(detectHeadingLevel('###### Title'), 6);
    });

    test('returns 0 for body text', () {
      expect(detectHeadingLevel('Just text'), 0);
      expect(detectHeadingLevel(''), 0);
    });

    test('handles leading whitespace', () {
      expect(detectHeadingLevel('  ## Indented'), 2);
    });

    test('detects level from first line only', () {
      expect(detectHeadingLevel('# Title\nBody text'), 1);
    });
  });

  group('buildTreeFromFlat', () {
    test('returns empty list for empty input', () {
      expect(buildTreeFromFlat([]), isEmpty);
    });

    test('keeps flat body nodes as roots', () {
      final flat = [_node('1'), _node('2')];
      final tree = buildTreeFromFlat(flat);
      expect(tree.length, 2);
    });

    test('nests H2 under H1', () {
      final flat = [
        _node('1', level: 1),
        _node('2', level: 2),
      ];
      final tree = buildTreeFromFlat(flat);
      expect(tree.length, 1);
      expect(tree[0].children.length, 1);
      expect(tree[0].children[0].id, '2');
    });

    test('body text attaches to preceding heading', () {
      final flat = [
        _node('h', level: 1),
        _node('body'),
      ];
      final tree = buildTreeFromFlat(flat);
      expect(tree.length, 1);
      expect(tree[0].children.length, 1);
      expect(tree[0].children[0].id, 'body');
    });

    test('complex hierarchy builds correctly', () {
      final flat = [
        _node('1', level: 1),
        _node('2', level: 2),
        _node('3', level: 3),
        _node('4', level: 2),
        _node('5', level: 1),
      ];
      final tree = buildTreeFromFlat(flat);
      expect(tree.length, 2);
      expect(tree[0].id, '1');
      expect(tree[0].children.length, 2);
      expect(tree[0].children[0].id, '2');
      expect(tree[0].children[0].children.length, 1);
      expect(tree[0].children[0].children[0].id, '3');
      expect(tree[0].children[1].id, '4');
      expect(tree[1].id, '5');
    });
  });
}
