import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class OmniaSAPickupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get nearby OmniaSA sellers that accept pickup orders
  static Future<List<Map<String, dynamic>>> getNearbyPickupStores({
    required double latitude,
    required double longitude,
    double radiusKm = 15.0,
  }) async {
    try {
      // Get all sellers who allow pickup
      final sellersQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'seller')
          .where('allowsPickup', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();
      
      List<Map<String, dynamic>> nearbyStores = [];
      
      for (final doc in sellersQuery.docs) {
        final sellerData = doc.data();
        final storeLat = sellerData['storeLatitude'] as double?;
        final storeLng = sellerData['storeLongitude'] as double?;
        
        if (storeLat != null && storeLng != null) {
          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            storeLat,
            storeLng,
          ) / 1000;
          
          if (distance <= radiusKm) {
            nearbyStores.add({
              'id': doc.id,
              'name': sellerData['storeName'] ?? 'Store',
              'address': sellerData['storeAddress'] ?? 'Address not provided',
              'latitude': storeLat,
              'longitude': storeLng,
              'distance': distance,
              'phone': sellerData['phone'] ?? '',
              'operatingHours': sellerData['operatingHours'] ?? {
                'monday': '08:00-18:00',
                'tuesday': '08:00-18:00',
                'wednesday': '08:00-18:00',
                'thursday': '08:00-18:00',
                'friday': '08:00-18:00',
                'saturday': '08:00-16:00',
                'sunday': 'Closed',
              },
              'fees': {
                'collection': 0.0, // Free pickup from sellers
              },
              'type': 'omniasa_store',
              'isActive': true,
              'rating': sellerData['rating'] ?? 4.5,
              'pickupInstructions': sellerData['pickupInstructions'] ?? 'Contact store for pickup',
            });
          }
        }
      }
      
      // Sort by distance
      nearbyStores.sort((a, b) => (a['distance'] as double).compareTo(b['distance']));
      
      return nearbyStores;
    } catch (e) {
      print('❌ Error getting pickup stores: $e');
      return [];
    }
  }
  
  /// Create pickup order at seller's store
  static Future<Map<String, dynamic>> createStorePickupOrder({
    required String orderId,
    required String storeId,
    required Map<String, dynamic> buyerDetails,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      // Create pickup notification for seller
      await _firestore.collection('store_pickups').doc(orderId).set({
        'orderId': orderId,
        'storeId': storeId,
        'buyerDetails': buyerDetails,
        'items': items,
        'status': 'ready_for_pickup',
        'createdAt': FieldValue.serverTimestamp(),
        'pickupCode': _generatePickupCode(),
        'estimatedReadyTime': DateTime.now().add(Duration(minutes: 30)).toIso8601String(),
      });
      
      return {
        'success': true,
        'pickupCode': _generatePickupCode(),
        'message': 'Order ready for pickup at store',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  static String _generatePickupCode() {
    return (1000 + DateTime.now().millisecond % 9000).toString();
  }
}
