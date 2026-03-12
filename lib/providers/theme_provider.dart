import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggle() {
    switch (state) {
      case ThemeMode.system:
        state = ThemeMode.light;
      case ThemeMode.light:
        state = ThemeMode.dark;
      case ThemeMode.dark:
        state = ThemeMode.system;
    }
  }

  void setMode(ThemeMode mode) {
    state = mode;
  }
}

final sidebarVisibleProvider = StateProvider<bool>((ref) => true);
