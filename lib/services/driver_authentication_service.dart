import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverAuthenticationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Comprehensive driver detection from multiple sources
  static Future<Map<String, dynamic>?> detectDriverProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return null;
      }

      print('🔍 Checking driver profile for user: ${user.uid}');

      // Method 1: Check global drivers collection
      final globalDriver = await _checkGlobalDriver(user.uid);
      if (globalDriver != null) {
        print('✅ Found global driver profile');
        return {
          'driverType': 'global',
          'driverId': user.uid,
          'sellerId': null,
          'driverData': globalDriver,
          'source': 'drivers',
        };
      }

      // Method 2: Check if user is a seller-owned driver
      final sellerDriver = await _checkSellerOwnedDriver(user.uid);
      if (sellerDriver != null) {
        print('✅ Found seller-owned driver profile');
        return sellerDriver;
      }

      // Method 3: Check if user has driver role in their profile
      final userDriver = await _checkUserDriverRole(user.uid);
      if (userDriver != null) {
        print('✅ Found user with driver role');
        return userDriver;
      }

      print('❌ No driver profile found for user: ${user.uid}');
      return null;
    } catch (e) {
      print('❌ Error detecting driver profile: $e');
      return null;
    }
  }

  /// Check global drivers collection
  static Future<Map<String, dynamic>?> _checkGlobalDriver(String userId) async {
    try {
      final driverDoc = await _firestore.collection('drivers').doc(userId).get();
      if (driverDoc.exists) {
        return driverDoc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error checking global driver: $e');
      return null;
    }
  }

  /// Check all seller subcollections for this driver
  static Future<Map<String, dynamic>?> _checkSellerOwnedDriver(String userId) async {
    try {
      // Query all users to find where this driver might be stored
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (final userDoc in usersSnapshot.docs) {
        final sellerId = userDoc.id;
        
        // Check if this user has drivers subcollection
        final driversQuery = await _firestore
            .collection('users')
            .doc(sellerId)
            .collection('drivers')
            .get();

        for (final driverDoc in driversQuery.docs) {
          final driverData = driverDoc.data();
          
          // Check if this driver matches by email, phone, or manual match
          if (_isMatchingDriver(driverData, userId)) {
            return {
              'driverType': 'seller_owned',
              'driverId': driverDoc.id,
              'driverDocId': driverDoc.id, // Add to top level for easy access
              'sellerId': sellerId,
              'driverData': {
                ...driverData,
                'driverDocId': driverDoc.id,
              },
              'source': 'users/$sellerId/drivers',
            };
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Error checking seller-owned drivers: $e');
      return null;
    }
  }

  /// Check if user profile has driver role
  static Future<Map<String, dynamic>?> _checkUserDriverRole(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final userType = userData['userType'] as String?;
        final roles = userData['roles'] as List?;
        
        if (userType == 'driver' || (roles?.contains('driver') == true)) {
          return {
            'driverType': 'user_profile',
            'driverId': userId,
            'sellerId': null,
            'driverData': userData,
            'source': 'users',
          };
        }
      }
      return null;
    } catch (e) {
      print('❌ Error checking user driver role: $e');
      return null;
    }
  }

  /// Check if driver data matches current user
  static bool _isMatchingDriver(Map<String, dynamic> driverData, String userId) {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Match by email
    if (driverData['email'] != null && 
        driverData['email'] == user.email) {
      return true;
    }

    // Match by phone
    if (driverData['phone'] != null && 
        user.phoneNumber != null &&
        driverData['phone'] == user.phoneNumber) {
      return true;
    }

    // Match by UID if stored
    if (driverData['userId'] != null && 
        driverData['userId'] == userId) {
      return true;
    }

    return false;
  }

  /// Register current user as a driver in global collection
  static Future<Map<String, dynamic>> registerGlobalDriver({
    required String name,
    required String phone,
    required String vehicleType,
    String? email,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
        };
      }

      await _firestore.collection('drivers').doc(user.uid).set({
        'userId': user.uid,
        'name': name,
        'phone': phone,
        'email': email ?? user.email,
        'vehicleType': vehicleType,
        'isAvailable': true,
        'isOnline': false,
        'rating': 5.0,
        'totalDeliveries': 0,
        'earnings': 0.0,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Also update user profile
      await _firestore.collection('users').doc(user.uid).update({
        'userType': 'driver',
        'roles': FieldValue.arrayUnion(['driver']),
        'driverProfile': {
          'name': name,
          'phone': phone,
          'vehicleType': vehicleType,
        },
      });

      return {
        'success': true,
        'message': 'Driver registered successfully',
        'driverId': user.uid,
      };
    } catch (e) {
      print('❌ Error registering driver: $e');
      return {
        'success': false,
        'message': 'Failed to register driver: $e',
      };
    }
  }

  /// Link seller-owned driver to user account
  static Future<Map<String, dynamic>> linkSellerDriverToUser({
    required String sellerId,
    required String driverDocId,
    required String userId,
  }) async {
    try {
      // Update driver document with user ID
      await _firestore
          .collection('users')
          .doc(sellerId)
          .collection('drivers')
          .doc(driverDocId)
          .update({
        'userId': userId,
        'linkedAt': FieldValue.serverTimestamp(),
      });

      // Update user profile
      await _firestore.collection('users').doc(userId).update({
        'roles': FieldValue.arrayUnion(['driver']),
        'linkedToSeller': sellerId,
        'driverDocId': driverDocId,
      });

      return {
        'success': true,
        'message': 'Driver linked to user account',
      };
    } catch (e) {
      print('❌ Error linking driver: $e');
      return {
        'success': false,
        'message': 'Failed to link driver: $e',
      };
    }
  }

  /// Get driver's assigned orders
  static Future<List<Map<String, dynamic>>> getDriverOrders(
    Map<String, dynamic> driverProfile,
  ) async {
    try {
      final driverType = driverProfile['driverType'];
      final driverId = driverProfile['driverId'];

      print('🔍 DEBUG: Getting orders for driver type: $driverType, driverId: $driverId');
      print('🔍 DEBUG: Driver profile: $driverProfile');

      if (driverType == 'global') {
        // Global driver - check assignedDriverId
        final ordersQuery = await _firestore
            .collection('orders')
            .where('assignedDriverId', isEqualTo: driverId)
            .where('status', whereIn: ['confirmed', 'ready', 'delivery_in_progress'])
            .get();

        return ordersQuery.docs.map((doc) => {
          'orderId': doc.id,
          ...doc.data(),
        }).toList();
      } else if (driverType == 'seller_owned') {
        // 🚀 NEW: Seller-owned driver - check main orders collection for seller-assigned orders
        final sellerId = driverProfile['sellerId'];
        final driverData = driverProfile['driverData'] as Map<String, dynamic>;
        // Use the correct driverDocId - should be the Firestore document ID, not Firebase UID
        final driverDocId = driverProfile.containsKey('driverDocId') 
            ? driverProfile['driverDocId'] 
            : driverData['driverDocId'] ?? driverProfile['driverId'];
        
        print('🔍 DEBUG: Driver profile: $driverProfile');
        print('🔍 DEBUG: Looking for orders assigned to seller driver: $driverDocId');
        print('🔍 DEBUG: Seller ID: $sellerId');
        
        // Get orders from main orders collection where this driver is assigned
        final ordersQuery = await _firestore
            .collection('orders')
            .where('assignedDriver.driverId', isEqualTo: driverDocId)
            .where('assignedDriver.type', isEqualTo: 'seller_assigned')
            .where('status', whereIn: ['driver_assigned', 'delivery_in_progress', 'picked_up', 'out_for_delivery'])
            .get();

        print('🔍 DEBUG: Found ${ordersQuery.docs.length} seller-assigned orders');

        // Get seller name from seller document
        String sellerName = 'Unknown Store';
        try {
          final sellerDoc = await _firestore.collection('users').doc(sellerId).get();
          if (sellerDoc.exists) {
            final sellerData = sellerDoc.data()!;
            sellerName = sellerData['name'] ?? sellerData['businessName'] ?? sellerData['storeName'] ?? 'Unknown Store';
          }
        } catch (e) {
          print('⚠️ Could not fetch seller name: $e');
        }

        // Process orders with async address fetching
        final List<Map<String, dynamic>> orders = [];
        
        for (final doc in ordersQuery.docs) {
          final data = doc.data();
          
          // Extract correct data from nested structures
          final buyerDetails = data['buyerDetails'] as Map<String, dynamic>?;
          final pricing = data['pricing'] as Map<String, dynamic>?;
          final fulfillment = data['fulfillment'] as Map<String, dynamic>?;
          final items = data['items'] as List?;
          
          // Get delivery address - use same logic as seller dashboard but enhance it
          String deliveryAddress = 'No delivery address provided';
          
          // First check fulfillment.address (new format)
          if (fulfillment?['address'] != null && fulfillment!['address'].toString().isNotEmpty) {
            deliveryAddress = fulfillment!['address'].toString();
          }
          // Then check root level address field (old format)
          else if (data['address'] != null && data['address'].toString().isNotEmpty) {
            deliveryAddress = data['address'].toString();
          }
          // Then check delivery task address
          else {
            // Try to get from seller delivery task
            try {
              final taskDoc = await _firestore.collection('seller_delivery_tasks').doc(doc.id).get();
              if (taskDoc.exists) {
                final taskData = taskDoc.data() as Map<String, dynamic>;
                final taskAddress = taskData['deliveryDetails']?['address'];
                if (taskAddress != null && taskAddress.toString().isNotEmpty) {
                  deliveryAddress = taskAddress.toString();
                }
              }
            } catch (e) {
              print('⚠️ Could not fetch delivery task address: $e');
            }
          }
          
          // Finally, use coordinates as fallback with better formatting
          if (deliveryAddress == 'No delivery address provided' && fulfillment?['coordinates'] != null) {
            final coords = fulfillment!['coordinates'] as Map<String, dynamic>;
            final lat = coords['lat']?.toDouble() ?? 0.0;
            final lng = coords['lng']?.toDouble() ?? 0.0;
            
            // Use GPS with approximate area (you could implement reverse geocoding here)
            if (lat != 0.0 && lng != 0.0) {
              deliveryAddress = '📍 Customer GPS Location\nLat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}\n(Navigate to these coordinates)';
            }
          }
          
          orders.add({
            'orderId': doc.id,
            'orderNumber': data['orderId'] ?? doc.id.substring(0, 8),
            'status': data['status'],
            'storeName': sellerName, // Use the fetched seller name
            'customerName': buyerDetails?['fullName'] ?? buyerDetails?['firstName'] ?? 'Unknown Customer',
            'deliveryAddress': deliveryAddress,
            'items': items ?? [],
            'totalAmount': pricing?['grandTotal']?.toDouble() ?? 0.0,
            'deliveryFee': pricing?['deliveryFee']?.toDouble() ?? 0.0,
            'createdAt': data['createdAt'],
            'assignedBy': 'seller',
            'sellerId': sellerId,
            'customerPhone': buyerDetails?['phone'] ?? buyerDetails?['email'],
            'sellerPhone': data['sellerPhone'],
          });
        }

        print('🔍 DEBUG: Returning ${orders.length} seller-assigned orders for driver app');
        return orders;
      }

      return [];
    } catch (e) {
      print('❌ Error getting driver orders: $e');
      return [];
    }
  }
}
