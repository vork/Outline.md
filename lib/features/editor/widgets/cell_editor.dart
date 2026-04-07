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

  static const _pairs = <String, String>{
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    '`': '`',
  };

  static const _closers = <String>{')', ']', '}'};

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed)) {
      _commit();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      _commit();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace &&
        _controller.text.isEmpty &&
        widget.onDelete != null) {
      widget.onDelete!();
      return KeyEventResult.handled;
    }

    // Auto-pair brackets
    final char = event.character;
    if (char != null && _controller.selection.isCollapsed) {
      final offset = _controller.selection.baseOffset;
      final text = _controller.text;

      // Typing a closing bracket that already exists after cursor → skip over it
      if (_closers.contains(char) &&
          offset < text.length &&
          text[offset] == char) {
        _controller.selection =
            TextSelection.collapsed(offset: offset + 1);
        return KeyEventResult.handled;
      }

      // Typing an opening bracket → insert pair
      if (_pairs.containsKey(char)) {
        final closer = _pairs[char]!;
        // For quotes/backticks, skip pairing if character after cursor is alphanumeric
        if ((char == '"' || char == '`') &&
            offset < text.length &&
            RegExp(r'[a-zA-Z0-9]').hasMatch(text[offset])) {
          return KeyEventResult.ignored;
        }
        final newText =
            text.substring(0, offset) + char + closer + text.substring(offset);
        _controller.text = newText;
        _controller.selection =
            TextSelection.collapsed(offset: offset + 1);
        widget.onChanged(newText);
        return KeyEventResult.handled;
      }

      // Backspace deletes both brackets if cursor is between a pair
      if (key == LogicalKeyboardKey.backspace &&
          offset > 0 &&
          offset < text.length) {
        final before = text[offset - 1];
        final after = text[offset];
        if (_pairs[before] == after) {
          final newText =
              text.substring(0, offset - 1) + text.substring(offset + 1);
          _controller.text = newText;
          _controller.selection =
              TextSelection.collapsed(offset: offset - 1);
          widget.onChanged(newText);
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Focus(
      onKeyEvent: _handleKeyEvent,
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
            fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14,
            color: theme.colorScheme.onSurface,
            height: 1.5,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(12),
            border: InputBorder.none,
            hintText: 'Type markdown here...',
            hintStyle: GoogleFonts.geistMono(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14,
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
