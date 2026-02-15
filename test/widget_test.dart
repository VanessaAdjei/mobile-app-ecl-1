// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eclapp/main.dart';

void main() {
  testWidgets('Onboarding shows welcome text on first launch',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(
      find.text('Welcome to Enerst Chemists E-Pharmacy!'),
      findsOneWidget,
    );
  });
}
