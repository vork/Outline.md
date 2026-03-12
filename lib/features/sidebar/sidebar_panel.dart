import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/document_provider.dart';
import 'sidebar_item.dart';

class SidebarPanel extends ConsumerWidget {
  final ValueChanged<String>? onItemTap;

  const SidebarPanel({super.key, this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        border: Border(
          right: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'OUTLINE',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const Divider(height: 1),

          // Tree
          Expanded(
            child: doc.nodes.isEmpty
                ? Center(
                    child: Text(
                      'No outline yet',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    children: doc.nodes
                        .map((node) => SidebarItem(
                              node: node,
                              onTap: onItemTap,
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
