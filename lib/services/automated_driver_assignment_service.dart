import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'live_tracking_service.dart';
import 'whatsapp_integration_service.dart';

class AutomatedDriverAssignmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Automatically assign driver to order using intelligent algorithm
  static Future<Map<String, dynamic>> assignDriverToOrder({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    required String productCategory,
    required double orderValue,
    bool isUrgent = false,
  }) async {
    try {
      print('🤖 Starting intelligent driver assignment for order: $orderId');
      
      // Get available drivers within radius
      final availableDrivers = await _getAvailableDrivers(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        radiusKm: isUrgent ? 20.0 : 15.0,
      );
      
      if (availableDrivers.isEmpty) {
        return {
          'success': false,
          'message': 'No available drivers in the area',
          'code': 'NO_DRIVERS_AVAILABLE',
          'suggestedAction': 'expand_radius_or_schedule_later',
        };
      }
      
      // Score and rank drivers
      final rankedDrivers = await _scoreAndRankDrivers(
        drivers: availableDrivers,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        productCategory: productCategory,
        orderValue: orderValue,
        isUrgent: isUrgent,
      );
      
      // Attempt assignment with top-ranked drivers
      for (final driver in rankedDrivers.take(3)) {
        final assignmentResult = await _attemptDriverAssignment(
          orderId: orderId,
          driverData: driver,
          pickupLat: pickupLat,
          pickupLng: pickupLng,
          deliveryLat: deliveryLat,
          deliveryLng: deliveryLng,
        );
        
        if (assignmentResult['success']) {
          return assignmentResult;
        }
      }
      
      // If no driver accepts, queue for later assignment
      await _queueForLaterAssignment(orderId, rankedDrivers);
      
      return {
        'success': false,
        'message': 'Drivers are busy. Order queued for next available driver.',
        'code': 'QUEUED_FOR_ASSIGNMENT',
        'estimatedWaitTime': 15, // minutes
      };
      
    } catch (e) {
      print('❌ Error in driver assignment: $e');
      return {
        'success': false,
        'message': 'Assignment system error',
        'code': 'ASSIGNMENT_ERROR',
        'error': e.toString(),
      };
    }
  }
  
  /// Get available drivers with real-time status
  static Future<List<Map<String, dynamic>>> _getAvailableDrivers({
    required double pickupLat,
    required double pickupLng,
    required double radiusKm,
  }) async {
    try {
      // Query drivers collection for available drivers
      final driversQuery = await _firestore
          .collection('drivers')
          .where('status', isEqualTo: 'available')
          .where('isOnline', isEqualTo: true)
          .where('isVerified', isEqualTo: true)
          .get();
      
      List<Map<String, dynamic>> availableDrivers = [];
      
      for (final doc in driversQuery.docs) {
        final driverData = doc.data();
        final location = driverData['currentLocation'] as Map<String, dynamic>?;
        
        if (location != null) {
          final distance = Geolocator.distanceBetween(
            pickupLat,
            pickupLng,
            location['latitude'],
            location['longitude'],
          ) / 1000; // Convert to km
          
          if (distance <= radiusKm) {
            availableDrivers.add({
              'driverId': doc.id,
              ...driverData,
              'distanceToPickup': distance,
              'estimatedPickupTime': _calculatePickupETA(distance),
            });
          }
        }
      }
      
      print('📋 Found ${availableDrivers.length} available drivers within ${radiusKm}km');
      return availableDrivers;
      
    } catch (e) {
      print('❌ Error getting available drivers: $e');
      return [];
    }
  }
  
  /// Intelligent driver scoring algorithm (China-level AI)
  static Future<List<Map<String, dynamic>>> _scoreAndRankDrivers({
    required List<Map<String, dynamic>> drivers,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    required String productCategory,
    required double orderValue,
    required bool isUrgent,
  }) async {
    try {
      final deliveryDistance = Geolocator.distanceBetween(
        pickupLat, pickupLng, deliveryLat, deliveryLng
      ) / 1000;
      
      for (final driver in drivers) {
        double score = 100.0; // Start with perfect score
        
        // Factor 1: Distance to pickup (40% weight)
        final distanceScore = _calculateDistanceScore(driver['distanceToPickup']);
        score *= 0.4 * distanceScore;
        
        // Factor 2: Driver rating (25% weight)
        final rating = (driver['rating'] as double?) ?? 3.0;
        final ratingScore = rating / 5.0;
        score += 25.0 * ratingScore;
        
        // Factor 3: Completion rate (15% weight)
        final completionRate = (driver['completionRate'] as double?) ?? 0.8;
        score += 15.0 * completionRate;
        
        // Factor 4: Vehicle suitability (10% weight)
        final vehicleScore = _calculateVehicleScore(
          driver['vehicleType'] ?? 'car',
          productCategory,
          orderValue,
        );
        score += 10.0 * vehicleScore;
        
        // Factor 5: Recent performance (5% weight)
        final recentPerformance = await _getRecentPerformanceScore(driver['driverId']);
        score += 5.0 * recentPerformance;
        
        // Factor 6: Special bonuses/penalties (5% weight)
        if (isUrgent && (driver['acceptsUrgentOrders'] ?? false)) {
          score += 5.0; // Bonus for urgent orders
        }
        
        if (driver['isNearbyFrequently'] ?? false) {
          score += 3.0; // Bonus for area familiarity
        }
        
        // Penalty for recent cancellations
        final recentCancellations = (driver['recentCancellations'] as int?) ?? 0;
        score -= recentCancellations * 2.0;
        
        driver['assignmentScore'] = score;
        driver['scoreBreakdown'] = {
          'distance': distanceScore * 40,
          'rating': ratingScore * 25,
          'completion': completionRate * 15,
          'vehicle': vehicleScore * 10,
          'performance': recentPerformance * 5,
        };
      }
      
      // Sort by score descending
      drivers.sort((a, b) => (b['assignmentScore'] as double)
          .compareTo(a['assignmentScore'] as double));
      
      print('🎯 Top driver score: ${drivers.first['assignmentScore'].toStringAsFixed(1)}');
      return drivers;
      
    } catch (e) {
      print('❌ Error scoring drivers: $e');
      return drivers;
    }
  }
  
  /// Attempt to assign specific driver to order
  static Future<Map<String, dynamic>> _attemptDriverAssignment({
    required String orderId,
    required Map<String, dynamic> driverData,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) async {
    try {
      final driverId = driverData['driverId'];
      final driverName = driverData['name'] ?? 'Driver';
      final driverPhone = driverData['phone'] ?? '';
      
      // Create assignment request
      final assignmentId = 'assign_${orderId}_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestore.collection('driver_assignments').doc(assignmentId).set({
        'assignmentId': assignmentId,
        'orderId': orderId,
        'driverId': driverId,
        'status': 'pending', // pending, accepted, declined, expired
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(minutes: 2))),
        'pickupLocation': {
          'latitude': pickupLat,
          'longitude': pickupLng,
        },
        'deliveryLocation': {
          'latitude': deliveryLat,
          'longitude': deliveryLng,
        },
        'estimatedEarnings': _calculateDriverEarnings(driverData['distanceToPickup']),
        'estimatedDuration': _calculateTripDuration(
          driverData['distanceToPickup'],
          Geolocator.distanceBetween(pickupLat, pickupLng, deliveryLat, deliveryLng) / 1000,
        ),
        'assignmentScore': driverData['assignmentScore'],
      });
      
      // Send notification to driver (push notification or in-app)
      await _notifyDriverOfAssignment(
        driverId: driverId,
        driverPhone: driverPhone,
        orderId: orderId,
        assignmentId: assignmentId,
        estimatedEarnings: _calculateDriverEarnings(driverData['distanceToPickup']),
      );
      
      // Wait for driver response (2 minutes timeout)
      final response = await _waitForDriverResponse(assignmentId);
      
      if (response['accepted']) {
        // Assignment accepted
        await _finalizeAssignment(
          orderId: orderId,
          driverId: driverId,
          driverName: driverName,
          driverPhone: driverPhone,
          assignmentId: assignmentId,
          pickupLat: pickupLat,
          pickupLng: pickupLng,
          deliveryLat: deliveryLat,
          deliveryLng: deliveryLng,
        );
        
        return {
          'success': true,
          'driverId': driverId,
          'driverName': driverName,
          'driverPhone': driverPhone,
          'estimatedPickupTime': driverData['estimatedPickupTime'],
          'assignmentScore': driverData['assignmentScore'],
          'message': 'Driver assigned successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Driver declined or did not respond',
          'code': 'DRIVER_DECLINED',
        };
      }
      
    } catch (e) {
      print('❌ Error attempting driver assignment: $e');
      return {
        'success': false,
        'message': 'Assignment attempt failed',
        'error': e.toString(),
      };
    }
  }
  
  /// Finalize successful assignment
  static Future<void> _finalizeAssignment({
    required String orderId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String assignmentId,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) async {
    try {
      // Update order with driver info
      await _firestore.collection('orders').doc(orderId).update({
        'assignedDriver': {
          'driverId': driverId,
          'driverName': driverName,
          'driverPhone': driverPhone,
          'assignedAt': FieldValue.serverTimestamp(),
        },
        'status': 'driver_assigned',
      });
      
      // Update driver status
      await _firestore.collection('drivers').doc(driverId).update({
        'status': 'assigned',
        'currentOrder': orderId,
        'lastAssignedAt': FieldValue.serverTimestamp(),
      });
      
      // Start live tracking
      await LiveTrackingService.startDeliveryTracking(
        orderId: orderId,
        driverId: driverId,
        driverName: driverName,
        driverPhone: driverPhone,
        destinationLat: deliveryLat,
        destinationLng: deliveryLat,
        destinationAddress: 'Delivery Address', // Get from order
      );
      
      // Notify customer
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        final orderData = orderDoc.data()!;
        final buyerPhone = orderData['buyerPhone'] ?? '';
        
        await WhatsAppIntegrationService.sendDeliveryNotification(
          orderId: orderId,
          buyerPhone: buyerPhone,
          driverName: driverName,
          driverPhone: driverPhone,
          estimatedArrival: DateTime.now().add(Duration(minutes: 30)).toString(),
          trackingUrl: LiveTrackingService.getTrackingUrl(orderId),
        );
      }
      
      print('✅ Assignment finalized: Order $orderId → Driver $driverName');
      
    } catch (e) {
      print('❌ Error finalizing assignment: $e');
    }
  }
  
  // Helper methods
  
  static int _calculatePickupETA(double distanceKm) {
    // Average city speed including traffic
    if (distanceKm < 2) return (distanceKm * 8).round();
    if (distanceKm < 10) return (distanceKm * 6).round();
    return (distanceKm * 4).round();
  }
  
  static double _calculateDistanceScore(double distanceKm) {
    if (distanceKm < 2) return 1.0;
    if (distanceKm < 5) return 0.8;
    if (distanceKm < 10) return 0.6;
    return 0.4;
  }
  
  static double _calculateVehicleScore(String vehicleType, String productCategory, double orderValue) {
    switch (vehicleType.toLowerCase()) {
      case 'motorcycle':
        return productCategory.contains('food') ? 1.0 : 0.7;
      case 'car':
        return 0.9;
      case 'van':
        return orderValue > 1000 ? 1.0 : 0.8;
      case 'truck':
        return orderValue > 5000 ? 1.0 : 0.6;
      default:
        return 0.7;
    }
  }
  
  static Future<double> _getRecentPerformanceScore(String driverId) async {
    try {
      // Get last 10 deliveries performance
      final recentDeliveries = await _firestore
          .collection('delivery_history')
          .where('driverId', isEqualTo: driverId)
          .orderBy('completedAt', descending: true)
          .limit(10)
          .get();
      
      if (recentDeliveries.docs.isEmpty) return 0.5; // Neutral for new drivers
      
      double totalScore = 0.0;
      for (final doc in recentDeliveries.docs) {
        final data = doc.data();
        final onTime = (data['deliveredOnTime'] as bool?) ?? false;
        final customerRating = (data['customerRating'] as double?) ?? 3.0;
        
        double deliveryScore = (onTime ? 0.6 : 0.0) + (customerRating / 5.0 * 0.4);
        totalScore += deliveryScore;
      }
      
      return totalScore / recentDeliveries.docs.length;
    } catch (e) {
      print('❌ Error getting performance score: $e');
      return 0.5;
    }
  }
  
  static double _calculateDriverEarnings(double distanceKm) {
    final baseRate = 15.0;
    final perKmRate = 3.50;
    return baseRate + (distanceKm * perKmRate);
  }
  
  static int _calculateTripDuration(double pickupDistanceKm, double deliveryDistanceKm) {
    return ((pickupDistanceKm + deliveryDistanceKm) * 6).round(); // 6 min per km average
  }
  
  static Future<void> _notifyDriverOfAssignment({
    required String driverId,
    required String driverPhone,
    required String orderId,
    required String assignmentId,
    required double estimatedEarnings,
  }) async {
    try {
      // In a real app, this would send push notification to driver app
      // For now, we'll store the notification
      await _firestore.collection('driver_notifications').add({
        'driverId': driverId,
        'type': 'new_assignment',
        'orderId': orderId,
        'assignmentId': assignmentId,
        'estimatedEarnings': estimatedEarnings,
        'message': 'New delivery request - R${estimatedEarnings.toStringAsFixed(0)} earnings',
        'sentAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(minutes: 2))),
        'status': 'sent',
      });
      
      print('📱 Notified driver $driverId of assignment $assignmentId');
    } catch (e) {
      print('❌ Error notifying driver: $e');
    }
  }
  
  static Future<Map<String, dynamic>> _waitForDriverResponse(String assignmentId) async {
    try {
      // Wait up to 2 minutes for driver response
      final timeout = DateTime.now().add(Duration(minutes: 2));
      
      while (DateTime.now().isBefore(timeout)) {
        final assignmentDoc = await _firestore
            .collection('driver_assignments')
            .doc(assignmentId)
            .get();
        
        if (assignmentDoc.exists) {
          final status = assignmentDoc.data()!['status'] as String;
          
          if (status == 'accepted') {
            return {'accepted': true, 'status': status};
          } else if (status == 'declined') {
            return {'accepted': false, 'status': status};
          }
        }
        
        // Wait 5 seconds before checking again
        await Future.delayed(Duration(seconds: 5));
      }
      
      // Timeout - mark as expired
      await _firestore.collection('driver_assignments').doc(assignmentId).update({
        'status': 'expired',
        'expiredAt': FieldValue.serverTimestamp(),
      });
      
      return {'accepted': false, 'status': 'expired'};
      
    } catch (e) {
      print('❌ Error waiting for driver response: $e');
      return {'accepted': false, 'status': 'error'};
    }
  }
  
  static Future<void> _queueForLaterAssignment(String orderId, List<Map<String, dynamic>> drivers) async {
    try {
      await _firestore.collection('assignment_queue').doc(orderId).set({
        'orderId': orderId,
        'status': 'queued',
        'queuedAt': FieldValue.serverTimestamp(),
        'attemptedDrivers': drivers.take(3).map((d) => d['driverId']).toList(),
        'nextAttemptAt': Timestamp.fromDate(DateTime.now().add(Duration(minutes: 10))),
        'priority': 'normal',
      });
      
      print('📋 Queued order $orderId for later assignment');
    } catch (e) {
      print('❌ Error queuing order: $e');
    }
  }
  
  /// Process queued assignments (call this periodically)
  static Future<void> processQueuedAssignments() async {
    try {
      final queuedOrders = await _firestore
          .collection('assignment_queue')
          .where('status', isEqualTo: 'queued')
          .where('nextAttemptAt', isLessThanOrEqualTo: Timestamp.now())
          .limit(10)
          .get();
      
      for (final doc in queuedOrders.docs) {
        final queueData = doc.data();
        final orderId = queueData['orderId'] as String;
        
        // Get order details and retry assignment
        final orderDoc = await _firestore.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
          final orderData = orderDoc.data()!;
          
          // Retry assignment
          await assignDriverToOrder(
            orderId: orderId,
            pickupLat: orderData['pickupLat'] ?? 0.0,
            pickupLng: orderData['pickupLng'] ?? 0.0,
            deliveryLat: orderData['deliveryLat'] ?? 0.0,
            deliveryLng: orderData['deliveryLng'] ?? 0.0,
            productCategory: orderData['productCategory'] ?? 'general',
            orderValue: (orderData['total'] as num?)?.toDouble() ?? 0.0,
          );
        }
      }
      
      print('🔄 Processed ${queuedOrders.docs.length} queued assignments');
    } catch (e) {
      print('❌ Error processing queued assignments: $e');
    }
  }
}
