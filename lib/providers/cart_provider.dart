import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _items.length;
  
  double get totalPrice {
    return _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  // Check if user is authenticated
  bool get isAuthenticated => FirebaseAuth.instance.currentUser != null;

  // Cart operations
  Future<bool> addItem(String productId, String productName, double price, String imageUrl, String sellerId, {int? availableStock}) async {
    final existingIndex = _items.indexWhere((item) => item.id == productId);
    
    // Check stock availability if provided
    if (availableStock != null) {
      final currentCartQuantity = existingIndex >= 0 ? _items[existingIndex].quantity : 0;
      if (currentCartQuantity + 1 > availableStock) {
        return false; // Cannot add more items, insufficient stock
      }
    }
    
    if (existingIndex >= 0) {
      // Item exists, increment quantity
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + 1,
      );
    } else {
      // Add new item
      _items.add(CartItem(
        id: productId,
        name: productName,
        price: price,
        quantity: 1,
        imageUrl: imageUrl,
        sellerName: sellerId,
      ));
    }
    
    notifyListeners();
    
    // Only save to Firestore if user is authenticated
    if (isAuthenticated) {
      await _saveToFirestore();
    }
    
    return true; // Successfully added
  }

  Future<void> addToCart(CartItem item) async {
    final existingIndex = _items.indexWhere((cartItem) => cartItem.id == item.id);
    
    if (existingIndex >= 0) {
      // Item exists, increment quantity
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + 1,
      );
    } else {
      // Add new item
      _items.add(item);
    }
    
    notifyListeners();
    
    // Only save to Firestore if user is authenticated
    if (isAuthenticated) {
      await _saveToFirestore();
    }
  }

  void removeFromCart(String productId) {
    _items.removeWhere((item) => item.id == productId);
    notifyListeners();
    
    // Only save to Firestore if user is authenticated
    if (isAuthenticated) {
      _saveToFirestore();
    }
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    
    final index = _items.indexWhere((item) => item.id == productId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: quantity);
      notifyListeners();
      
      // Only save to Firestore if user is authenticated
      if (isAuthenticated) {
        _saveToFirestore();
      }
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
    
    // Only save to Firestore if user is authenticated
    if (isAuthenticated) {
      _saveToFirestore();
    }
  }

  // Clear cart when user changes (for logout/login scenarios)
  void clearCartOnUserChange() {
    _items.clear();
    notifyListeners();
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
      
      // Add current cart items
      for (var item in _items) {
        await cartRef.doc(item.id).set({
          'productId': item.id,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'imageUrl': item.imageUrl,
          'sellerId': item.sellerName,
        });
      }
          
    } catch (e) {
      _error = 'Failed to save cart: $e';
      print('🔍 DEBUG: Cart save error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
      
      _items = cartSnapshot.docs.map((doc) {
        final data = doc.data();
        return CartItem(
          id: data['productId'] ?? doc.id,
          name: data['name'] ?? '',
          price: (data['price'] ?? 0).toDouble(),
          quantity: data['quantity'] ?? 1,
          imageUrl: data['imageUrl'] ?? '',
          sellerName: data['sellerId'] ?? '',
        );
      }).toList();
      
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
    return _items.isNotEmpty && _items.every((item) => item.quantity > 0);
  }

  // Get unique sellers in cart
  List<String> get uniqueSellers {
    return _items.map((item) => item.sellerName).toSet().toList();
  }

  // Get cart items by seller
  List<CartItem> getItemsBySeller(String sellerName) {
    return _items.where((item) => item.sellerName == sellerName).toList();
  }

  // Calculate shipping cost (placeholder)
  double get shippingCost {
    if (_items.isEmpty) return 0.0;
    // Simple shipping calculation - could be more complex
    return uniqueSellers.length * 5.0; // R5 per seller
  }

  double get totalWithShipping => totalPrice + shippingCost;
} 