import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class RealPickupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get nearby OmniaSA sellers as pickup points
  static Future<List<Map<String, dynamic>>> getNearbyPickupPoints({
    required double latitude,
    required double longitude,
    double radiusKm = 15.0,
  }) async {
    try {
      // Query all active sellers from Firestore
      final sellersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .where('isStoreOpen', isEqualTo: true)
          .where('verified', isEqualTo: true)
          .get();
      
      List<Map<String, dynamic>> nearbyPickupPoints = [];
      
      for (var sellerDoc in sellersSnapshot.docs) {
        final sellerData = sellerDoc.data();
        
        // Get seller coordinates if available
        final sellerLat = sellerData['latitude'] as double?;
        final sellerLng = sellerData['longitude'] as double?;
        
        if (sellerLat != null && sellerLng != null) {
          // Calculate distance
          final distance = Geolocator.distanceBetween(
            latitude, longitude, 
            sellerLat, sellerLng
          ) / 1000; // Convert to km
          
          if (distance <= radiusKm) {
            nearbyPickupPoints.add({
              'id': sellerDoc.id,
              'name': sellerData['storeName'] ?? sellerData['businessName'] ?? sellerData['firstName'] ?? 'OmniaSA Store',
              'address': sellerData['formattedAddress'] ?? sellerData['location'] ?? sellerData['address'] ?? 'Address not available',
              'latitude': sellerLat,
              'longitude': sellerLng,
              'distance': double.parse(distance.toStringAsFixed(1)),
              'operatingHours': _getOperatingHours(sellerData),
              'services': ['free_pickup', 'seller_managed'],
              'fees': {
                'collection': 0.00, // Free pickup from sellers
                'return': 0.00,
              },
              'type': 'omniasa_seller',
              'isActive': sellerData['isStoreOpen'] ?? false,
              'contact': sellerData['contact'] ?? '',
              'storeCategory': sellerData['storeCategory'] ?? 'General',
              'rating': sellerData['rating'] ?? 4.5,
              'totalReviews': sellerData['totalReviews'] ?? 0,
            });
          }
        }
      }
      
      // Sort by distance
      nearbyPickupPoints.sort((a, b) => 
          (a['distance'] as double).compareTo(b['distance'] as double));
      
      return nearbyPickupPoints;
      
    } catch (e) {
      print('Error fetching pickup points: $e');
      return [];
    }
  }
  
  /// Get operating hours for a seller
  static Map<String, String> _getOperatingHours(Map<String, dynamic> sellerData) {
    // Check if seller has custom operating hours
    final customHours = sellerData['operatingHours'] as Map<String, dynamic>?;
    
    if (customHours != null) {
      return customHours.map((key, value) => MapEntry(key, value.toString()));
    }
    
    // Default operating hours for pickup
    return {
      'monday': '08:00-18:00',
      'tuesday': '08:00-18:00',
      'wednesday': '08:00-18:00',
      'thursday': '08:00-18:00',
      'friday': '08:00-18:00',
      'saturday': '08:00-16:00',
      'sunday': '09:00-15:00',
    };
  }
  
  /// Create a pickup booking with a seller
  static Future<Map<String, dynamic>?> createPickupBooking({
    required String pickupPointId,
    required String orderId,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      // Create pickup booking document
      final bookingRef = await _firestore.collection('pickup_bookings').add({
        'orderId': orderId,
        'pickupPointId': pickupPointId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'items': items,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'estimatedReadyTime': DateTime.now().add(Duration(hours: 2)),
        'pickupCode': _generatePickupCode(),
      });
      
      // Notify the seller about the pickup request
      await _notifySellerOfPickup(pickupPointId, orderId, bookingRef.id);
      
      return {
        'bookingId': bookingRef.id,
        'pickupCode': await bookingRef.get().then((doc) => doc.data()?['pickupCode']),
        'status': 'confirmed',
        'estimatedReadyTime': DateTime.now().add(Duration(hours: 2)).toIso8601String(),
      };
      
    } catch (e) {
      print('Error creating pickup booking: $e');
      return null;
    }
  }
  
  /// Generate a unique pickup code
  static String _generatePickupCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'PU$random';
  }
  
  /// Notify seller of new pickup request
  static Future<void> _notifySellerOfPickup(String sellerId, String orderId, String bookingId) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': sellerId,
        'type': 'pickup_request',
        'title': 'New Pickup Request',
        'message': 'Customer wants to collect order $orderId from your store',
        'data': {
          'orderId': orderId,
          'bookingId': bookingId,
          'action': 'pickup_request',
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error notifying seller: $e');
    }
  }
  
  /// Get pickup booking status
  static Future<Map<String, dynamic>?> getPickupStatus(String bookingId) async {
    try {
      final bookingDoc = await _firestore.collection('pickup_bookings').doc(bookingId).get();
      
      if (bookingDoc.exists) {
        final data = bookingDoc.data()!;
        return {
          'status': data['status'],
          'pickupCode': data['pickupCode'],
          'estimatedReadyTime': data['estimatedReadyTime']?.toDate()?.toIso8601String(),
          'actualReadyTime': data['actualReadyTime']?.toDate()?.toIso8601String(),
          'notes': data['notes'] ?? '',
        };
      }
      
      return null;
    } catch (e) {
      print('Error getting pickup status: $e');
      return null;
    }
  }
  
  /// Update pickup booking status (for sellers)
  static Future<bool> updatePickupStatus({
    required String bookingId,
    required String status,
    String? notes,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (status == 'ready') {
        updateData['actualReadyTime'] = FieldValue.serverTimestamp();
      }
      
      if (notes != null) {
        updateData['notes'] = notes;
      }
      
      await _firestore.collection('pickup_bookings').doc(bookingId).update(updateData);
      
      return true;
    } catch (e) {
      print('Error updating pickup status: $e');
      return false;
    }
  }
  
  /// Get all pickup bookings for a seller
  static Future<List<Map<String, dynamic>>> getSellerPickupBookings(String sellerId) async {
    try {
      final bookingsSnapshot = await _firestore
          .collection('pickup_bookings')
          .where('pickupPointId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      return bookingsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
    } catch (e) {
      print('Error getting seller pickup bookings: $e');
      return [];
    }
  }
}
