// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eclapp/main.dart';

void main() {
  testWidgets('Onboarding shows welcome text on first launch',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      const MyApp(
        launchFlags: AppLaunchFlags(
          isFirstLaunch: true,
          termsAccepted: false,
          hasSeenBrandSplash: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Welcome to Ernest Chemists Ltd'),
      findsOneWidget,
    );
  });
}
