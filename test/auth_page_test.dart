// ============================================================================
//  ENNVO — AUTH SCREEN WIDGET TEST
//
//  The auth screen is the first thing a new user sees, so its structure is
//  worth locking down against the web build.
// ============================================================================

import 'package:ennvo/features/auth/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows the sign-in form', (tester) async {
    await tester.pumpWidget(_wrap(const AuthPage()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back,'), findsOneWidget);
    expect(find.text('Log In!'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('the Google button carries the brand mark', (tester) async {
    await tester.pumpWidget(_wrap(const AuthPage()));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('switches to the sign-up chooser and the form', (tester) async {
    await tester.pumpWidget(_wrap(const AuthPage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    // The web app opens the social chooser first.
    expect(find.text("it's easier to sign up now"), findsOneWidget);
    expect(find.text("I'll use email or username"), findsOneWidget);

    await tester.ensureVisible(find.text("I'll use email or username"));
    await tester.tap(find.text("I'll use email or username"));
    await tester.pumpAndSettle();

    expect(find.text('USER NAME'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('switches to the password reset form', (tester) async {
    await tester.pumpWidget(_wrap(const AuthPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Pass!'), findsOneWidget);
    expect(find.text('YOUR EMAIL'), findsOneWidget);
    expect(find.text('Send Reset Link'), findsOneWidget);
  });

  testWidgets('calls back with the entered credentials', (tester) async {
    String? user;
    String? password;

    await tester.pumpWidget(
      _wrap(
        AuthPage(
          onSignIn: (u, p) async {
            user = u;
            password = p;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'erfan');
    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(user, 'erfan');
    expect(password, 'secret123');
  });
}
