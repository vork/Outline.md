import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

bool get isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

bool get isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

bool get isMacOS => !kIsWeb && Platform.isMacOS;

String get platformModifierKey => isMacOS ? '⌘' : 'Ctrl';
