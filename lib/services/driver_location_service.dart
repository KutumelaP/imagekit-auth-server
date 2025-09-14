import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverLocationService {
  static final DriverLocationService _instance = DriverLocationService._internal();
  factory DriverLocationService() => _instance;
  DriverLocationService._internal();

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  String? _currentOrderId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Start tracking driver location for a specific order
  Future<bool> startTracking(String orderId) async {
    try {
      print('🛰️ Starting GPS tracking for order: $orderId');
      
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permissions denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permissions permanently denied');
        return false;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return false;
      }

      _currentOrderId = orderId;
      _isTracking = true;

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      await _updateLocationInFirestore(position);

      // Start continuous tracking
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) {
          if (_isTracking && _currentOrderId != null) {
            _updateLocationInFirestore(position);
          }
        },
        onError: (error) {
          print('❌ GPS tracking error: $error');
        },
      );

      print('✅ GPS tracking started successfully');
      return true;
    } catch (e) {
      print('❌ Failed to start GPS tracking: $e');
      return false;
    }
  }

  /// Update driver location in Firestore
  Future<void> _updateLocationInFirestore(Position position) async {
    try {
      final user = _auth.currentUser;
      if (user == null || _currentOrderId == null) return;

      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Update order with current driver location
      await _firestore
          .collection('orders')
          .doc(_currentOrderId)
          .update({
        'driverLocation': locationData,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

      // Also save to driver's location history
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('location_history')
          .add({
        ...locationData,
        'orderId': _currentOrderId,
      });

      print('📍 Location updated for order $_currentOrderId: ${position.latitude}, ${position.longitude}');
      print('   - Speed: ${position.speed} m/s');
      print('   - Accuracy: ${position.accuracy} meters');
    } catch (e) {
      print('❌ Failed to update location: $e');
    }
  }

  /// Stop tracking driver location
  Future<void> stopTracking() async {
    try {
      print('🛑 Stopping GPS tracking');
      
      _isTracking = false;
      _positionStream?.cancel();
      _locationTimer?.cancel();
      
      // Clear current location from order
      if (_currentOrderId != null) {
        await _firestore
            .collection('orders')
            .doc(_currentOrderId)
            .update({
          'driverLocation': FieldValue.delete(),
          'trackingEnded': FieldValue.serverTimestamp(),
        });
      }
      
      _currentOrderId = null;
      print('✅ GPS tracking stopped');
    } catch (e) {
      print('❌ Failed to stop GPS tracking: $e');
    }
  }

  /// Get real-time location stream for an order
  Stream<DocumentSnapshot> getOrderLocationStream(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots();
  }

  /// Check if currently tracking
  bool get isTracking => _isTracking;
  
  /// Get current order being tracked
  String? get currentOrderId => _currentOrderId;

  /// Get current position without tracking
  Future<Position?> getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('❌ Failed to get current position: $e');
      return null;
    }
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculate estimated time of arrival (basic calculation)
  static Duration calculateETA(double distanceInMeters, {double speedKmh = 30.0}) {
    double distanceInKm = distanceInMeters / 1000;
    double timeInHours = distanceInKm / speedKmh;
    return Duration(minutes: (timeInHours * 60).round());
  }

  /// Dispose of resources
  void dispose() {
    stopTracking();
  }
}
