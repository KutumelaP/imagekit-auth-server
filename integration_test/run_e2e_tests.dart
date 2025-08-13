import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/main.dart' as app;

/// E2E Test Runner for Marketplace App
/// 
/// This script provides a centralized way to run all E2E tests
/// with proper configuration and reporting.
void main() {
  group('Marketplace App E2E Test Suite', () {
    
    setUpAll(() async {
      // Global setup for all E2E tests
      print('🚀 Starting E2E Test Suite...');
    });

    tearDownAll(() async {
      // Global cleanup
      print('✅ E2E Test Suite completed');
    });

    // Run all test files
    testWidgets('Complete E2E Test Suite', (tester) async {
      // Initialize app
      app.main();
      await tester.pumpAndSettle();

      // Test 1: Authentication Flow
      await _runAuthenticationTests(tester);
      
      // Test 2: Shopping Flow
      await _runShoppingTests(tester);
      
      // Test 3: Performance Tests
      await _runPerformanceTests(tester);
      
      // Test 4: Error Handling
      await _runErrorHandlingTests(tester);
    });
  });
}

Future<void> _runAuthenticationTests(WidgetTester tester) async {
  print('🔐 Running Authentication Tests...');
  
  // Test registration
  await _testRegistration(tester);
  
  // Test login
  await _testLogin(tester);
  
  // Test logout
  await _testLogout(tester);
  
  print('✅ Authentication Tests completed');
}

Future<void> _runShoppingTests(WidgetTester tester) async {
  print('🛒 Running Shopping Tests...');
  
  // Test product browsing
  await _testProductBrowsing(tester);
  
  // Test cart operations
  await _testCartOperations(tester);
  
  // Test checkout process
  await _testCheckout(tester);
  
  print('✅ Shopping Tests completed');
}

Future<void> _runPerformanceTests(WidgetTester tester) async {
  print('⚡ Running Performance Tests...');
  
  // Test app startup
  await _testAppStartup(tester);
  
  // Test scrolling performance
  await _testScrollingPerformance(tester);
  
  // Test memory usage
  await _testMemoryUsage(tester);
  
  print('✅ Performance Tests completed');
}

Future<void> _runErrorHandlingTests(WidgetTester tester) async {
  print('⚠️ Running Error Handling Tests...');
  
  // Test network errors
  await _testNetworkErrors(tester);
  
  // Test invalid inputs
  await _testInvalidInputs(tester);
  
  // Test edge cases
  await _testEdgeCases(tester);
  
  print('✅ Error Handling Tests completed');
}

// Authentication test helpers
Future<void> _testRegistration(WidgetTester tester) async {
  final registerButton = find.byKey(const Key('register_button'));
  if (await tester.any(registerButton)) {
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    // Fill registration form
    await tester.enterText(
      find.byKey(const Key('email_field')),
      'testuser${DateTime.now().millisecondsSinceEpoch}@example.com'
    );
    await tester.enterText(
      find.byKey(const Key('password_field')),
      'TestPassword123!'
    );
    await tester.enterText(
      find.byKey(const Key('confirm_password_field')),
      'TestPassword123!'
    );
    await tester.enterText(
      find.byKey(const Key('name_field')),
      'Test User'
    );

    await tester.tap(find.byKey(const Key('submit_registration')));
    await tester.pumpAndSettle();

    expect(
      find.any((widget) => 
        widget is Text && 
        (widget.data?.contains('success') == true || 
         widget.data?.contains('welcome') == true)
      ),
      findsOneWidget,
    );
  }
}

Future<void> _testLogin(WidgetTester tester) async {
  final loginButton = find.byKey(const Key('login_button'));
  if (await tester.any(loginButton)) {
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('email_field')),
      'test@example.com'
    );
    await tester.enterText(
      find.byKey(const Key('password_field')),
      'password123'
    );

    await tester.tap(find.byKey(const Key('submit_login')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
  }
}

Future<void> _testLogout(WidgetTester tester) async {
  final profileButton = find.byKey(const Key('profile_button'));
  if (await tester.any(profileButton)) {
    await tester.tap(profileButton);
    await tester.pumpAndSettle();
  }

  final logoutButton = find.byKey(const Key('logout_button'));
  if (await tester.any(logoutButton)) {
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();
  }

  expect(find.text('Login'), findsOneWidget);
}

// Shopping test helpers
Future<void> _testProductBrowsing(WidgetTester tester) async {
  final productsButton = find.byKey(const Key('products_button'));
  if (await tester.any(productsButton)) {
    await tester.tap(productsButton);
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsWidgets);
  }
}

Future<void> _testCartOperations(WidgetTester tester) async {
  final addToCartButton = find.byKey(const Key('add_to_cart'));
  if (await tester.any(addToCartButton)) {
    await tester.tap(addToCartButton.first);
    await tester.pumpAndSettle();

    expect(find.text('Item added to cart'), findsOneWidget);
  }

  final cartButton = find.byKey(const Key('cart_button'));
  if (await tester.any(cartButton)) {
    await tester.tap(cartButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cart_items')), findsOneWidget);
  }
}

Future<void> _testCheckout(WidgetTester tester) async {
  final checkoutButton = find.byKey(const Key('checkout_button'));
  if (await tester.any(checkoutButton)) {
    await tester.tap(checkoutButton);
    await tester.pumpAndSettle();

    // Fill checkout form
    await tester.enterText(
      find.byKey(const Key('shipping_name')),
      'John Doe'
    );
    await tester.enterText(
      find.byKey(const Key('shipping_address')),
      '123 Main Street'
    );

    await tester.tap(find.byKey(const Key('place_order')));
    await tester.pumpAndSettle();

    expect(find.text('Order placed successfully'), findsOneWidget);
  }
}

// Performance test helpers
Future<void> _testAppStartup(WidgetTester tester) async {
  final stopwatch = Stopwatch()..start();
  
  app.main();
  await tester.pumpAndSettle();
  
  stopwatch.stop();
  
  expect(stopwatch.elapsedMilliseconds, lessThan(5000));
  expect(find.byType(MaterialApp), findsOneWidget);
}

Future<void> _testScrollingPerformance(WidgetTester tester) async {
  final scrollable = find.byType(SingleChildScrollView);
  if (await tester.any(scrollable)) {
    for (int i = 0; i < 3; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  }
}

Future<void> _testMemoryUsage(WidgetTester tester) async {
  // Basic memory check - in real scenarios, you'd use Flutter's memory profiling
  final images = find.byType(Image);
  if (await tester.any(images)) {
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(Image), findsWidgets);
  }
}

// Error handling test helpers
Future<void> _testNetworkErrors(WidgetTester tester) async {
  final loginButton = find.byKey(const Key('login_button'));
  if (await tester.any(loginButton)) {
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('email_field')),
      'test@example.com'
    );
    await tester.enterText(
      find.byKey(const Key('password_field')),
      'password123'
    );

    await tester.tap(find.byKey(const Key('submit_login')));
    await tester.pumpAndSettle();

    // Verify error handling
    expect(
      find.any((widget) => 
        widget is Text && 
        (widget.data?.contains('network') == true || 
         widget.data?.contains('error') == true)
      ),
      findsOneWidget,
    );
  }
}

Future<void> _testInvalidInputs(WidgetTester tester) async {
  final registerButton = find.byKey(const Key('register_button'));
  if (await tester.any(registerButton)) {
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    // Test invalid email
    await tester.enterText(
      find.byKey(const Key('email_field')),
      'invalid-email'
    );
    await tester.tap(find.byKey(const Key('submit_registration')));
    await tester.pumpAndSettle();

    expect(
      find.any((widget) => 
        widget is Text && 
        widget.data?.contains('email') == true
      ),
      findsOneWidget,
    );
  }
}

Future<void> _testEdgeCases(WidgetTester tester) async {
  // Test rapid button presses
  final buttons = find.byType(ElevatedButton);
  if (await tester.any(buttons)) {
    for (int i = 0; i < 3; i++) {
      await tester.tap(buttons.first);
      await tester.pumpAndSettle();
    }
    
    // Verify app remains stable
    expect(find.byType(MaterialApp), findsOneWidget);
  }
} 