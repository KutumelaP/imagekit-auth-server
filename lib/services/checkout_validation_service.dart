import 'package:cloud_firestore/cloud_firestore.dart';

class CheckoutValidationResult {
  final bool isValid;
  final String? errorMessage;

  const CheckoutValidationResult._(this.isValid, this.errorMessage);

  factory CheckoutValidationResult.ok() => const CheckoutValidationResult._(true, null);
  factory CheckoutValidationResult.error(String message) => CheckoutValidationResult._(false, message);
}

class CheckoutValidationService {
  static Future<CheckoutValidationResult> validate({
    required List<String> excludedZones,
    required String addressText,
    required double totalPrice,
    required String? currentUserId,
    double? minOrderForDelivery,
    String? selectedServiceFilter, // 'paxi', 'pargo', etc.
    String? selectedPaxiDeliverySpeed, // 'standard' | 'express'
    Map<String, dynamic>? selectedPickupPoint,
    Map<String, dynamic>? pudoDeliveryAddress,
    String? pudoDeliveryPhone,
    required bool isDelivery,
    FirebaseFirestore? firestore,
  }) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;

      // 1) Zone exclusion check
      if (excludedZones.isNotEmpty && addressText.isNotEmpty) {
        final address = addressText.toLowerCase();
        final blocked = excludedZones.any((z) => address.contains(z.toLowerCase()));
        if (blocked) {
          return CheckoutValidationResult.error('Delivery is not available to your address');
        }
      }
      
      // 1.5) Basic address validation for delivery
      print('🔍 Validation: isDelivery=$isDelivery, addressText="$addressText", length=${addressText.length}');
      
      if (isDelivery && (addressText.isEmpty || addressText.length < 5)) {
        print('❌ Validation: Address validation failed - empty or too short');
        return CheckoutValidationResult.error('Please enter a valid delivery address');
      }
      
      print('✅ Validation: Address validation passed');

      // 2) Minimum order for delivery
      if (isDelivery && minOrderForDelivery != null && totalPrice < minOrderForDelivery) {
        return CheckoutValidationResult.error(
          'Minimum order for delivery is R${minOrderForDelivery.toStringAsFixed(2)}',
        );
      }

      // 3) PAXI delivery speed selection, when applicable
      if (!isDelivery && selectedServiceFilter == 'paxi' && (selectedPaxiDeliverySpeed == null || selectedPaxiDeliverySpeed.isEmpty)) {
        return CheckoutValidationResult.error('Please select a PAXI delivery speed');
      }

      // 3.5) PUDO Locker-to-Door validation
      if (!isDelivery && selectedPickupPoint?['type'] == 'pudo') {
        if (pudoDeliveryAddress == null || pudoDeliveryAddress.isEmpty) {
          return CheckoutValidationResult.error('Please enter delivery address for PUDO Locker-to-Door service');
        }
        if (pudoDeliveryPhone == null || pudoDeliveryPhone.isEmpty) {
          return CheckoutValidationResult.error('Please enter phone number for PUDO delivery coordination');
        }
      }

      // 4) Cart not empty
      if (currentUserId == null || currentUserId.isEmpty) {
        return CheckoutValidationResult.error('Please log in to place an order');
      }

      final cartSnapshot = await db
          .collection('users')
          .doc(currentUserId)
          .collection('cart')
          .get();

      if (cartSnapshot.docs.isEmpty) {
        return CheckoutValidationResult.error('Your cart is empty');
      }

      // 5) Stock checks for items with stock tracking
      for (final doc in cartSnapshot.docs) {
        final item = doc.data();
        final productId = item['id'] ?? item['productId'];
        if (productId == null) continue;

        final productDoc = await db.collection('products').doc(productId).get();
        if (!productDoc.exists) {
          final name = (item['name'] ?? productId).toString();
          return CheckoutValidationResult.error('Product not found: $name');
        }

        final product = productDoc.data()!;

        int resolveStock(dynamic value) {
          if (value is int) return value;
          if (value is num) return value.toInt();
          if (value is String) return int.tryParse(value) ?? 0;
          return 0;
        }

        final bool hasExplicitStock = product.containsKey('stock') || product.containsKey('quantity');
        final int stock = hasExplicitStock
            ? (product.containsKey('stock')
                ? resolveStock(product['stock'])
                : resolveStock(product['quantity']))
            : 999999;
        final int quantity = resolveStock(item['quantity'] ?? 1);

        if (hasExplicitStock && quantity > stock) {
          final name = (item['name'] ?? 'an item').toString();
          return CheckoutValidationResult.error('Not enough stock for $name');
        }
      }

      return CheckoutValidationResult.ok();
    } catch (e) {
      return CheckoutValidationResult.error('Error validating order: $e');
    }
  }
}

