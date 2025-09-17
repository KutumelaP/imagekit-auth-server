import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_item.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CartProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _localCartKey = 'local_cart_v1';
  
  // Store-separated carts: Map<storeId, List<CartItem>>
  Map<String, List<CartItem>> _storeCarts = {};
  String? _currentStoreId; // Currently active store
  bool _isLoading = false;
  String? _error;
  // Info about last add-to-cart operation
  String? lastAddNotice;
  bool lastAddClamped = false;
  int? lastAddedQuantity;
  // Add new fields for better error handling
  String? lastAddError;
  bool lastAddBlocked = false;

  CartProvider() {
    _loadFromLocal();
  }

  // Getters
  List<CartItem> get items => _currentStoreId != null ? _storeCarts[_currentStoreId] ?? [] : [];
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => items.length;
  
  // Store management
  String? get currentStoreId => _currentStoreId;
  List<String> get availableStoreIds => _storeCarts.keys.toList();
  
  // Get items for a specific store
  List<CartItem> getItemsForStore(String storeId) => _storeCarts[storeId] ?? [];
  
  // Get total price for current store
  double get totalPrice {
    return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }
  
  // Get total price for a specific store
  double getTotalPriceForStore(String storeId) {
    final storeItems = _storeCarts[storeId] ?? [];
    return storeItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }
  
  // Get total items across all stores
  int get totalItemsAcrossStores {
    return _storeCarts.values.fold(0, (sum, storeItems) => sum + storeItems.length);
  }

  // Check if user is authenticated
  bool get isAuthenticated => FirebaseAuth.instance.currentUser != null;

  // Cart operations
  Future<bool> addItem(String productId, String productName, double price, String imageUrl, String sellerId, String sellerName, String storeCategory, {int? quantity, int? availableStock, List<Map<String, dynamic>>? customizations, double? customPrice}) async {
    // Use provided quantity or default to 1
    int quantityToAdd = quantity ?? 1;
    // Reset last add info
    lastAddNotice = null;
    lastAddClamped = false;
    lastAddedQuantity = null;
    lastAddError = null;
    lastAddBlocked = false;
    
    // Prevent seller self-purchase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && sellerId == user.uid) {
      print('🛑 Self-purchase blocked: seller $sellerId attempted to add own product');
      lastAddError = 'You can\'t purchase from your store';
      lastAddBlocked = true;
      return false;
    }
    
    // Check if this is a different store than current cart
    if (_currentStoreId != null && _currentStoreId != sellerId) {
      // Ask user if they want to switch stores or clear current cart
      print('🔍 DEBUG: Adding item from different store. Current: $_currentStoreId, New: $sellerId');
      // For now, we'll automatically switch stores (you can add user confirmation later)
      _switchToStore(sellerId);
    }
    
    // Initialize store cart if it doesn't exist
    if (!_storeCarts.containsKey(sellerId)) {
      _storeCarts[sellerId] = [];
      _currentStoreId = sellerId;
    }
    
    final storeItems = _storeCarts[sellerId]!;
    final existingIndex = storeItems.indexWhere((item) => item.id == productId);
    
    // Check stock availability if provided (clamp instead of hard-fail)
    if (availableStock != null) {
      final currentCartQuantity = existingIndex >= 0 ? storeItems[existingIndex].quantity : 0;
      final remaining = availableStock - currentCartQuantity;
      if (remaining <= 0) {
        lastAddError = 'No more stock available for this product';
        return false; // already at max
      }
      if (quantityToAdd > remaining) {
        quantityToAdd = remaining; // clamp to remaining stock
        lastAddClamped = true;
        lastAddNotice = 'Added remaining stock ($remaining)';
      }
    }
    
    if (existingIndex >= 0) {
      // Item exists, increment quantity by the specified amount
      storeItems[existingIndex] = storeItems[existingIndex].copyWith(
        quantity: storeItems[existingIndex].quantity + quantityToAdd,
      );
    } else {
      // Add new item with specified quantity
      storeItems.add(CartItem(
        id: productId,
        name: productName,
        price: customPrice ?? price,
        quantity: quantityToAdd,
        imageUrl: imageUrl,
        sellerId: sellerId,
        sellerName: sellerName,
        storeCategory: storeCategory,
        availableStock: availableStock,
        customizations: customizations,
        customPrice: customPrice,
      ));
    }
    
    lastAddedQuantity = quantityToAdd;
    notifyListeners();
    _saveToLocal();
    
    // Only save to Firestore if user is authenticated
    if (isAuthenticated) {
      await _saveToFirestore();
    }
    
    return true; // Successfully added
  }

  // Store management methods
  void _switchToStore(String storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      print('🔍 DEBUG: Switched to store: $storeId');
      notifyListeners();
      _saveToLocal();
    }
  }
  
  // Switch to a different store
  void switchToStore(String storeId) {
    if (_storeCarts.containsKey(storeId)) {
      _switchToStore(storeId);
    } else {
      print('🔍 DEBUG: Store $storeId not found in carts');
    }
  }
  
  // Get current store info
  Map<String, dynamic>? getCurrentStoreInfo() {
    if (_currentStoreId == null) return null;
    
    final storeItems = _storeCarts[_currentStoreId]!;
    if (storeItems.isEmpty) return null;
    
    final firstItem = storeItems.first;
    return {
      'storeId': _currentStoreId,
      'storeName': firstItem.sellerName,
      'storeCategory': firstItem.storeCategory,
      'itemCount': storeItems.length,
      'totalPrice': getTotalPriceForStore(_currentStoreId!),
    };
  }
  
  // Get summary of all stores in cart
  List<Map<String, dynamic>> getAllStoresSummary() {
    final summaries = <Map<String, dynamic>>[];
    
    for (var storeId in _storeCarts.keys) {
      final storeItems = _storeCarts[storeId]!;
      if (storeItems.isNotEmpty) {
        final firstItem = storeItems.first;
        summaries.add({
          'storeId': storeId,
          'storeName': firstItem.sellerName,
          'storeCategory': firstItem.storeCategory,
          'itemCount': storeItems.length,
          'totalPrice': getTotalPriceForStore(storeId),
          'isCurrentStore': storeId == _currentStoreId,
        });
      }
    }
    
    return summaries;
  }
  
  Future<void> addToCart(CartItem item) async {
    // Reset last add info
    lastAddNotice = null;
    lastAddClamped = false;
    lastAddedQuantity = null;
    lastAddError = null;
    lastAddBlocked = false;
    
    // Prevent seller self-purchase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && item.sellerId == user.uid) {
      print('🛑 Self-purchase blocked: seller ${item.sellerId} attempted to add own product');
      lastAddError = 'You can\'t purchase from your store';
      lastAddBlocked = true;
      return;
    }
    // Check if this is a different store than current cart
    if (_currentStoreId != null && _currentStoreId != item.sellerId) {
      _switchToStore(item.sellerId);
    }
    
    // Initialize store cart if it doesn't exist
    if (!_storeCarts.containsKey(item.sellerId)) {
      _storeCarts[item.sellerId] = [];
      _currentStoreId = item.sellerId;
    }
    
    final storeItems = _storeCarts[item.sellerId]!;
    final existingIndex = storeItems.indexWhere((cartItem) => cartItem.id == item.id);
    
    if (existingIndex >= 0) {
      // Item exists, increment quantity
      storeItems[existingIndex] = storeItems[existingIndex].copyWith(
        quantity: storeItems[existingIndex].quantity + 1,
      );
    } else {
      // Add new item
      storeItems.add(item);
    }
    
    notifyListeners();
    _saveToLocal();
    
    // Only save to Firestore if user is authenticated
    if (isAuthenticated) {
      await _saveToFirestore();
    }
  }

  void removeFromCart(String productId) {
    if (_currentStoreId != null) {
      final storeItems = _storeCarts[_currentStoreId]!;
      storeItems.removeWhere((item) => item.id == productId);
      
      // If store cart is empty, remove the store
      if (storeItems.isEmpty) {
        _storeCarts.remove(_currentStoreId);
        _currentStoreId = _storeCarts.isNotEmpty ? _storeCarts.keys.first : null;
      }
      
      notifyListeners();
      _saveToLocal();
      
      // Only save to Firestore if user is authenticated
      if (isAuthenticated) {
        _saveToFirestore();
      }
    }
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    
    if (_currentStoreId != null) {
      final storeItems = _storeCarts[_currentStoreId]!;
      final index = storeItems.indexWhere((item) => item.id == productId);
      if (index >= 0) {
        final item = storeItems[index];
        
        // Check stock availability if provided
        if (item.availableStock != null && quantity > item.availableStock!) {
          // Don't allow quantity to exceed available stock
          print('🛑 Stock limit reached: Cannot set quantity $quantity, only ${item.availableStock} available');
          return;
        }
        
        storeItems[index] = item.copyWith(quantity: quantity);
        notifyListeners();
        _saveToLocal();
        
        // Only save to Firestore if user is authenticated
        if (isAuthenticated) {
          _saveToFirestore();
        }
      }
    }
  }

  // Check if an item can be incremented (has stock available)
  bool canIncrementQuantity(String productId) {
    if (_currentStoreId != null) {
      final storeItems = _storeCarts[_currentStoreId]!;
      final index = storeItems.indexWhere((item) => item.id == productId);
      if (index >= 0) {
        final item = storeItems[index];
        // If no stock info, allow increment (unlimited stock)
        if (item.availableStock == null) return true;
        // Check if current quantity is less than available stock
        return item.quantity < item.availableStock!;
      }
    }
    return false;
  }

  void clearCart() {
    _storeCarts.clear();
    _currentStoreId = null;
    notifyListeners();
    _saveToLocal();
    
    // Only save to Firestore if user is authenticated
    if (isAuthenticated) {
      _saveToFirestore();
    }
  }
  
  // Clear cart for a specific store
  void clearStoreCart(String storeId) {
    _storeCarts.remove(storeId);
    
    // If we cleared the current store, switch to another one
    if (_currentStoreId == storeId) {
      _currentStoreId = _storeCarts.isNotEmpty ? _storeCarts.keys.first : null;
    }
    
    notifyListeners();
    _saveToLocal();
    
    // Only save to Firestore if user is authenticated
    if (isAuthenticated) {
      _saveToFirestore();
    }
  }

  // Clear cart when user changes (for logout/login scenarios)
  void clearCartOnUserChange() {
    _storeCarts.clear();
    _currentStoreId = null;
    notifyListeners();
    _saveToLocal();
  }

  // Firestore operations
  Future<void> _saveToFirestore() async {
    if (!isAuthenticated) return; // Don't save if not authenticated
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser!;
      
      // Clear existing cart items
      final cartRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart');
      
      // Delete all existing cart items
      final existingItems = await cartRef.get();
      for (var doc in existingItems.docs) {
        await doc.reference.delete();
      }
      
      // Add all store cart items
      for (var storeId in _storeCarts.keys) {
        final storeItems = _storeCarts[storeId]!;
        for (var item in storeItems) {
          await cartRef.doc('${storeId}_${item.id}').set({
            'productId': item.id,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
            'imageUrl': item.imageUrl,
            'sellerId': item.sellerId,
            'sellerName': item.sellerName,
            'storeCategory': item.storeCategory,
            'storeId': storeId,
          });
        }
      }
          
    } catch (e) {
      _error = 'Failed to save cart: $e';
      print('🔍 DEBUG: Cart save error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= LOCAL PERSISTENCE =================
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {
        'currentStoreId': _currentStoreId,
        'storeCarts': _storeCarts.map((storeId, items) => MapEntry(
              storeId,
              items.map((e) => e.toMap()).toList(),
            )),
      };
      await prefs.setString(_localCartKey, jsonEncode(data));
    } catch (e) {
      print('❌ Failed to save local cart: $e');
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localCartKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final currentId = decoded['currentStoreId'] as String?;
      final storeCartsRaw = decoded['storeCarts'] as Map<String, dynamic>?;
      final Map<String, List<CartItem>> restored = {};
      if (storeCartsRaw != null) {
        storeCartsRaw.forEach((storeId, list) {
          final items = (list as List<dynamic>)
              .map((it) => CartItem.fromMap(Map<String, dynamic>.from(it as Map)))
              .toList();
          if (items.isNotEmpty) {
            restored[storeId] = items;
          }
        });
      }
      _storeCarts = restored;
      _currentStoreId = currentId ?? (restored.isNotEmpty ? restored.keys.first : null);
      notifyListeners();
    } catch (e) {
      print('❌ Failed to load local cart: $e');
    }
  }

  Future<void> loadCartFromFirestore() async {
    if (!isAuthenticated) return; // Don't load if not authenticated
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser!;
      
      final cartRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart');
      
      final cartSnapshot = await cartRef.get();
      
      // Group items by store
      final Map<String, List<CartItem>> storeCarts = {};
      
      for (var doc in cartSnapshot.docs) {
        final data = doc.data();
        final storeId = data['storeId'] ?? data['sellerId'] ?? '';
        
        if (storeId.isNotEmpty) {
          if (!storeCarts.containsKey(storeId)) {
            storeCarts[storeId] = [];
          }
          
          storeCarts[storeId]!.add(CartItem(
            id: data['productId'] ?? doc.id,
            name: data['name'] ?? '',
            price: (data['price'] ?? 0).toDouble(),
            quantity: data['quantity'] ?? 1,
            imageUrl: data['imageUrl'] ?? '',
            sellerId: data['sellerId'] ?? storeId,
            sellerName: data['sellerName'] ?? '',
            storeCategory: data['storeCategory'] ?? '',
          ));
        }
      }
      
      _storeCarts = storeCarts;
      _currentStoreId = storeCarts.isNotEmpty ? storeCarts.keys.first : null;
      
      print('🔍 DEBUG: Loaded ${storeCarts.length} store carts');
      notifyListeners();
      
    } catch (e) {
      _error = 'Failed to load cart: $e';
      print('🔍 DEBUG: Cart load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sync local cart to Firestore when user logs in
  Future<void> syncCartToFirestore() async {
    if (!isAuthenticated) return;
    
    await _saveToFirestore();
  }

  // Animation helpers
  void animateAddToCart(String productId) {
    // Trigger animation for add to cart
    notifyListeners();
  }

  void animateRemoveFromCart(String productId) {
    // Trigger animation for remove from cart
    notifyListeners();
  }

  // Cart validation
  bool get isCartValid {
    return _currentStoreId != null && 
           _storeCarts[_currentStoreId]!.isNotEmpty && 
           _storeCarts[_currentStoreId]!.every((item) => item.quantity > 0);
  }

  // Get unique stores in cart
  List<String> get uniqueStores {
    return _storeCarts.keys.toList();
  }

  // Get cart items by store
  List<CartItem> getItemsByStore(String storeId) {
    return _storeCarts[storeId] ?? [];
  }

  // Calculate shipping cost (placeholder)
  double get shippingCost {
    if (_currentStoreId == null || _storeCarts[_currentStoreId]!.isEmpty) return 0.0;
    // Simple shipping calculation - could be more complex
    return 25.0; // Base shipping cost per store
  }

  double get totalWithShipping => totalPrice + shippingCost;
} 