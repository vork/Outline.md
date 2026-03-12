import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/document_provider.dart';
import 'outline_cell.dart' show kColumnWidth;

class ColumnHeader extends ConsumerWidget {
  const ColumnHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentProvider);
    if (!doc.hasColumns) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text('Content', style: labelStyle),
            ),
          ),
          for (final col in doc.columns)
            SizedBox(
              width: kColumnWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(col.name, style: labelStyle),
              ),
            ),
          // Placeholder matching the menu button width
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
