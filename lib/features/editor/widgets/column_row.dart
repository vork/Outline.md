import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/outline_node.dart';
import '../../../providers/document_provider.dart';

class ColumnRow extends ConsumerWidget {
  final OutlineNode node;

  const ColumnRow({super.key, required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentProvider);
    if (!doc.hasColumns) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isEditing = ref.watch(editorStateProvider).editingNodeId == node.id;

    return Row(
      children: doc.columns.map((col) {
        final value = node.columnValues[col.name] ?? '';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: isEditing
                ? _EditableColumnCell(
                    value: value,
                    onChanged: (v) {
                      ref
                          .read(documentProvider.notifier)
                          .setColumnValue(node.id, col.name, v);
                    },
                    theme: theme,
                  )
                : Text(
                    value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        );
      }).toList(),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: widget.theme.dividerColor),
        ),
        hintText: '...',
        hintStyle: TextStyle(
          color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.3),
          fontSize: 12,
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}
