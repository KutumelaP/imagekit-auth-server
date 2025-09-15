import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Service for batching Firestore operations to reduce network calls and improve performance
class BatchOperationsService {
  static final BatchOperationsService _instance = BatchOperationsService._internal();
  factory BatchOperationsService() => _instance;
  BatchOperationsService._internal();

  /// Get cart data optimized for checkout
  Future<Map<String, dynamic>> getOptimizedCartData(String userId) async {
    final startTime = DateTime.now();
    
    final cartSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .get();

    final items = <Map<String, dynamic>>[];
    final cartItemsWithIds = <Map<String, dynamic>>[];
    String sellerId = '';

    for (final doc in cartSnapshot.docs) {
      final data = doc.data();
      items.add(data);
      cartItemsWithIds.add({
        'cartItemId': doc.id,
        ...data,
      });
      
      // Get seller ID from first item
      if (sellerId.isEmpty) {
        sellerId = data['sellerId'] ?? data['ownerId'] ?? '';
      }
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds;
    
    if (kDebugMode) {
      print('⚡ BatchOperationsService: Cart data fetched in ${duration}ms');
      print('📦 Items: ${items.length}, Seller: $sellerId');
    }

    return {
      'items': items,
      'cartItemsWithIds': cartItemsWithIds,
      'sellerId': sellerId,
    };
  }

  /// Validate stock for multiple products in parallel
  Future<List<Map<String, dynamic>>> batchStockValidation({
    required List<Map<String, dynamic>> cartItems,
  }) async {
    final startTime = DateTime.now();
    
    // Extract unique product IDs
    final productIds = cartItems
        .map((item) => item['id'] ?? item['productId'])
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    if (productIds.isEmpty) {
      return cartItems.map((item) => {
        'valid': false,
        'error': 'No product ID found',
        'name': item['name'] ?? 'Unknown',
      }).toList();
    }

    // Fetch all product documents in parallel
    final futures = productIds.map((productId) =>
        FirebaseFirestore.instance.collection('products').doc(productId).get()
    ).toList();

    final productDocs = await Future.wait(futures);
    
    // Create a map for quick lookup
    final productMap = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (int i = 0; i < productIds.length; i++) {
      productMap[productIds[i]] = productDocs[i];
    }

    // Validate each cart item
    final results = <Map<String, dynamic>>[];
    for (final item in cartItems) {
      final productId = item['id'] ?? item['productId'];
      final quantity = _resolveQuantity(item['quantity'] ?? 1);
      final productName = item['name'] ?? 'Unknown';

      if (productId == null) {
        results.add({
          'valid': false,
          'error': 'Missing product ID',
          'name': productName,
        });
        continue;
      }

      final productDoc = productMap[productId];
      if (productDoc == null || !productDoc.exists) {
        results.add({
          'valid': false,
          'error': 'Product not found',
          'name': productName,
        });
        continue;
      }

      final product = productDoc.data()!;
      final hasExplicitStock = product.containsKey('stock') || product.containsKey('quantity');
      
      if (!hasExplicitStock) {
        // No stock tracking - assume unlimited
        results.add({
          'valid': true,
          'name': productName,
          'stock': 'unlimited',
        });
        continue;
      }

      final stock = product.containsKey('stock')
          ? _resolveQuantity(product['stock'])
          : _resolveQuantity(product['quantity']);

      if (quantity > stock) {
        results.add({
          'valid': false,
          'error': 'Insufficient stock',
          'name': productName,
          'requested': quantity,
          'available': stock,
        });
      } else {
        results.add({
          'valid': true,
          'name': productName,
          'stock': stock,
        });
      }
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds;
    
    if (kDebugMode) {
      print('⚡ BatchOperationsService: Stock validation completed in ${duration}ms');
      print('✅ Valid: ${results.where((r) => r['valid']).length}');
      print('❌ Invalid: ${results.where((r) => !r['valid']).length}');
    }

    return results;
  }

  /// Batch decrement stock for multiple products atomically
  Future<void> batchStockDecrement({
    required List<Map<String, dynamic>> cartItems,
  }) async {
    final startTime = DateTime.now();
    
    for (final item in cartItems) {
      final productId = item['id'] ?? item['productId'];
      final quantity = _resolveQuantity(item['quantity'] ?? 1);
      
      if (productId == null) continue;

      final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
      
      // Use a transaction for each product to ensure atomicity
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);
        
        if (!snapshot.exists) return;
        
        final data = snapshot.data()!;
        final hasExplicitStock = data.containsKey('stock') || data.containsKey('quantity');
        
        if (!hasExplicitStock) return; // No stock tracking
        
        // Use the same logic as UI - take the maximum of both fields
        final int stockValue = _resolveQuantity(data['stock'] ?? 0);
        final int quantityValue = _resolveQuantity(data['quantity'] ?? 0);
        final int currentStock = math.max(stockValue, quantityValue);
        
        final int newStock = (currentStock - quantity).clamp(0, double.maxFinite.toInt());
        
        // Update both stock fields if they exist (keep them synchronized)
        if (data.containsKey('stock')) {
          transaction.update(productRef, {'stock': newStock});
        }
        if (data.containsKey('quantity')) {
          transaction.update(productRef, {'quantity': newStock});
        }
      });
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds;
    
    if (kDebugMode) {
      print('⚡ BatchOperationsService: Stock decrement completed in ${duration}ms');
      print('📦 Products updated: ${cartItems.length}');
    }
  }

  /// Batch clear cart items
  Future<void> batchClearCart({
    required String userId,
    required List<String> cartItemIds,
  }) async {
    final startTime = DateTime.now();
    
    final batch = FirebaseFirestore.instance.batch();
    
    for (final cartItemId in cartItemIds) {
      final cartItemRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(cartItemId);
      
      batch.delete(cartItemRef);
    }

    await batch.commit();

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds;
    
    if (kDebugMode) {
      print('⚡ BatchOperationsService: Cart clearing completed in ${duration}ms');
      print('🗑️ Items removed: ${cartItemIds.length}');
    }
  }

  /// Utility function to resolve quantity from various types
  int _resolveQuantity(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
