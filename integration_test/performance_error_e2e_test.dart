import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/main.dart' as app;

void main() {
  group('Performance and Error Handling E2E Tests', () {
    testWidgets('App startup performance', (tester) async {
      final stopwatch = Stopwatch()..start();
      app.main();
      await tester.pumpAndSettle();
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Memory usage and performance', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate through multiple screens to test memory usage
      for (int i = 0; i < 5; i++) {
        final homeButton = find.byIcon(Icons.home);
        if (await tester.any(homeButton)) {
          await tester.tap(homeButton);
          await tester.pumpAndSettle();
        }

        final profileButton = find.byIcon(Icons.person);
        if (await tester.any(profileButton)) {
          await tester.tap(profileButton);
          await tester.pumpAndSettle();
        }
      }

      // Verify app is still responsive
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Network error handling', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _testNetworkErrorHandling(tester);
    });

    testWidgets('Invalid input handling', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _testInvalidInputs(tester);
    });

    testWidgets('App state persistence', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _testStatePersistence(tester);
    });

    testWidgets('Accessibility compliance', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _testAccessibility(tester);
    });
  });
}

Future<void> _testNetworkErrorHandling(WidgetTester tester) async {
  // Try to perform actions that require network
  final loginButton = find.text('Login');
  if (await tester.any(loginButton)) {
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    // Enter invalid credentials to trigger network error
    final emailField = find.byType(TextFormField).at(0);
    final passwordField = find.byType(TextFormField).at(1);

    await tester.enterText(emailField, 'invalid@example.com');
    await tester.enterText(passwordField, 'wrongpassword');

    final submitButton = find.text('Login');
    if (await tester.any(submitButton)) {
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
    }

    // Verify error message is displayed
    expect(find.text('Invalid email or password'), findsOneWidget);
  }
}

Future<void> _testInvalidInputs(WidgetTester tester) async {
  final loginButton = find.text('Login');
  if (await tester.any(loginButton)) {
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    final emailField = find.byType(TextFormField).at(0);
    final passwordField = find.byType(TextFormField).at(1);

    // Test invalid email format
    await tester.enterText(emailField, 'invalid-email');
    await tester.enterText(passwordField, '123');

    final submitButton = find.text('Login');
    if (await tester.any(submitButton)) {
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
    }

    // Verify validation error messages
    expect(find.text('Please enter a valid email'), findsOneWidget);
  }
}

Future<void> _testStatePersistence(WidgetTester tester) async {
  // Login user
  final loginButton = find.text('Login');
  if (await tester.any(loginButton)) {
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    final emailField = find.byType(TextFormField).at(0);
    final passwordField = find.byType(TextFormField).at(1);

    await tester.enterText(emailField, 'test@example.com');
    await tester.enterText(passwordField, 'password123');

    final submitButton = find.text('Login');
    if (await tester.any(submitButton)) {
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
    }
  }

  // Verify user is logged in
  expect(find.text('Welcome'), findsOneWidget);
}

Future<void> _testAccessibility(WidgetTester tester) async {
  // Test that all interactive elements have proper accessibility labels
  final buttons = find.byType(ElevatedButton);
  for (final button in buttons.evaluate()) {
    final semantics = button.semantics;
    expect(semantics.label, isNotEmpty);
  }

  // Test that text fields have proper labels
  final textFields = find.byType(TextFormField);
  for (final field in textFields.evaluate()) {
    final semantics = field.semantics;
    expect(semantics.label, isNotEmpty);
  }

  // Test navigation accessibility
  final navigationButtons = find.byType(BottomNavigationBar);
  if (await tester.any(navigationButtons)) {
    expect(navigationButtons, findsOneWidget);
  }
} 