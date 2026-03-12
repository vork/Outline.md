import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MermaidDiagram extends StatefulWidget {
  final String source;
  final Brightness brightness;

  const MermaidDiagram({
    super.key,
    required this.source,
    required this.brightness,
  });

  @override
  State<MermaidDiagram> createState() => _MermaidDiagramState();
}

class _MermaidDiagramState extends State<MermaidDiagram> {
  late final WebViewController _controller;
  double _height = 300;
  bool _ready = false;
  String? _error;

  static String? _mermaidJsPath;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _loadDiagram();
  }

  Future<String> _ensureMermaidJs() async {
    if (_mermaidJsPath != null && File(_mermaidJsPath!).existsSync()) {
      return _mermaidJsPath!;
    }
    final tempDir = await getTemporaryDirectory();
    final mermaidDir = Directory('${tempDir.path}/mermaid_assets');
    if (!mermaidDir.existsSync()) {
      mermaidDir.createSync(recursive: true);
    }
    final jsFile = File('${mermaidDir.path}/mermaid.min.js');
    if (!jsFile.existsSync()) {
      final jsContent =
          await rootBundle.loadString('assets/mermaid/mermaid.min.js');
      await jsFile.writeAsString(jsContent);
    }
    _mermaidJsPath = jsFile.path;
    return _mermaidJsPath!;
  }

  Future<void> _loadDiagram() async {
    String mermaidJsPath;
    try {
      mermaidJsPath = await _ensureMermaidJs();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load mermaid.js: $e';
          _ready = true;
        });
      }
      return;
    }

    final isDark = widget.brightness == Brightness.dark;
    final theme = isDark ? 'dark' : 'default';
    final bg = isDark ? '#1e1e1e' : '#ffffff';
    final escapedSource = jsonEncode(widget.source.trim());

    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  html, body { margin: 0; padding: 0; background: $bg; }
  body { padding: 16px; display: flex; justify-content: center; }
  #container { display: inline-block; }
  #container svg { max-width: 100%; height: auto; }
  .error { color: #d32f2f; font-family: monospace; font-size: 13px; padding: 12px; }
</style>
</head>
<body>
<div id="container"></div>
<script src="mermaid.min.js"></script>
<script>
(async function() {
  try {
    mermaid.initialize({
      startOnLoad: false,
      theme: '$theme',
      securityLevel: 'loose',
    });
    const source = $escapedSource;
    const { svg } = await mermaid.render('diagram', source);
    document.getElementById('container').innerHTML = svg;

    // Wait for the SVG to render and measure its actual size
    await new Promise(r => setTimeout(r, 300));
    const svgEl = document.querySelector('#container svg');
    let h = 200;
    if (svgEl) {
      // Try getBBox for accurate SVG dimensions
      try {
        const bbox = svgEl.getBBox();
        h = Math.ceil(bbox.height) + 40;
      } catch(e) {}
      // Fallback: use viewBox or element dimensions
      if (h <= 40) {
        const vb = svgEl.getAttribute('viewBox');
        if (vb) {
          const parts = vb.split(/[\\s,]+/);
          if (parts.length === 4) h = Math.ceil(parseFloat(parts[3])) + 40;
        }
      }
      if (h <= 40) {
        h = Math.max(svgEl.scrollHeight, svgEl.clientHeight, svgEl.offsetHeight, 200) + 40;
      }
      // Also check the document body
      const bodyH = document.body.scrollHeight;
      if (bodyH > h) h = bodyH;
    }
    if (window.MermaidChannel) {
      MermaidChannel.postMessage(JSON.stringify({ height: Math.max(h, 100) }));
    }
  } catch (e) {
    document.getElementById('container').innerHTML =
      '<div class="error">Mermaid error: ' + e.message + '</div>';
    if (window.MermaidChannel) {
      MermaidChannel.postMessage(JSON.stringify({ height: 80, error: e.message }));
    }
  }
})();
</script>
</body>
</html>
''';

    final htmlDir = File(mermaidJsPath).parent.path;
    final htmlFile =
        File('$htmlDir/diagram_${widget.source.hashCode.abs()}.html');
    await htmlFile.writeAsString(html);

    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    try {
      await _controller.setBackgroundColor(
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF));
    } catch (_) {
      // setBackgroundColor is unimplemented on macOS WKWebView
    }
    await _controller.setNavigationDelegate(NavigationDelegate(
      onWebResourceError: (error) {
        if (mounted && (error.isForMainFrame ?? false)) {
          setState(() {
            _error = error.description;
            _ready = true;
          });
        }
      },
    ));
    await _controller.addJavaScriptChannel('MermaidChannel',
        onMessageReceived: (message) {
      if (!mounted) return;
      try {
        final data = jsonDecode(message.message) as Map<String, dynamic>;
        final h = (data['height'] as num?)?.toDouble() ?? 300;
        final err = data['error'] as String?;
        setState(() {
          _height = h.clamp(100, 800);
          _ready = true;
          _error = err;
        });
      } catch (_) {
        setState(() => _ready = true);
      }
    });
    await _controller.loadFile(htmlFile.path);
  }

  void _openFullScreen() {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _FullScreenMermaid(
        source: widget.source,
        brightness: widget.brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final theme = Theme.of(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Mermaid: $_error',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _ready ? _openFullScreen : null,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: _height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: WebViewWidget(controller: _controller),
          ),
          if (!_ready)
            SizedBox(
              height: _height,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (_ready)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: theme.colorScheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _openFullScreen,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.fullscreen,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen dialog for viewing a mermaid diagram.
class _FullScreenMermaid extends StatefulWidget {
  final String source;
  final Brightness brightness;

  const _FullScreenMermaid({
    required this.source,
    required this.brightness,
  });

  @override
  State<_FullScreenMermaid> createState() => _FullScreenMermaidState();
}

class _FullScreenMermaidState extends State<_FullScreenMermaid> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _load();
  }

  Future<void> _load() async {
    final jsPath = _MermaidDiagramState._mermaidJsPath;
    if (jsPath == null) return;

    final isDark = widget.brightness == Brightness.dark;
    final theme = isDark ? 'dark' : 'default';
    final bg = isDark ? '#1e1e1e' : '#ffffff';
    final fg = isDark ? '#e0e0e0' : '#333333';
    final escapedSource = jsonEncode(widget.source.trim());

    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  html, body { margin: 0; padding: 0; background: $bg; color: $fg;
    display: flex; justify-content: center; align-items: flex-start;
    min-height: 100vh; overflow: auto; }
  body { padding: 24px; }
  #container svg { max-width: 100%; height: auto; }
  .error { color: #d32f2f; font-family: monospace; font-size: 14px; padding: 16px; }
</style>
</head>
<body>
<div id="container"></div>
<script src="mermaid.min.js"></script>
<script>
(async function() {
  try {
    mermaid.initialize({ startOnLoad: false, theme: '$theme', securityLevel: 'loose' });
    const { svg } = await mermaid.render('diagram', $escapedSource);
    document.getElementById('container').innerHTML = svg;
  } catch (e) {
    document.getElementById('container').innerHTML =
      '<div class="error">Mermaid error: ' + e.message + '</div>';
  }
})();
</script>
</body>
</html>
''';

    final htmlDir = File(jsPath).parent.path;
    final htmlFile = File('$htmlDir/diagram_fullscreen.html');
    await htmlFile.writeAsString(html);

    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    try {
      await _controller.setBackgroundColor(
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF));
    } catch (_) {}
    await _controller.loadFile(htmlFile.path);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : Colors.white;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              Positioned.fill(
                child: WebViewWidget(controller: _controller),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child:
                          Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
