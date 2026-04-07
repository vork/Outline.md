import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CellEditor extends StatefulWidget {
  final String content;
  final ValueChanged<String> onChanged;
  final VoidCallback onCommit;
  final VoidCallback? onCommitAndContinue;
  final VoidCallback? onDelete;
  final FocusNode? focusNode;
  final bool focusMode;

  const CellEditor({
    super.key,
    required this.content,
    required this.onChanged,
    required this.onCommit,
    this.onCommitAndContinue,
    this.onDelete,
    this.focusNode,
    this.focusMode = false,
  });

  @override
  State<CellEditor> createState() => _CellEditorState();
}

class _CellEditorState extends State<CellEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final GlobalKey _textFieldKey = GlobalKey();
  bool _committed = false;
  // Active line rect relative to the TextField, updated from caret position.
  Rect? _activeLineRect;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _controller.addListener(_onSelectionChanged);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onSelectionChanged() {
    if (!widget.focusMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final newRect = _getActiveLineRect();
      if (newRect != _activeLineRect) {
        setState(() => _activeLineRect = newRect);
      }
    });
  }

  /// Walk the render tree to find the RenderEditable and compute the caret line rect.
  Rect? _getActiveLineRect() {
    final fieldContext = _textFieldKey.currentContext;
    if (fieldContext == null) return null;

    RenderEditable? editable;
    void visitor(Element element) {
      if (editable != null) return;
      if (element.renderObject is RenderEditable) {
        editable = element.renderObject as RenderEditable;
        return;
      }
      element.visitChildren(visitor);
    }
    fieldContext.visitChildElements(visitor);
    if (editable == null) return null;

    final offset = _controller.selection.baseOffset;
    final caretOffset = editable!.getLocalRectForCaret(
      TextPosition(offset: offset.clamp(0, _controller.text.length)),
    );

    // Convert from RenderEditable coordinates to the TextField widget coordinates.
    final editableBox = editable!;
    final fieldBox = fieldContext.findRenderObject() as RenderBox;
    final toField = editableBox.localToGlobal(Offset.zero) -
        fieldBox.localToGlobal(Offset.zero);

    final lineTop = toField.dy + caretOffset.top;
    final lineBottom = toField.dy + caretOffset.bottom;

    return Rect.fromLTRB(0, lineTop, fieldBox.size.width, lineBottom);
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
    _controller.removeListener(_onSelectionChanged);
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
    final fontSize = theme.textTheme.bodyMedium?.fontSize ?? 14;

    final textField = TextField(
      key: _textFieldKey,
      controller: _controller,
      focusNode: _focusNode,
      maxLines: null,
      style: GoogleFonts.geistMono(
        fontSize: fontSize,
        color: theme.colorScheme.onSurface,
        height: 1.5,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(12),
        border: InputBorder.none,
        hintText: 'Type markdown here...',
        hintStyle: GoogleFonts.geistMono(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          fontSize: fontSize,
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
    );

    final bgColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: widget.focusMode
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4.5),
                child: Stack(
                  children: [
                    textField,
                    if (_activeLineRect != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _LineFocusPainter(
                              activeLineRect: _activeLineRect!,
                              dimColor: bgColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : textField,
      ),
    );
  }
}

class _LineFocusPainter extends CustomPainter {
  final Rect activeLineRect;
  final Color dimColor;

  _LineFocusPainter({
    required this.activeLineRect,
    required this.dimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dimColor;

    // Dim above the active line
    if (activeLineRect.top > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, size.width, activeLineRect.top),
        paint,
      );
    }
    // Dim below the active line
    if (activeLineRect.bottom < size.height) {
      canvas.drawRect(
        Rect.fromLTRB(0, activeLineRect.bottom, size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LineFocusPainter old) =>
      old.activeLineRect != activeLineRect ||
      old.dimColor != dimColor;
}
