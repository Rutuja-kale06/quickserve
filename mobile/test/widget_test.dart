import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/main.dart';
import 'package:quickserve/screens/splash_screen.dart';
import 'package:quickserve/screens/auth_screen.dart';

void main() {
  testWidgets('App boots to the branded Splash screen', (tester) async {
    await tester.pumpWidget(const QuickServeApp());
    expect(find.text('QuickServe'), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('Auth screen renders login form with reset option', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    expect(find.text('QuickServe'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // email + password
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('Registration toggles to sign-up fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.tap(find.text('New customer? Register'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4)); // name, phone, email, password
    expect(find.text('Create account'), findsOneWidget);
  });
}