import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/main.dart' as app;

void main() {
  group('Authentication E2E Tests', () {
    testWidgets('Complete registration flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _navigateToRegistration(tester);
      await _fillRegistrationForm(tester);
      await _submitRegistration(tester);
    });

    testWidgets('Login with valid credentials', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _navigateToLogin(tester);
      await _fillLoginForm(tester);
      await _submitLogin(tester);
    });

    testWidgets('Login with invalid credentials', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _navigateToLogin(tester);
      await _fillInvalidLoginForm(tester);
      await _submitLogin(tester);
    });

    testWidgets('Password reset flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _navigateToPasswordReset(tester);
      await _fillPasswordResetForm(tester);
      await _submitPasswordReset(tester);
    });

    testWidgets('Logout flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _loginUser(tester);
      await _logout(tester);
    });
  });
}

Future<void> _navigateToRegistration(WidgetTester tester) async {
  // Look for registration-related elements
  final registerButton = find.text('Register');
  if (await tester.any(registerButton)) {
    await tester.tap(registerButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _fillRegistrationForm(WidgetTester tester) async {
  // Fill in registration form fields
  final emailField = find.byType(TextFormField).at(0);
  final passwordField = find.byType(TextFormField).at(1);
  final nameField = find.byType(TextFormField).at(2);

  await tester.enterText(emailField, 'test@example.com');
  await tester.enterText(passwordField, 'password123');
  await tester.enterText(nameField, 'Test User');
  await tester.pumpAndSettle();
}

Future<void> _submitRegistration(WidgetTester tester) async {
  final submitButton = find.text('Register');
  if (await tester.any(submitButton)) {
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _navigateToLogin(WidgetTester tester) async {
  final loginButton = find.text('Login');
  if (await tester.any(loginButton)) {
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _fillLoginForm(WidgetTester tester) async {
  final emailField = find.byType(TextFormField).at(0);
  final passwordField = find.byType(TextFormField).at(1);

  await tester.enterText(emailField, 'test@example.com');
  await tester.enterText(passwordField, 'password123');
  await tester.pumpAndSettle();
}

Future<void> _fillInvalidLoginForm(WidgetTester tester) async {
  final emailField = find.byType(TextFormField).at(0);
  final passwordField = find.byType(TextFormField).at(1);

  await tester.enterText(emailField, 'invalid@example.com');
  await tester.enterText(passwordField, 'wrongpassword');
  await tester.pumpAndSettle();
}

Future<void> _submitLogin(WidgetTester tester) async {
  final submitButton = find.text('Login');
  if (await tester.any(submitButton)) {
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _navigateToPasswordReset(WidgetTester tester) async {
  final forgotPasswordButton = find.text('Forgot Password?');
  if (await tester.any(forgotPasswordButton)) {
    await tester.tap(forgotPasswordButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _fillPasswordResetForm(WidgetTester tester) async {
  final emailField = find.byType(TextFormField).first;
  await tester.enterText(emailField, 'test@example.com');
  await tester.pumpAndSettle();
}

Future<void> _submitPasswordReset(WidgetTester tester) async {
  final submitButton = find.text('Reset Password');
  if (await tester.any(submitButton)) {
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _loginUser(WidgetTester tester) async {
  await _navigateToLogin(tester);
  await _fillLoginForm(tester);
  await _submitLogin(tester);
}

Future<void> _logout(WidgetTester tester) async {
  // Look for logout option in menu or profile
  final profileButton = find.byIcon(Icons.person);
  if (await tester.any(profileButton)) {
    await tester.tap(profileButton);
    await tester.pumpAndSettle();
  }

  final logoutButton = find.text('Logout');
  if (await tester.any(logoutButton)) {
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();
  }
} 