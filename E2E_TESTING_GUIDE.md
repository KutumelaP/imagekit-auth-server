# E2E Testing Guide for Marketplace App

## Overview

This guide covers the comprehensive End-to-End (E2E) testing setup for the Marketplace App. The E2E testing framework includes authentication flows, shopping journeys, performance testing, and error handling scenarios.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code
- Physical device or emulator for testing

### Running E2E Tests

```bash
# Run all E2E tests
flutter test integration_test/

# Run specific test file
flutter test integration_test/auth_e2e_test.dart

# Run with verbose output
flutter test integration_test/ --verbose

# Run on specific device
flutter test integration_test/ -d <device-id>
```

## 📁 Test Structure

```
integration_test/
├── app_test.dart              # Main comprehensive E2E tests
├── auth_e2e_test.dart         # Authentication flow tests
├── shopping_e2e_test.dart     # Shopping and checkout tests
├── performance_error_e2e_test.dart  # Performance and error handling
└── run_e2e_tests.dart        # Centralized test runner
```

## 🧪 Test Categories

### 1. Authentication Tests (`auth_e2e_test.dart`)

**Coverage:**
- User registration flow
- Login with valid/invalid credentials
- Password reset functionality
- Logout process
- Session management

**Key Test Scenarios:**
```dart
testWidgets('Complete registration flow', (tester) async {
  // Navigate to registration
  // Fill registration form
  // Submit and verify success
});

testWidgets('Login with valid credentials', (tester) async {
  // Navigate to login
  // Enter credentials
  // Verify successful login
});
```

### 2. Shopping Tests (`shopping_e2e_test.dart`)

**Coverage:**
- Product browsing and search
- Cart management (add/remove items)
- Checkout process
- Order history
- Product filtering and sorting

**Key Test Scenarios:**
```dart
testWidgets('Complete shopping journey', (tester) async {
  // Login user
  // Browse products
  // Add to cart
  // Checkout
  // Complete order
});
```

### 3. Performance Tests (`performance_error_e2e_test.dart`)

**Coverage:**
- App startup time
- Memory usage monitoring
- Scrolling performance
- Image loading performance
- Network error handling
- Invalid input validation

**Key Test Scenarios:**
```dart
testWidgets('App startup performance', (tester) async {
  final stopwatch = Stopwatch()..start();
  app.main();
  await tester.pumpAndSettle();
  stopwatch.stop();
  expect(stopwatch.elapsedMilliseconds, lessThan(5000));
});
```

## 🔧 Test Configuration

### Dependencies

The following dependencies are required for E2E testing:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_driver:
    sdk: flutter
  test: ^1.24.0
  mockito: ^5.4.4
  golden_toolkit: ^0.15.0
```

### Test Keys

All interactive elements in the app should have unique keys for reliable testing:

```dart
// Example keys used in tests
const Key('login_button')
const Key('register_button')
const Key('email_field')
const Key('password_field')
const Key('submit_login')
const Key('add_to_cart')
const Key('cart_button')
const Key('checkout_button')
```

## 📊 Test Reports

### Running Tests with Reports

```bash
# Generate HTML report
flutter test integration_test/ --reporter=expanded

# Run with coverage
flutter test integration_test/ --coverage

# Generate detailed report
flutter test integration_test/ --reporter=json
```

### Test Metrics

The E2E tests track the following metrics:

1. **Performance Metrics:**
   - App startup time (< 5 seconds)
   - Memory usage
   - Scrolling performance
   - Image loading time

2. **Functional Metrics:**
   - Authentication success rate
   - Shopping flow completion rate
   - Error handling effectiveness
   - User journey completion

3. **Quality Metrics:**
   - Test coverage percentage
   - Test execution time
   - Failure rate
   - Flaky test detection

## 🛠️ Best Practices

### 1. Test Organization

- **Group related tests** using `group()` function
- **Use descriptive test names** that explain the scenario
- **Keep tests independent** - each test should be self-contained
- **Use helper functions** for common operations

### 2. Test Data Management

```dart
// Use unique test data to avoid conflicts
final email = 'testuser${DateTime.now().millisecondsSinceEpoch}@example.com';

// Clean up test data after tests
tearDown(() async {
  // Cleanup logic
});
```

### 3. Error Handling

```dart
// Test error scenarios
testWidgets('Network error handling', (tester) async {
  // Simulate network error
  // Verify error message is displayed
  // Test recovery mechanisms
});
```

### 4. Performance Testing

```dart
// Measure performance metrics
final stopwatch = Stopwatch()..start();
// Perform action
stopwatch.stop();
expect(stopwatch.elapsedMilliseconds, lessThan(threshold));
```

## 🔍 Debugging Tests

### Common Issues and Solutions

1. **Element Not Found:**
   ```dart
   // Use find.byKey() for reliable element selection
   final button = find.byKey(const Key('login_button'));
   ```

2. **Timing Issues:**
   ```dart
   // Use pumpAndSettle() to wait for animations
   await tester.pumpAndSettle();
   ```

3. **State Management:**
   ```dart
   // Reset app state between tests
   setUp(() async {
     // Reset app state
   });
   ```

### Debug Commands

```bash
# Run tests with debug output
flutter test integration_test/ --verbose

# Run single test with debug
flutter test integration_test/auth_e2e_test.dart --verbose

# Run with observatory
flutter test integration_test/ --observatory-port=8888
```

## 📱 Platform-Specific Testing

### Mobile Testing

```bash
# Run on Android
flutter test integration_test/ -d android

# Run on iOS
flutter test integration_test/ -d ios
```

### Web Testing

```bash
# Run on Chrome
flutter test integration_test/ -d chrome

# Run on Firefox
flutter test integration_test/ -d firefox
```

### Desktop Testing

```bash
# Run on Windows
flutter test integration_test/ -d windows

# Run on macOS
flutter test integration_test/ -d macos

# Run on Linux
flutter test integration_test/ -d linux
```

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - run: flutter pub get
      - run: flutter test integration_test/
```

### Local CI Setup

```bash
# Run tests before commit
git add .
flutter test integration_test/
git commit -m "Add E2E tests"
```

## 📈 Monitoring and Analytics

### Test Metrics Dashboard

Track the following metrics over time:

1. **Test Execution Time:**
   - Individual test duration
   - Total suite execution time
   - Performance trends

2. **Success Rates:**
   - Test pass/fail rates
   - Flaky test identification
   - Regression detection

3. **Coverage Metrics:**
   - Feature coverage
   - User journey coverage
   - Edge case coverage

## 🚨 Troubleshooting

### Common Problems

1. **Tests failing intermittently:**
   - Add longer wait times with `pumpAndSettle()`
   - Use `find.byKey()` instead of `find.text()`
   - Check for race conditions

2. **Element not found:**
   - Verify keys are properly set in the app
   - Check if element is visible and enabled
   - Use `tester.any()` to check element existence

3. **Performance issues:**
   - Optimize test data
   - Reduce unnecessary waits
   - Use efficient element selectors

### Getting Help

1. **Check test logs** for detailed error messages
2. **Run tests individually** to isolate issues
3. **Use debug mode** for step-by-step execution
4. **Review test documentation** for best practices

## 📚 Additional Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Integration Testing Guide](https://docs.flutter.dev/cookbook/testing/integration/introduction)
- [Widget Testing Guide](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Test Coverage](https://docs.flutter.dev/testing/code-coverage)

## 🤝 Contributing

When adding new E2E tests:

1. **Follow the existing structure** and naming conventions
2. **Add appropriate keys** to UI elements
3. **Include error handling** scenarios
4. **Document test purpose** and expected behavior
5. **Update this guide** with new test categories

---

**Last Updated:** December 2024  
**Version:** 1.0.0  
**Maintainer:** Development Team 