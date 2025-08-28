import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/web_env.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _locationPermissionRequested = false;
  bool _driverStatusChecked = false;
  bool _isDriver = false;
  Position? _currentPosition;

  // Getters
  bool get isDriver => _isDriver;
  Position? get currentPosition => _currentPosition;
  bool get hasLocationPermission => _locationPermissionRequested;

  /// Initialize location services
  Future<void> initialize() async {
    try {
      // Check driver status once
      await _checkDriverStatus();
      
      // Request location permission if not already done
      if (!_locationPermissionRequested) {
        await _requestLocationPermission();
      }
    } catch (e) {
      // Silent fail for location service
    }
  }

  /// Check driver status
  Future<void> _checkDriverStatus() async {
    if (_driverStatusChecked) return;
    _driverStatusChecked = true;
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final driverDoc = await _firestore
            .collection('drivers')
            .doc(user.uid)
            .get();
        
        _isDriver = driverDoc.exists;
      }
    } catch (e) {
      // Permission denied is expected for non-drivers - not an actual error
      if (e.toString().contains('permission-denied')) {
        _isDriver = false; // User is not a driver
      }
      // Silent fail for driver status in all other cases
    }
  }

  /// Request location permission
  Future<void> _requestLocationPermission() async {
    if (_locationPermissionRequested) return;
    _locationPermissionRequested = true;
    
    try {
      // Avoid geolocation permission on iOS Safari tabs; it can crash/reload the page
      final bool skipOnIOSWebTab = kIsWeb && WebEnv.isIOSWeb && !WebEnv.isStandalonePWA;
      if (skipOnIOSWebTab) {
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
      }
    } catch (e) {
      // Silent fail for location permission
    }
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      if (!_locationPermissionRequested) {
        await _requestLocationPermission();
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _currentPosition = position;
      return position;
    } catch (e) {
      return null;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return false;
    }
  }

  /// Get last known position
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }
}
