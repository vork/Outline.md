import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outline_md/app.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: OutlineMdApp()));
    expect(find.text('OUTLINE'), findsOneWidget);
  });
}
