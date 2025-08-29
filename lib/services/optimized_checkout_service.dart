import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for optimizing checkout data fetching with parallel loading and caching
class OptimizedCheckoutService {
  static final OptimizedCheckoutService _instance = OptimizedCheckoutService._internal();
  factory OptimizedCheckoutService() => _instance;
  OptimizedCheckoutService._internal();

  // Cache for seller data with TTL
  static final Map<String, Map<String, dynamic>> _sellerCache = {};
  static final Map<String, DateTime> _sellerCacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(minutes: 10);

  /// Preload checkout data in parallel for faster UI rendering
  static Future<CheckoutData> preloadCheckoutData(String userId) async {
    final startTime = DateTime.now();
    
    try {
      // Parallel execution of independent operations
      final futures = await Future.wait([
        _getCartItemsAndSellerId(userId),
        _getUserDraft(userId),
        _getPlatformConfig(),
      ]);

      final cartData = futures[0] as Map<String, dynamic>;
      final userDraft = futures[1] as Map<String, dynamic>?;
      final platformConfig = futures[2] as Map<String, dynamic>?;

      // Get seller data if we have a seller ID
      Map<String, dynamic>? sellerData;
      final sellerId = cartData['sellerId'] as String?;
      if (sellerId != null && sellerId.isNotEmpty) {
        sellerData = await _getCachedSellerData(sellerId);
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      
      if (kDebugMode) {
        print('⚡ OptimizedCheckoutService: Preload completed in ${duration}ms');
        print('📦 Cart items: ${(cartData['items'] as List).length}');
        print('👤 User draft: ${userDraft != null ? "available" : "none"}');
        print('⚙️ Platform config: ${platformConfig != null ? "loaded" : "none"}');
        print('🏪 Seller data: ${sellerData != null ? "cached" : "none"}');
      }

      return CheckoutData(
        cartItems: cartData['items'] as List<Map<String, dynamic>>,
        sellerId: sellerId ?? '',
        productCategory: cartData['productCategory'] as String? ?? 'other',
        userDraft: userDraft,
        platformConfig: platformConfig,
        sellerData: sellerData,
      );
    } catch (e) {
      if (kDebugMode) print('❌ OptimizedCheckoutService preload error: $e');
      rethrow;
    }
  }

  /// Get cart items and determine seller ID
  static Future<Map<String, dynamic>> _getCartItemsAndSellerId(String userId) async {
    final cartSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .get();

    final items = cartSnapshot.docs.map((doc) => doc.data()).toList();
    
    // Determine seller ID and product category
    String sellerId = '';
    String productCategory = 'other';
    bool hasFoodItems = false;
    bool hasNonFoodItems = false;

    for (final item in items) {
      // Get seller ID
      if (sellerId.isEmpty) {
        sellerId = item['sellerId'] ?? item['ownerId'] ?? '';
      }

      // Categorize products
      final category = (item['category'] ?? '').toString().toLowerCase();
      if (category.contains('food') || category.contains('grocery') || 
          category.contains('restaurant') || category.contains('meal')) {
        hasFoodItems = true;
      } else {
        hasNonFoodItems = true;
      }
    }

    // Determine overall category
    if (hasFoodItems && hasNonFoodItems) {
      productCategory = 'mixed';
    } else if (hasFoodItems) {
      productCategory = 'food';
    } else if (hasNonFoodItems) {
      productCategory = 'other';
    }

    return {
      'items': items,
      'sellerId': sellerId,
      'productCategory': productCategory,
      'hasFoodItems': hasFoodItems,
      'hasNonFoodItems': hasNonFoodItems,
    };
  }

  /// Get user draft data
  static Future<Map<String, dynamic>?> _getUserDraft(String userId) async {
    try {
      final draftDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('drafts')
          .doc('checkout')
          .get();
      
      return draftDoc.exists ? draftDoc.data() : null;
    } catch (e) {
      if (kDebugMode) print('⚠️ Error loading user draft: $e');
      return null;
    }
  }

  /// Get platform configuration
  static Future<Map<String, dynamic>?> _getPlatformConfig() async {
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('platform')
          .get();
      
      return configDoc.exists ? configDoc.data() : null;
    } catch (e) {
      if (kDebugMode) print('⚠️ Error loading platform config: $e');
      return null;
    }
  }

  /// Get seller data with intelligent caching
  static Future<Map<String, dynamic>?> _getCachedSellerData(String sellerId) async {
    // Check cache first
    if (_sellerCache.containsKey(sellerId)) {
      final timestamp = _sellerCacheTimestamps[sellerId];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _cacheTimeout) {
        if (kDebugMode) print('📋 Seller data retrieved from cache: $sellerId');
        return _sellerCache[sellerId];
      } else {
        // Cache expired, remove old data
        _sellerCache.remove(sellerId);
        _sellerCacheTimestamps.remove(sellerId);
      }
    }

    try {
      // Cache miss or expired - fetch from Firestore
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();

      if (sellerDoc.exists) {
        final sellerData = sellerDoc.data()!;
        
        // Cache the data
        _sellerCache[sellerId] = sellerData;
        _sellerCacheTimestamps[sellerId] = DateTime.now();
        
        if (kDebugMode) print('🏪 Seller data fetched and cached: $sellerId');
        return sellerData;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching seller data: $e');
    }

    return null;
  }

  /// Clear cache (useful for testing or memory management)
  static void clearCache() {
    _sellerCache.clear();
    _sellerCacheTimestamps.clear();
    if (kDebugMode) print('🗑️ OptimizedCheckoutService cache cleared');
  }

  /// Pre-warm cache with frequently accessed data
  static Future<void> prewarmCache(String userId) async {
    try {
      final cartData = await _getCartItemsAndSellerId(userId);
      final sellerId = cartData['sellerId'] as String?;
      
      if (sellerId != null && sellerId.isNotEmpty) {
        await _getCachedSellerData(sellerId);
      }
      
      if (kDebugMode) print('🔥 Cache prewarmed for user: $userId');
    } catch (e) {
      if (kDebugMode) print('⚠️ Cache prewarm failed: $e');
    }
  }
}

/// Data class for checkout preload results
class CheckoutData {
  final List<Map<String, dynamic>> cartItems;
  final String sellerId;
  final String productCategory;
  final Map<String, dynamic>? userDraft;
  final Map<String, dynamic>? platformConfig;
  final Map<String, dynamic>? sellerData;

  CheckoutData({
    required this.cartItems,
    required this.sellerId,
    required this.productCategory,
    this.userDraft,
    this.platformConfig,
    this.sellerData,
  });

  /// Empty constructor for timeout fallback
  static CheckoutData empty() {
    return CheckoutData(
      cartItems: [],
      sellerId: '',
      productCategory: 'other',
      userDraft: null,
      platformConfig: null,
      sellerData: null,
    );
  }
}