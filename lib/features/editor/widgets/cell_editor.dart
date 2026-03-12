import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CellEditor extends StatefulWidget {
  final String content;
  final ValueChanged<String> onChanged;
  final VoidCallback onCommit;
  final VoidCallback? onCommitAndContinue;
  final VoidCallback? onDelete;
  final FocusNode? focusNode;

  const CellEditor({
    super.key,
    required this.content,
    required this.onChanged,
    required this.onCommit,
    this.onCommitAndContinue,
    this.onDelete,
    this.focusNode,
  });

  @override
  State<CellEditor> createState() => _CellEditorState();
}

class _CellEditorState extends State<CellEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _commit() {
    if (_committed) return;
    _committed = true;
    widget.onCommit();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && mounted) {
      _commit();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter &&
              (HardwareKeyboard.instance.isMetaPressed ||
                  HardwareKeyboard.instance.isControlPressed)) {
            _commit();
            return;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _commit();
            return;
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace &&
              _controller.text.isEmpty &&
              widget.onDelete != null) {
            widget.onDelete!();
            return;
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: null,
          style: GoogleFonts.geistMono(
            fontSize: 14,
            color: theme.colorScheme.onSurface,
            height: 1.5,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(12),
            border: InputBorder.none,
            hintText: 'Type markdown here...',
            hintStyle: GoogleFonts.geistMono(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
          onChanged: (value) {
            if (value == '\n' && widget.onCommitAndContinue != null) {
              _committed = true;
              widget.onCommitAndContinue!();
              return;
            }
            widget.onChanged(value);
          },
        ),
      ),
    );
  }
}
