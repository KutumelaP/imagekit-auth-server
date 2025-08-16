import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'notification_service.dart';

class DeliveryFulfillmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// **1. AUTOMATED DRIVER ASSIGNMENT**
  /// Automatically assigns the best available driver to an order
  static Future<Map<String, dynamic>?> assignDriverToOrder({
    required String orderId,
    required String sellerId,
    required double pickupLatitude,
    required double pickupLongitude,
    required double deliveryLatitude,
    required double deliveryLongitude,
    required String deliveryType, // 'rural', 'urban', 'pickup'
    required String category, // 'food', 'electronics', 'clothes', 'other'
  }) async {
    try {
      print('🔍 DEBUG: Starting automated driver assignment for order: $orderId');
      
      // Get available drivers based on delivery type
      List<Map<String, dynamic>> availableDrivers = [];
      
      if (deliveryType == 'rural') {
        availableDrivers = await _getAvailableRuralDrivers(
          pickupLatitude, 
          pickupLongitude,
          deliveryLatitude,
          deliveryLongitude,
        );
      } else if (deliveryType == 'urban') {
        availableDrivers = await _getAvailableUrbanDrivers(
          pickupLatitude,
          pickupLongitude,
          deliveryLatitude,
          deliveryLongitude,
          category,
        );
      } else {
        // For pickup orders, no driver needed
        return null;
      }

      if (availableDrivers.isEmpty) {
        print('🔍 DEBUG: No available drivers found');
        return null;
      }

      // Select best driver based on criteria
      Map<String, dynamic> bestDriver = _selectBestDriver(availableDrivers, orderId);
      
      // Assign driver to order
      await _firestore.collection('orders').doc(orderId).update({
        'assignedDriver': {
          'driverId': bestDriver['driverId'],
          'name': bestDriver['name'],
          'phone': bestDriver['phone'],
          'vehicleType': bestDriver['vehicleType'],
          'assignedAt': FieldValue.serverTimestamp(),
          'estimatedPickupTime': _calculateEstimatedPickupTime(bestDriver),
          'estimatedDeliveryTime': _calculateEstimatedDeliveryTime(bestDriver, deliveryLatitude, deliveryLongitude),
        },
        'status': 'driver_assigned',
        'trackingUpdates': FieldValue.arrayUnion([
          {
            'description': 'Driver ${bestDriver['name']} assigned to your order',
            'timestamp': Timestamp.now(),
            'status': 'driver_assigned',
            'driverId': bestDriver['driverId'],
          }
        ]),
      });

      // Notify driver about new assignment
      await _notifyDriver(bestDriver['driverId'], orderId);

      print('🔍 DEBUG: Driver ${bestDriver['name']} assigned to order $orderId');
      return bestDriver;
      
    } catch (e) {
      print('🔍 DEBUG: Error assigning driver: $e');
      return null;
    }
  }

  /// **2. GET AVAILABLE RURAL DRIVERS**
  static Future<List<Map<String, dynamic>>> _getAvailableRuralDrivers(
    double pickupLat, double pickupLng,
    double deliveryLat, double deliveryLng,
  ) async {
    try {
      // Get all rural drivers
      final driversSnapshot = await _firestore
          .collection('drivers')
          .where('isRuralDriver', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> availableDrivers = [];
      
      for (var doc in driversSnapshot.docs) {
        final driverData = doc.data();
        final driverLat = (driverData['latitude'] as num?)?.toDouble() ?? 0.0;
        final driverLng = (driverData['longitude'] as num?)?.toDouble() ?? 0.0;
        final maxDistance = (driverData['maxDistance'] as num?)?.toDouble() ?? 50.0;

        // Calculate distances
        final distanceToPickup = Geolocator.distanceBetween(
          driverLat, driverLng, pickupLat, pickupLng,
        );
        
        final pickupToDelivery = Geolocator.distanceBetween(
          pickupLat, pickupLng, deliveryLat, deliveryLng,
        );

        final totalDistance = distanceToPickup + pickupToDelivery;

        // Check if driver can handle this delivery
        if (totalDistance <= maxDistance && driverData['rating'] >= 4.0) {
          availableDrivers.add({
            ...driverData,
            'driverId': doc.id,
            'distanceToPickup': distanceToPickup,
            'totalDistance': totalDistance,
          });
        }
      }

      // Sort by distance and rating
      availableDrivers.sort((a, b) {
        final aScore = (a['rating'] * 0.7) + (1 / a['distanceToPickup'] * 0.3);
        final bScore = (b['rating'] * 0.7) + (1 / b['distanceToPickup'] * 0.3);
        return bScore.compareTo(aScore);
      });

      return availableDrivers;
    } catch (e) {
      print('🔍 DEBUG: Error getting rural drivers: $e');
      return [];
    }
  }

  /// **3. GET AVAILABLE URBAN DRIVERS**
  static Future<List<Map<String, dynamic>>> _getAvailableUrbanDrivers(
    double pickupLat, double pickupLng,
    double deliveryLat, double deliveryLng,
    String category,
  ) async {
    try {
      // Get urban drivers with category-specific capabilities
      final driversSnapshot = await _firestore
          .collection('drivers')
          .where('isUrbanDriver', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> availableDrivers = [];
      
      for (var doc in driversSnapshot.docs) {
        final driverData = doc.data();
        final driverLat = (driverData['latitude'] as num?)?.toDouble() ?? 0.0;
        final driverLng = (driverData['longitude'] as num?)?.toDouble() ?? 0.0;
        final capabilities = List<String>.from(driverData['capabilities'] ?? []);

        // Check if driver can handle this category
        if (!capabilities.contains(category)) continue;

        final distanceToPickup = Geolocator.distanceBetween(
          driverLat, driverLng, pickupLat, pickupLng,
        );
        
        final pickupToDelivery = Geolocator.distanceBetween(
          pickupLat, pickupLng, deliveryLat, deliveryLng,
        );

        final totalDistance = distanceToPickup + pickupToDelivery;
        final maxDistance = (driverData['maxDistance'] as num?)?.toDouble() ?? 25.0;

        if (totalDistance <= maxDistance && driverData['rating'] >= 4.2) {
          availableDrivers.add({
            ...driverData,
            'driverId': doc.id,
            'distanceToPickup': distanceToPickup,
            'totalDistance': totalDistance,
          });
        }
      }

      // Sort by urban-specific criteria
      availableDrivers.sort((a, b) {
        final aScore = (a['rating'] * 0.6) + (1 / a['distanceToPickup'] * 0.4);
        final bScore = (b['rating'] * 0.6) + (1 / b['distanceToPickup'] * 0.4);
        return bScore.compareTo(aScore);
      });

      return availableDrivers;
    } catch (e) {
      print('🔍 DEBUG: Error getting urban drivers: $e');
      return [];
    }
  }

  /// **4. SELECT BEST DRIVER**
  static Map<String, dynamic> _selectBestDriver(
    List<Map<String, dynamic>> drivers,
    String orderId,
  ) {
    if (drivers.isEmpty) {
      throw Exception('No available drivers');
    }

    // For now, return the first (best) driver
    // In production, you'd have more sophisticated selection logic
    return drivers.first;
  }

  /// **5. CALCULATE ESTIMATED TIMES**
  static DateTime _calculateEstimatedPickupTime(Map<String, dynamic> driver) {
    // Base pickup time: 15-30 minutes from assignment
    final baseMinutes = 20;
    final distanceFactor = (driver['distanceToPickup'] ?? 0) / 1000; // km to minutes
    final totalMinutes = baseMinutes + (distanceFactor * 2).round();
    
    return DateTime.now().add(Duration(minutes: totalMinutes.toInt()));
  }

  static DateTime _calculateEstimatedDeliveryTime(
    Map<String, dynamic> driver,
    double deliveryLat,
    double deliveryLng,
  ) {
    final pickupTime = _calculateEstimatedPickupTime(driver);
    final deliveryDistance = driver['totalDistance'] ?? 0;
    final deliveryMinutes = (deliveryDistance / 1000 * 3).round(); // 3 min per km
    
    return pickupTime.add(Duration(minutes: deliveryMinutes));
  }

  /// **6. NOTIFY DRIVER**
  static Future<void> _notifyDriver(String driverId, String orderId) async {
    try {
      // Get order details for notification
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      final orderData = orderDoc.data();
      
      if (orderData != null) {
        final storeName = orderData['storeName'] ?? 'Unknown Store';
        final totalAmount = orderData['totalAmount'] ?? 0.0;
        final deliveryFee = orderData['deliveryFee'] ?? 0.0;
        final driverEarnings = deliveryFee * 0.8;
        
        final message = 'New order from $storeName - R${totalAmount.toStringAsFixed(2)} total, R${driverEarnings.toStringAsFixed(2)} earnings';
        
        // Send push notification to driver
        await NotificationService.sendDriverAssignmentNotification(
          driverId: driverId,
          orderId: orderId,
          message: message,
        );
        
        // Update driver's pending orders
        await _firestore.collection('drivers').doc(driverId).update({
          'pendingOrders': FieldValue.arrayUnion([orderId]),
          'lastNotification': FieldValue.serverTimestamp(),
        });
        
        print('🔍 DEBUG: Driver notification sent for order $orderId');
      }
    } catch (e) {
      print('🔍 DEBUG: Error notifying driver: $e');
    }
  }

  /// **7. DRIVER ACCEPTS ORDER**
  static Future<bool> driverAcceptsOrder({
    required String driverId,
    required String orderId,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'driver_accepted',
        'driverAcceptedAt': FieldValue.serverTimestamp(),
        'trackingUpdates': FieldValue.arrayUnion([
          {
            'description': 'Driver accepted your order and is heading to pickup',
            'timestamp': Timestamp.now(),
            'status': 'driver_accepted',
          }
        ]),
      });

      // Update driver status
      await _firestore.collection('drivers').doc(driverId).update({
        'currentOrder': orderId,
        'isAvailable': false,
        'status': 'en_route_to_pickup',
      });

      return true;
    } catch (e) {
      print('🔍 DEBUG: Error driver accepting order: $e');
      return false;
    }
  }

  /// **8. DRIVER PICKED UP ORDER**
  static Future<bool> driverPickedUpOrder({
    required String driverId,
    required String orderId,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'picked_up',
        'pickedUpAt': FieldValue.serverTimestamp(),
        'trackingUpdates': FieldValue.arrayUnion([
          {
            'description': 'Driver picked up your order and is on the way',
            'timestamp': Timestamp.now(),
            'status': 'picked_up',
          }
        ]),
      });

      // Update driver status
      await _firestore.collection('drivers').doc(driverId).update({
        'status': 'en_route_to_delivery',
        'currentLocation': FieldValue.serverTimestamp(), // Will be updated by driver app
      });

      return true;
    } catch (e) {
      print('🔍 DEBUG: Error driver pickup: $e');
      return false;
    }
  }

  /// **9. DRIVER DELIVERED ORDER**
  static Future<bool> driverDeliveredOrder({
    required String driverId,
    required String orderId,
    String? deliveryNote,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'deliveryNote': deliveryNote,
        'trackingUpdates': FieldValue.arrayUnion([
          {
            'description': 'Order delivered successfully!',
            'timestamp': Timestamp.now(),
            'status': 'delivered',
            'note': deliveryNote,
          }
        ]),
      });

      // Update driver status and calculate payment
      final orderData = await _firestore.collection('orders').doc(orderId).get();
      final deliveryFee = orderData.data()?['deliveryFee'] ?? 0.0;
      
      await _firestore.collection('drivers').doc(driverId).update({
        'status': 'available',
        'isAvailable': true,
        'currentOrder': null,
        'earnings': FieldValue.increment(deliveryFee * 0.8), // Driver gets 80% of delivery fee
        'completedOrders': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('🔍 DEBUG: Error driver delivery: $e');
      return false;
    }
  }

  /// **10. GET ORDER TRACKING**
  static Stream<Map<String, dynamic>> getOrderTracking(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  /// **11. UPDATE DRIVER LOCATION**
  static Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _firestore.collection('drivers').doc(driverId).update({
        'latitude': latitude,
        'longitude': longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🔍 DEBUG: Error updating driver location: $e');
    }
  }

  /// **12. GET DRIVER EARNINGS**
  static Future<Map<String, dynamic>> getDriverEarnings(String driverId) async {
    try {
      final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
      final driverData = driverDoc.data() ?? {};
      
      return {
        'totalEarnings': driverData['earnings'] ?? 0.0,
        'completedOrders': driverData['completedOrders'] ?? 0,
        'averageRating': driverData['rating'] ?? 0.0,
        'thisWeekEarnings': await _calculateWeeklyEarnings(driverId),
        'thisMonthEarnings': await _calculateMonthlyEarnings(driverId),
      };
    } catch (e) {
      print('🔍 DEBUG: Error getting driver earnings: $e');
      return {};
    }
  }

  static Future<double> _calculateWeeklyEarnings(String driverId) async {
    // Calculate earnings for current week
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    final ordersSnapshot = await _firestore
        .collection('orders')
        .where('assignedDriver.driverId', isEqualTo: driverId)
        .where('deliveredAt', isGreaterThan: Timestamp.fromDate(weekStart))
        .get();

    double weeklyEarnings = 0.0;
    for (var doc in ordersSnapshot.docs) {
      final deliveryFee = doc.data()['deliveryFee'] ?? 0.0;
      weeklyEarnings += deliveryFee * 0.8; // Driver gets 80%
    }

    return weeklyEarnings;
  }

  static Future<double> _calculateMonthlyEarnings(String driverId) async {
    // Calculate earnings for current month
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    
    final ordersSnapshot = await _firestore
        .collection('orders')
        .where('assignedDriver.driverId', isEqualTo: driverId)
        .where('deliveredAt', isGreaterThan: Timestamp.fromDate(monthStart))
        .get();

    double monthlyEarnings = 0.0;
    for (var doc in ordersSnapshot.docs) {
      final deliveryFee = doc.data()['deliveryFee'] ?? 0.0;
      monthlyEarnings += deliveryFee * 0.8; // Driver gets 80%
    }

    return monthlyEarnings;
  }
} 