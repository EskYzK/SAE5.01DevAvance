// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_object_detector/main.dart';

void main() {
  testWidgets('HomeScreen builds and shows title', (WidgetTester tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized() as TestWidgetsFlutterBinding;
    binding.window.physicalSizeTestValue = const Size(1080, 1920);
    binding.window.devicePixelRatioTestValue = 1.0;

    // Build our app and trigger a frame.
    await tester.pumpWidget(const ObjectDetectorApp());
    await tester.pumpAndSettle();

    // Verify that the main title is shown.
    expect(find.text("Reconnaissance d’objets scolaires"), findsOneWidget);

    // Clean up test window overrides.
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });
}
