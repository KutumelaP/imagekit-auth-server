import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LiveTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<Position>? _positionStream;
  static Timer? _etaUpdateTimer;
  
  /// Start live tracking for a delivery
  static Future<void> startDeliveryTracking({
    required String orderId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required double destinationLat,
    required double destinationLng,
    required String destinationAddress,
  }) async {
    try {
      // Create delivery tracking document
      await _firestore.collection('live_tracking').doc(orderId).set({
        'orderId': orderId,
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'status': 'assigned', // assigned, picked_up, in_transit, arrived, delivered
        'startedAt': FieldValue.serverTimestamp(),
        'destination': {
          'latitude': destinationLat,
          'longitude': destinationLng,
          'address': destinationAddress,
        },
        'currentLocation': null,
        'estimatedArrival': null,
        'route': [],
        'notifications': [],
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      
      print('🚚 Started delivery tracking for order: $orderId');
    } catch (e) {
      print('❌ Error starting delivery tracking: $e');
      throw Exception('Failed to start delivery tracking');
    }
  }
  
  /// Update driver location during delivery
  static Future<void> updateDriverLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    required double speed, // km/h
    required double heading, // degrees
    String status = 'in_transit',
  }) async {
    try {
      final trackingRef = _firestore.collection('live_tracking').doc(orderId);
      final trackingDoc = await trackingRef.get();
      
      if (!trackingDoc.exists) {
        print('❌ Tracking document not found for order: $orderId');
        return;
      }
      
      final trackingData = trackingDoc.data()!;
      final destination = trackingData['destination'] as Map<String, dynamic>;
      
      // Calculate distance to destination
      final distanceToDestination = Geolocator.distanceBetween(
        latitude,
        longitude,
        destination['latitude'],
        destination['longitude'],
      ) / 1000; // Convert to km
      
      // Calculate ETA based on distance and current speed
      final estimatedMinutes = speed > 0 
          ? (distanceToDestination / speed * 60).round()
          : _estimateETAByDistance(distanceToDestination);
      
      final estimatedArrival = DateTime.now().add(
        Duration(minutes: estimatedMinutes)
      );
      
      // Update tracking document
      await trackingRef.update({
        'currentLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
          'heading': heading,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'distanceToDestination': distanceToDestination,
        'estimatedArrival': Timestamp.fromDate(estimatedArrival),
        'estimatedMinutes': estimatedMinutes,
        'status': status,
        'lastUpdate': FieldValue.serverTimestamp(),
        'route': FieldValue.arrayUnion([{
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'speed': speed,
        }]),
      });
      
      // Send notifications based on distance
      await _checkDeliveryMilestones(
        orderId: orderId,
        distanceToDestination: distanceToDestination,
        estimatedMinutes: estimatedMinutes,
      );
      
      print('📍 Updated location for order $orderId: ${distanceToDestination.toStringAsFixed(2)}km away, ETA: ${estimatedMinutes}min');
    } catch (e) {
      print('❌ Error updating driver location: $e');
    }
  }
  
  /// Get live tracking data for an order
  static Stream<Map<String, dynamic>?> getTrackingStream(String orderId) {
    return _firestore
        .collection('live_tracking')
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }
  
  /// Mark order as picked up from seller
  static Future<void> markOrderPickedUp({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    String? notes,
  }) async {
    try {
      await _firestore.collection('live_tracking').doc(orderId).update({
        'status': 'picked_up',
        'pickedUpAt': FieldValue.serverTimestamp(),
        'pickupLocation': {
          'latitude': pickupLat,
          'longitude': pickupLng,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'pickupNotes': notes,
        'notifications': FieldValue.arrayUnion([{
          'type': 'picked_up',
          'message': 'Order has been picked up from seller',
          'timestamp': FieldValue.serverTimestamp(),
        }]),
      });
      
      // Notify customer
      await _sendTrackingNotification(
        orderId: orderId,
        type: 'picked_up',
        message: 'Your order has been picked up and is on the way! 🚚',
      );
      
      print('📦 Order $orderId marked as picked up');
    } catch (e) {
      print('❌ Error marking order as picked up: $e');
    }
  }
  
  /// Mark order as delivered
  static Future<void> markOrderDelivered({
    required String orderId,
    required double deliveryLat,
    required double deliveryLng,
    required String otpUsed,
    String? notes,
    String? photoUrl,
  }) async {
    try {
      await _firestore.collection('live_tracking').doc(orderId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'deliveryLocation': {
          'latitude': deliveryLat,
          'longitude': deliveryLng,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'deliveryVerification': {
          'otpUsed': otpUsed,
          'photoUrl': photoUrl,
          'notes': notes,
        },
        'notifications': FieldValue.arrayUnion([{
          'type': 'delivered',
          'message': 'Order delivered successfully',
          'timestamp': FieldValue.serverTimestamp(),
        }]),
      });
      
      // Update main order
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'trackingCompleted': true,
      });
      
      print('✅ Order $orderId marked as delivered');
    } catch (e) {
      print('❌ Error marking order as delivered: $e');
    }
  }
  
  /// Get tracking URL for sharing
  static String getTrackingUrl(String orderId) {
    return 'https://omniasa.co.za/track/$orderId';
  }
  
  /// Start automatic location updates for driver app
  static Future<void> startDriverLocationUpdates({
    required String orderId,
    Duration updateInterval = const Duration(seconds: 30),
  }) async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }
      
      // Configure location settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update when moved 10 meters
      );
      
      // Start position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) async {
        await updateDriverLocation(
          orderId: orderId,
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed * 3.6, // Convert m/s to km/h
          heading: position.heading,
        );
      });
      
      print('📱 Started automatic location updates for order: $orderId');
    } catch (e) {
      print('❌ Error starting location updates: $e');
      throw Exception('Failed to start location updates');
    }
  }
  
  /// Stop location updates
  static Future<void> stopDriverLocationUpdates() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _etaUpdateTimer?.cancel();
    _etaUpdateTimer = null;
    print('🛑 Stopped location updates');
  }
  
  /// Get nearby drivers for assignment
  static Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double pickupLat,
    required double pickupLng,
    double radiusKm = 10.0,
  }) async {
    try {
      // This would typically query a drivers collection
      // For now, returning mock data for China-level experience
      final drivers = await _firestore
          .collection('drivers')
          .where('status', isEqualTo: 'available')
          .where('isOnline', isEqualTo: true)
          .get();
      
      List<Map<String, dynamic>> nearbyDrivers = [];
      
      for (final doc in drivers.docs) {
        final driverData = doc.data();
        final location = driverData['currentLocation'] as Map<String, dynamic>?;
        
        if (location != null) {
          final distance = Geolocator.distanceBetween(
            pickupLat,
            pickupLng,
            location['latitude'],
            location['longitude'],
          ) / 1000;
          
          if (distance <= radiusKm) {
            nearbyDrivers.add({
              'driverId': doc.id,
              'name': driverData['name'],
              'phone': driverData['phone'],
              'rating': driverData['rating'] ?? 5.0,
              'distance': distance,
              'estimatedPickupTime': _estimateETAByDistance(distance),
              'vehicleType': driverData['vehicleType'] ?? 'car',
              'currentLocation': location,
            });
          }
        }
      }
      
      // Sort by distance
      nearbyDrivers.sort((a, b) => (a['distance'] as double).compareTo(b['distance']));
      
      return nearbyDrivers;
    } catch (e) {
      print('❌ Error getting nearby drivers: $e');
      return [];
    }
  }
  
  // Private helper methods
  
  static int _estimateETAByDistance(double distanceKm) {
    // Estimate based on average city speed including traffic
    if (distanceKm < 2) return (distanceKm * 8).round(); // 8 min/km for short distances
    if (distanceKm < 10) return (distanceKm * 6).round(); // 6 min/km for medium
    return (distanceKm * 4).round(); // 4 min/km for longer distances
  }
  
  static Future<void> _checkDeliveryMilestones({
    required String orderId,
    required double distanceToDestination,
    required int estimatedMinutes,
  }) async {
    try {
      final trackingRef = _firestore.collection('live_tracking').doc(orderId);
      
      // Notify when driver is 5km away
      if (distanceToDestination <= 5.0 && distanceToDestination > 4.5) {
        await _sendTrackingNotification(
          orderId: orderId,
          type: 'nearby',
          message: 'Driver is 5km away! Your order will arrive in ~${estimatedMinutes} minutes 🚚',
        );
      }
      
      // Notify when driver is 1km away
      if (distanceToDestination <= 1.0 && distanceToDestination > 0.5) {
        await _sendTrackingNotification(
          orderId: orderId,
          type: 'arriving_soon',
          message: 'Driver is almost there! 1km away. Please have your OTP ready 🔐',
        );
      }
      
      // Notify when driver has arrived
      if (distanceToDestination <= 0.1) {
        await _sendTrackingNotification(
          orderId: orderId,
          type: 'arrived',
          message: 'Driver has arrived! Please meet them for delivery verification ✅',
        );
        
        await trackingRef.update({
          'status': 'arrived',
          'arrivedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error checking delivery milestones: $e');
    }
  }
  
  static Future<void> _sendTrackingNotification({
    required String orderId,
    required String type,
    required String message,
  }) async {
    try {
      await _firestore.collection('live_tracking').doc(orderId).update({
        'notifications': FieldValue.arrayUnion([{
          'type': type,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        }]),
      });
      
      // You could integrate with your notification service here
      // to send push notifications or WhatsApp messages
      
      print('📢 Sent tracking notification: $message');
    } catch (e) {
      print('❌ Error sending tracking notification: $e');
    }
  }
}
