import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/outline_node.dart';
import '../../providers/document_provider.dart';

class SidebarItem extends ConsumerWidget {
  final OutlineNode node;
  final int depth;
  final ValueChanged<String>? onTap;

  const SidebarItem({
    super.key,
    required this.node,
    this.depth = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(editorStateProvider).selectedNodeId == node.id;
    final indent = depth * 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            ref.read(editorStateProvider.notifier).setSelectedNode(node.id);
            onTap?.call(node.id);
          },
          child: Container(
            padding: EdgeInsets.only(
              left: 12 + indent,
              right: 8,
              top: 6,
              bottom: 6,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                if (node.hasChildren)
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(documentProvider.notifier)
                          .toggleCollapse(node.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: AnimatedRotation(
                        turns: node.isCollapsed ? -0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 18),
                if (node.isCheckbox)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      node.isChecked
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                Expanded(
                  child: Text(
                    node.displayTitle,
                    style: TextStyle(
                      fontSize: node.isHeading ? 13 : 12,
                      fontWeight:
                          node.headingLevel <= 2 ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      decoration: node.isChecked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!node.isCollapsed)
          ...node.children
              .where((c) => c.isHeading)
              .map((child) => SidebarItem(
                    node: child,
                    depth: depth + 1,
                    onTap: onTap,
                  )),
      ],
    );
  }
}
