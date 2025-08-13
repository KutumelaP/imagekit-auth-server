import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/main.dart' as app;

void main() {
  group('Shopping E2E Tests', () {
    testWidgets('Complete shopping journey', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login first
      await _loginUser(tester);
      
      // Browse products
      await _browseProducts(tester);
      
      // Search for specific products
      await _searchProducts(tester);
      
      // Add items to cart
      await _addToCart(tester);
      
      // View cart
      await _viewCart(tester);
      
      // Proceed to checkout
      await _checkout(tester);
      
      // Complete order
      await _completeOrder(tester);
    });

    testWidgets('Product filtering and sorting', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _loginUser(tester);
      await _testProductFiltering(tester);
      await _testProductSorting(tester);
    });

    testWidgets('Cart management', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _loginUser(tester);
      await _testCartOperations(tester);
    });

    testWidgets('Order history and tracking', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _loginUser(tester);
      await _testOrderHistory(tester);
    });
  });
}

Future<void> _loginUser(WidgetTester tester) async {
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
}

Future<void> _browseProducts(WidgetTester tester) async {
  // Look for products or categories
  final productsButton = find.text('Products');
  if (await tester.any(productsButton)) {
    await tester.tap(productsButton);
    await tester.pumpAndSettle();
  }

  // Verify products are loaded
  expect(find.byType(Card), findsWidgets);
}

Future<void> _searchProducts(WidgetTester tester) async {
  final searchField = find.byType(TextField);
  if (await tester.any(searchField)) {
    await tester.enterText(searchField, 'organic vegetables');
    await tester.pumpAndSettle();
  }

  // Verify search results
  expect(find.byType(Card), findsWidgets);
}

Future<void> _addToCart(WidgetTester tester) async {
  // Find first product and add to cart
  final addToCartButtons = find.text('Add to Cart');
  if (await tester.any(addToCartButtons)) {
    await tester.tap(addToCartButtons.first);
    await tester.pumpAndSettle();
  }

  // Verify item added
  expect(find.text('Item added to cart'), findsOneWidget);
}

Future<void> _viewCart(WidgetTester tester) async {
  final cartButton = find.byIcon(Icons.shopping_cart);
  if (await tester.any(cartButton)) {
    await tester.tap(cartButton);
    await tester.pumpAndSettle();
  }

  // Verify cart contents
  expect(find.text('Cart'), findsOneWidget);
}

Future<void> _checkout(WidgetTester tester) async {
  final checkoutButton = find.text('Checkout');
  if (await tester.any(checkoutButton)) {
    await tester.tap(checkoutButton);
    await tester.pumpAndSettle();
  }

  // Fill shipping information
  final nameField = find.byType(TextFormField).at(0);
  final addressField = find.byType(TextFormField).at(1);
  final cityField = find.byType(TextFormField).at(2);
  final zipField = find.byType(TextFormField).at(3);
  final phoneField = find.byType(TextFormField).at(4);

  await tester.enterText(nameField, 'John Doe');
  await tester.enterText(addressField, '123 Main St');
  await tester.enterText(cityField, 'New York');
  await tester.enterText(zipField, '10001');
  await tester.enterText(phoneField, '1234567890');
  await tester.pumpAndSettle();

  // Fill payment information
  final cardNumberField = find.byType(TextFormField).at(5);
  final expiryField = find.byType(TextFormField).at(6);
  final cvvField = find.byType(TextFormField).at(7);

  await tester.enterText(cardNumberField, '4111111111111111');
  await tester.enterText(expiryField, '12/25');
  await tester.enterText(cvvField, '123');
  await tester.pumpAndSettle();
}

Future<void> _completeOrder(WidgetTester tester) async {
  final placeOrderButton = find.text('Place Order');
  if (await tester.any(placeOrderButton)) {
    await tester.tap(placeOrderButton);
    await tester.pumpAndSettle();
  }

  // Verify order confirmation
  expect(find.text('Order placed successfully'), findsOneWidget);
}

Future<void> _testProductFiltering(WidgetTester tester) async {
  final filterButton = find.text('Filter');
  if (await tester.any(filterButton)) {
    await tester.tap(filterButton);
    await tester.pumpAndSettle();

    // Select a category
    final categoryButton = find.text('Vegetables');
    if (await tester.any(categoryButton)) {
      await tester.tap(categoryButton);
      await tester.pumpAndSettle();
    }

    // Apply filter
    final applyButton = find.text('Apply');
    if (await tester.any(applyButton)) {
      await tester.tap(applyButton);
      await tester.pumpAndSettle();
    }
  }
}

Future<void> _testProductSorting(WidgetTester tester) async {
  final sortButton = find.text('Sort');
  if (await tester.any(sortButton)) {
    await tester.tap(sortButton);
    await tester.pumpAndSettle();

    // Select sort option
    final priceSortButton = find.text('Price: Low to High');
    if (await tester.any(priceSortButton)) {
      await tester.tap(priceSortButton);
      await tester.pumpAndSettle();
    }
  }
}

Future<void> _testCartOperations(WidgetTester tester) async {
  // Add item to cart
  final addToCartButtons = find.text('Add to Cart');
  if (await tester.any(addToCartButtons)) {
    await tester.tap(addToCartButtons.first);
    await tester.pumpAndSettle();
  }

  // View cart
  final cartButton = find.byIcon(Icons.shopping_cart);
  if (await tester.any(cartButton)) {
    await tester.tap(cartButton);
    await tester.pumpAndSettle();
  }

  // Update quantity
  final incrementButton = find.byIcon(Icons.add);
  if (await tester.any(incrementButton)) {
    await tester.tap(incrementButton);
    await tester.pumpAndSettle();
  }

  // Remove item
  final removeButton = find.byIcon(Icons.delete);
  if (await tester.any(removeButton)) {
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _testOrderHistory(WidgetTester tester) async {
  final ordersButton = find.text('Orders');
  if (await tester.any(ordersButton)) {
    await tester.tap(ordersButton);
    await tester.pumpAndSettle();
  }

  // Verify order history
  expect(find.text('Order History'), findsOneWidget);
} 