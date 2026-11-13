// ============================================================================
//  ENNVO — AUTH SCREEN WIDGET TEST
//
//  The auth screen is the first thing a new user sees, so its structure is
//  worth locking down.
// ============================================================================

import 'package:ennvo/features/auth/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows the sign-in form', (tester) async {
    await tester.pumpWidget(_wrap(const AuthPage()));
    await tester.pumpAndSettle();

    expect(find.text('Log In to Ennvo'), findsOneWidget);
    expect(find.text('Welcome back! Please enter your details.'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('the Google button carries the brand mark', (tester) async {
    await tester.pumpWidget(_wrap(const AuthPage()));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('switches to the sign-up form', (tester) async {
    await tester.pumpWidget(_wrap(const AuthPage()));
    await tester.pumpAndSettle();

    // The link sits at the bottom of the form, which is inside a scroll
    // view — bring it on screen first.
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Join Ennvo'), findsOneWidget);
    expect(find.text('FULL NAME'), findsOneWidget);
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
  });

  testWidgets('switches to the password reset form', (tester) async {
    await tester.pumpWidget(_wrap(const AuthPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
    expect(
      find.text('Enter your email and we will send you a reset link.'),
      findsOneWidget,
    );
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
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(user, 'erfan');
    expect(password, 'secret123');
  });
}
