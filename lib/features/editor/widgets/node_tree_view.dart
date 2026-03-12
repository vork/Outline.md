import 'package:flutter/material.dart';
import '../../../models/outline_node.dart';
import 'outline_cell.dart';

class NodeTreeView extends StatelessWidget {
  final List<OutlineNode> nodes;
  final int depth;
  final ScrollController? scrollController;
  final GlobalKey Function(String nodeId)? nodeKeyFactory;

  const NodeTreeView({
    super.key,
    required this.nodes,
    this.depth = 0,
    this.scrollController,
    this.nodeKeyFactory,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    _buildFlatList(nodes, depth, widgets);

    if (depth == 0) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        cacheExtent: 99999,
        children: widgets,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  void _buildFlatList(List<OutlineNode> nodes, int depth, List<Widget> result) {
    for (final node in nodes) {
      result.add(
        OutlineCell(
          key: nodeKeyFactory?.call(node.id) ?? ValueKey(node.id),
          node: node,
          depth: depth,
        ),
      );

      if (!node.isCollapsed && node.children.isNotEmpty) {
        _buildFlatList(node.children, depth + 1, result);
      }
    }
  }
}
