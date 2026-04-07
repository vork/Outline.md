import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'utils/platform_utils.dart';
import 'app.dart';

/// Stores the file path passed via command-line arguments on desktop platforms.
String? initialFilePath;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture file path from command-line arguments (desktop platforms)
  if (isDesktop && args.isNotEmpty) {
    final path = args.first;
    if (File(path).existsSync()) {
      initialFilePath = path;
    }
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
