import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'utils/platform_utils.dart';
import 'app.dart';

/// Stores the file path passed via command-line arguments or native file-open.
String? initialFilePath;

/// Method channel for receiving file-open events from native code.
const fileOpenChannel = MethodChannel('com.outline.md/file_open');

/// Callback invoked when the OS opens a file while the app is already running.
void Function(String path)? onFileOpened;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture file path from command-line arguments (Windows/Linux)
  if (isDesktop && args.isNotEmpty) {
    final path = args.first;
    if (File(path).existsSync()) {
      initialFilePath = path;
    }
  }

  // On macOS, ask the native side for a file path queued during launch
  if (isMacOS) {
    try {
      final path = await fileOpenChannel.invokeMethod<String>('getInitialFile');
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        initialFilePath = path;
      }
    } catch (_) {}

    // Listen for file-open events while the app is running
    fileOpenChannel.setMethodCallHandler((call) async {
      if (call.method == 'openFile') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          onFileOpened?.call(path);
        }
      }
    });
  }

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1100, 750),
      minimumSize: Size(600, 400),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Outline.md',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: OutlineMdApp()));
}
