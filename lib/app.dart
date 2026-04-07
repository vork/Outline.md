import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'features/editor/editor_screen.dart';

class OutlineMdApp extends ConsumerWidget {
  const OutlineMdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return MaterialApp(
      title: 'Outline.md',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(fontScale: fontScale),
      darkTheme: AppTheme.dark(fontScale: fontScale),
      themeMode: themeMode,
      home: const EditorScreen(),
    );
  }
}
