import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistSystem {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Add product to wishlist
  static Future<bool> addToWishlist({
    required String productId,
    required String productName,
    required String storeId,
    required String storeName,
    double? price,
    String? imageUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wishlist')
          .doc(productId)
          .set({
        'productId': productId,
        'productName': productName,
        'storeId': storeId,
        'storeName': storeName,
        'price': price,
        'imageUrl': imageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error adding to wishlist: $e');
      return false;
    }
  }

  /// Remove product from wishlist
  static Future<bool> removeFromWishlist(String productId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wishlist')
          .doc(productId)
          .delete();

      return true;
    } catch (e) {
      print('Error removing from wishlist: $e');
      return false;
    }
  }

  /// Check if product is in wishlist
  static Future<bool> isInWishlist(String productId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wishlist')
          .doc(productId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking wishlist status: $e');
      return false;
    }
  }

  /// Get user's wishlist
  static Future<List<Map<String, dynamic>>> getWishlist() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wishlist')
          .orderBy('addedAt', descending: true)
          .get();

      List<Map<String, dynamic>> wishlist = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['wishlistId'] = doc.id;
        wishlist.add(data);
      }

      return wishlist;
    } catch (e) {
      print('Error getting wishlist: $e');
      return [];
    }
  }

  /// Get wishlist count
  static Future<int> getWishlistCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wishlist')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting wishlist count: $e');
      return 0;
    }
  }

  /// Clear entire wishlist
  static Future<bool> clearWishlist() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wishlist')
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error clearing wishlist: $e');
      return false;
    }
  }

  /// Move wishlist item to cart
  static Future<bool> moveToCart(String productId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Get wishlist item
      DocumentSnapshot wishlistDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wishlist')
          .doc(productId)
          .get();

      if (!wishlistDoc.exists) return false;

      Map<String, dynamic> wishlistData = wishlistDoc.data() as Map<String, dynamic>;

      // Add to cart
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .add({
        'productId': productId,
        'productName': wishlistData['productName'],
        'storeId': wishlistData['storeId'],
        'storeName': wishlistData['storeName'],
        'price': wishlistData['price'],
        'quantity': 1,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Remove from wishlist
      await removeFromWishlist(productId);

      return true;
    } catch (e) {
      print('Error moving to cart: $e');
      return false;
    }
  }

  /// Get wishlist statistics
  static Future<Map<String, dynamic>> getWishlistStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      List<Map<String, dynamic>> wishlist = await getWishlist();
      
      double totalValue = 0;
      Map<String, int> storeCounts = {};
      List<String> categories = [];

      for (var item in wishlist) {
        double price = (item['price'] ?? 0.0).toDouble();
        totalValue += price;

        String storeId = item['storeId'] ?? '';
        storeCounts[storeId] = (storeCounts[storeId] ?? 0) + 1;
      }

      return {
        'totalItems': wishlist.length,
        'totalValue': totalValue,
        'uniqueStores': storeCounts.length,
        'mostFrequentStore': storeCounts.isNotEmpty 
            ? storeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key 
            : null,
      };
    } catch (e) {
      print('Error getting wishlist stats: $e');
      return {};
    }
  }

  /// Share wishlist
  static Future<String?> shareWishlist() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      List<Map<String, dynamic>> wishlist = await getWishlist();
      
      if (wishlist.isEmpty) return null;

      // Create shareable wishlist
      DocumentReference shareDoc = await _firestore
          .collection('shared_wishlists')
          .add({
        'userId': user.uid,
        'userName': user.displayName ?? 'User',
        'items': wishlist,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });

      return shareDoc.id;
    } catch (e) {
      print('Error sharing wishlist: $e');
      return null;
    }
  }

  /// Get shared wishlist
  static Future<Map<String, dynamic>?> getSharedWishlist(String shareId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('shared_wishlists')
          .doc(shareId)
          .get();

      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Check if expired
      Timestamp expiresAt = data['expiresAt'];
      if (expiresAt.toDate().isBefore(DateTime.now())) {
        return null;
      }

      return data;
    } catch (e) {
      print('Error getting shared wishlist: $e');
      return null;
    }
  }
} 