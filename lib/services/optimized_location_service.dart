import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class OptimizedLocationService {
  static Position? _cachedPosition;
  static DateTime? _lastPositionTime;
  static bool _isGettingPosition = false;
  
  // Cache location for 5 minutes to avoid repeated expensive GPS calls
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  
  // Timeout for location requests
  static const Duration _locationTimeout = Duration(seconds: 8);

  /// Get current position with intelligent caching and fast fallback
  static Future<Position?> getCurrentPosition({
    bool forceRefresh = false,
    LocationAccuracy accuracy = LocationAccuracy.medium, // Changed from high to medium
  }) async {
    try {
      // Return cached position if valid and not forcing refresh
      if (!forceRefresh && _isCachedPositionValid()) {
        print('📍 Using cached position: ${_cachedPosition!.latitude}, ${_cachedPosition!.longitude}');
        return _cachedPosition;
      }

      // Prevent multiple simultaneous location requests
      if (_isGettingPosition) {
        print('📍 Location request already in progress, waiting...');
        // Wait up to 10 seconds for the current request to complete
        int waitCount = 0;
        while (_isGettingPosition && waitCount < 20) {
          await Future.delayed(Duration(milliseconds: 500));
          waitCount++;
        }
        return _cachedPosition;
      }

      _isGettingPosition = true;

      // Check permissions quickly
      final permission = await _checkPermissions();
      if (permission != LocationPermission.whileInUse && 
          permission != LocationPermission.always) {
        print('📍 Location permission not granted: $permission');
        return null;
      }

      print('📍 Getting fresh location with accuracy: $accuracy');
      
      // Use optimized location settings for faster response
      final position = await _getPositionWithFallback();
      
      if (position != null) {
        _cachedPosition = position;
        _lastPositionTime = DateTime.now();
        print('📍 Fresh location obtained: ${position.latitude}, ${position.longitude}');
      }
      
      return position;
      
    } catch (e) {
      print('❌ Error getting current position: $e');
      return _cachedPosition; // Return cached position if available
    } finally {
      _isGettingPosition = false;
    }
  }

  /// Get position with intelligent fallback strategy
  static Future<Position?> _getPositionWithFallback() async {
    try {
      // First attempt: Try with medium accuracy and timeout
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10,
        timeLimit: _locationTimeout,
      );
      
      return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      ).timeout(
        _locationTimeout,
        onTimeout: () => throw TimeoutException('Initial location request timed out'),
      );
    } on TimeoutException {
      print('📍 Initial location request timed out, trying with lower accuracy...');
      
      try {
        // Fallback 1: Use lower accuracy for faster response
        final fallbackSettings = LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100,
          timeLimit: const Duration(seconds: 5),
        );
        
        return await Geolocator.getCurrentPosition(
          locationSettings: fallbackSettings,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Fallback location request timed out'),
        );
      } on TimeoutException {
        print('📍 Fallback location request timed out, trying last known position...');
        
        // Fallback 2: Get last known position
        return await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      print('❌ Location request failed: $e');
      
      // Final fallback: Try last known position
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          print('📍 Using last known position: ${lastKnown.latitude}, ${lastKnown.longitude}');
          return lastKnown;
        }
      } catch (e) {
        print('❌ Could not get last known position: $e');
      }
      
      return null;
    }
  }

  /// Check and request location permissions efficiently
  static Future<LocationPermission> _checkPermissions() async {
    // Quick permission check
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      print('📍 Requesting location permission...');
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }

  /// Check if cached position is still valid
  static bool _isCachedPositionValid() {
    if (_cachedPosition == null || _lastPositionTime == null) {
      return false;
    }
    
    final age = DateTime.now().difference(_lastPositionTime!);
    return age < _cacheValidDuration;
  }

  /// Get current position with UI-friendly loading states
  static Future<Position?> getCurrentPositionWithLoading({
    required Function() onLoadingStart,
    required Function() onLoadingEnd,
    required Function(String) onError,
    bool forceRefresh = false,
    LocationAccuracy accuracy = LocationAccuracy.medium,
  }) async {
    onLoadingStart();
    
    try {
      final position = await getCurrentPosition(
        forceRefresh: forceRefresh,
        accuracy: accuracy,
      );
      
      if (position == null) {
        onError('Could not determine your location. Please check location settings.');
      }
      
      return position;
    } catch (e) {
      onError('Location error: ${e.toString()}');
      return null;
    } finally {
      onLoadingEnd();
    }
  }

  /// Clear cached position (useful for testing or when user manually refreshes)
  static void clearCache() {
    _cachedPosition = null;
    _lastPositionTime = null;
    print('📍 Location cache cleared');
  }

  /// Get cached position if available (no network/GPS request)
  static Position? getCachedPosition() {
    if (_isCachedPositionValid()) {
      return _cachedPosition;
    }
    return null;
  }

  /// Check if location services are available and permissions are granted
  static Future<bool> isLocationAvailable() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      print('❌ Error checking location availability: $e');
      return false;
    }
  }

  /// Warm up location services (call this early in app lifecycle)
  static Future<void> warmUpLocationServices() async {
    if (kDebugMode) print('📍 Warming up location services...');
    
    try {
      // Pre-check permissions and services
      await isLocationAvailable();
      
      // Try to get last known position to prime the cache
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && !_isCachedPositionValid()) {
        _cachedPosition = lastKnown;
        _lastPositionTime = DateTime.now().subtract(Duration(minutes: 10)); // Mark as old
        print('📍 Location services warmed up with last known position');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Could not warm up location services: $e');
    }
  }
}
