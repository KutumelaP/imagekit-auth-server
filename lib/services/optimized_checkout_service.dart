import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optimized service to handle checkout initialization in the background
class OptimizedCheckoutService {
  static final OptimizedCheckoutService _instance = OptimizedCheckoutService._internal();
  factory OptimizedCheckoutService() => _instance;
  OptimizedCheckoutService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache for frequently accessed data
  static Map<String, dynamic>? _cachedSellerData;
  static String? _cachedSellerId;
  static DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 10);
  
  // Pre-computed values to avoid recalculation
  static List<String>? _cachedPaymentMethods;
  static Map<String, dynamic>? _cachedPlatformConfig;
  static Map<String, dynamic>? _cachedUserDraft;

  /// Pre-load checkout data in the background for faster initialization
  static Future<CheckoutData> preloadCheckoutData() async {
    final service = OptimizedCheckoutService();
    final startTime = DateTime.now();
    
    try {
      // Run multiple operations in parallel instead of sequentially
      final futures = await Future.wait([
        service._getCartItemsAndSellerId(),
        service._getCachedUserDraft(),
        service._getPlatformConfig(),
      ]);
      
      final cartData = futures[0] as Map<String, dynamic>?;
      final userDraft = futures[1] as Map<String, dynamic>?;
      final platformConfig = futures[2] as Map<String, dynamic>?;
      
      String? sellerId;
      List<Map<String, dynamic>> cartItems = [];
      String productCategory = 'other';
      
      if (cartData != null) {
        sellerId = cartData['sellerId'];
        cartItems = cartData['items'] ?? [];
        productCategory = cartData['category'] ?? 'other';
      }
      
      // Get seller data if we have a seller ID
      Map<String, dynamic>? sellerData;
      if (sellerId != null) {
        sellerData = await service._getCachedSellerData(sellerId);
      }
      
      final endTime = DateTime.now();
      final loadTime = endTime.difference(startTime).inMilliseconds;
      
      if (kDebugMode) {
        print('⚡ Optimized checkout preload completed in ${loadTime}ms');
      }
      
      return CheckoutData(
        cartItems: cartItems,
        sellerData: sellerData,
        userDraft: userDraft,
        platformConfig: platformConfig,
        productCategory: productCategory,
        loadTimeMs: loadTime,
      );
      
    } catch (e) {
      if (kDebugMode) print('❌ Error preloading checkout data: $e');
      return CheckoutData.empty();
    }
  }

  /// Get cart items and determine seller ID efficiently
  Future<Map<String, dynamic>?> _getCartItemsAndSellerId() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    try {
      // Use get() with source cache first for faster response
      final cartSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2))
          .catchError((_) async {
            // Fallback to server if cache fails
            return await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('cart')
                .get();
          });
      
      if (cartSnapshot.docs.isEmpty) return null;
      
      final items = cartSnapshot.docs.map((doc) => doc.data()).toList();
      final firstItem = cartSnapshot.docs.first.data();
      final sellerId = firstItem['sellerId'] ?? firstItem['ownerId'];
      
      // Determine product category efficiently
      String category = 'other';
      bool hasFood = false;
      bool hasNonFood = false;
      
      for (final item in items) {
        final itemCategory = item['category']?.toString().toLowerCase() ?? '';
        if (itemCategory == 'food') {
          hasFood = true;
        } else {
          hasNonFood = true;
        }
        
        // Early exit if we have both types
        if (hasFood && hasNonFood) {
          category = 'mixed';
          break;
        }
      }
      
      if (category != 'mixed') {
        category = hasFood ? 'food' : 'other';
      }
      
      return {
        'sellerId': sellerId,
        'items': items,
        'category': category,
        'hasFood': hasFood,
        'hasNonFood': hasNonFood,
      };
      
    } catch (e) {
      if (kDebugMode) print('❌ Error getting cart items: $e');
      return null;
    }
  }

  /// Get seller data with intelligent caching
  Future<Map<String, dynamic>?> _getCachedSellerData(String sellerId) async {
    // Return cached data if valid
    if (_isCacheValid() && _cachedSellerId == sellerId && _cachedSellerData != null) {
      if (kDebugMode) print('💾 Using cached seller data');
      return _cachedSellerData;
    }
    
    try {
      // Try cache first, then server
      final sellerDoc = await _firestore
          .collection('users')
          .doc(sellerId)
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2))
          .catchError((_) async {
            return await _firestore.collection('users').doc(sellerId).get();
          });
      
      if (!sellerDoc.exists) return null;
      
      final sellerData = sellerDoc.data()!;
      
      // Cache the result
      _cachedSellerData = sellerData;
      _cachedSellerId = sellerId;
      _lastCacheTime = DateTime.now();
      
      return sellerData;
      
    } catch (e) {
      if (kDebugMode) print('❌ Error getting seller data: $e');
      return null;
    }
  }

  /// Get user draft data from SharedPreferences efficiently
  Future<Map<String, dynamic>?> _getCachedUserDraft() async {
    // Return cached draft if already loaded
    if (_cachedUserDraft != null) {
      return _cachedUserDraft;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final draft = {
        'name': prefs.getString('checkout_name'),
        'address': prefs.getString('checkout_address'),
        'phone': prefs.getString('checkout_phone'),
        'instructions': prefs.getString('checkout_instructions'),
        'isDelivery': prefs.getBool('checkout_is_delivery'),
        'paymentMethod': prefs.getString('checkout_payment_method'),
      };
      
      // Cache for subsequent calls
      _cachedUserDraft = draft;
      
      return draft;
      
    } catch (e) {
      if (kDebugMode) print('❌ Error getting user draft: $e');
      return null;
    }
  }

  /// Get platform configuration with caching
  Future<Map<String, dynamic>?> _getPlatformConfig() async {
    // Return cached config if valid
    if (_cachedPlatformConfig != null) {
      return _cachedPlatformConfig;
    }
    
    try {
      // Try cache first for faster response
      final platformDoc = await _firestore
          .collection('config')
          .doc('platform')
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 1))
          .catchError((_) async {
            return await _firestore.collection('config').doc('platform').get();
          });
      
      final config = platformDoc.exists ? platformDoc.data() : null;
      
      // Cache the result
      _cachedPlatformConfig = config ?? {};
      
      return _cachedPlatformConfig;
      
    } catch (e) {
      if (kDebugMode) print('❌ Error getting platform config: $e');
      return {};
    }
  }

  /// Check if cached data is still valid
  bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  /// Clear all cached data
  static void clearCache() {
    _cachedSellerData = null;
    _cachedSellerId = null;
    _lastCacheTime = null;
    _cachedPaymentMethods = null;
    _cachedPlatformConfig = null;
    _cachedUserDraft = null;
    if (kDebugMode) print('🗑️ Checkout cache cleared');
  }

  /// Pre-warm the cache with data (call this from cart screen)
  static Future<void> prewarmCache() async {
    if (kDebugMode) print('🔥 Pre-warming checkout cache...');
    
    try {
      // Start preloading in background without waiting
      preloadCheckoutData();
    } catch (e) {
      if (kDebugMode) print('⚠️ Error pre-warming cache: $e');
    }
  }
}

/// Data class to hold preloaded checkout information
class CheckoutData {
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic>? sellerData;
  final Map<String, dynamic>? userDraft;
  final Map<String, dynamic>? platformConfig;
  final String productCategory;
  final int loadTimeMs;

  CheckoutData({
    required this.cartItems,
    this.sellerData,
    this.userDraft,
    this.platformConfig,
    required this.productCategory,
    required this.loadTimeMs,
  });

  factory CheckoutData.empty() {
    return CheckoutData(
      cartItems: [],
      productCategory: 'other',
      loadTimeMs: 0,
    );
  }

  bool get hasData => cartItems.isNotEmpty || sellerData != null;
  bool get isEmpty => !hasData;
}
