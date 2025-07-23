// test/widget_test.dart
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eclapp/main.dart';

void main() {
  testWidgets('Onboarding shows welcome text', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'hasLaunchedBefore': false});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Enerst Chemists!'), findsOneWidget);
  });
}
