import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// Service for optimizing location-related operations with caching
class LocationOptimizationService {
  static final LocationOptimizationService _instance = LocationOptimizationService._internal();
  factory LocationOptimizationService() => _instance;
  LocationOptimizationService._internal();

  // Cache for location data
  static Position? _cachedLocation;
  static DateTime? _locationCacheTimestamp;
  static const Duration _locationCacheTimeout = Duration(minutes: 5);

  // Cache for delivery calculations
  static final Map<String, Map<String, dynamic>> _deliveryCache = {};
  static final Map<String, DateTime> _deliveryCacheTimestamps = {};
  static const Duration _deliveryCacheTimeout = Duration(minutes: 10);

  /// Get cached location or fetch new one
  Future<Position?> getCachedLocation() async {
    final startTime = DateTime.now();

    // Check cache first
    if (_cachedLocation != null && _locationCacheTimestamp != null) {
      if (DateTime.now().difference(_locationCacheTimestamp!) < _locationCacheTimeout) {
        if (kDebugMode) {
          final duration = DateTime.now().difference(startTime).inMilliseconds;
          print('📍 Location retrieved from cache in ${duration}ms');
        }
        return _cachedLocation;
      }
    }

    try {
      // Get fresh location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Cache the result
      _cachedLocation = position;
      _locationCacheTimestamp = DateTime.now();

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      
      if (kDebugMode) {
        print('📍 Fresh location obtained in ${duration}ms');
        print('🗺️ Coordinates: ${position.latitude}, ${position.longitude}');
      }

      return position;
    } catch (e) {
      if (kDebugMode) print('❌ Error getting location: $e');
      return null;
    }
  }

  /// Get cached delivery calculation or compute new one
  Future<Map<String, double>> getCachedDeliveryCalculation({
    required double userLat,
    required double userLng,
    required double storeLat,
    required double storeLng,
    required String sellerId,
    double? customDeliveryFee,
    String? deliveryPreference,
  }) async {
    final startTime = DateTime.now();

    // Create cache key
    final cacheKey = '${userLat.toStringAsFixed(4)}_${userLng.toStringAsFixed(4)}_'
                    '${storeLat.toStringAsFixed(4)}_${storeLng.toStringAsFixed(4)}_'
                    '$sellerId';

    // Check cache first
    if (_deliveryCache.containsKey(cacheKey)) {
      final timestamp = _deliveryCacheTimestamps[cacheKey];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _deliveryCacheTimeout) {
        if (kDebugMode) {
          final duration = DateTime.now().difference(startTime).inMilliseconds;
          print('🚚 Delivery calculation retrieved from cache in ${duration}ms');
        }
        return Map<String, double>.from(_deliveryCache[cacheKey]!);
      }
    }

    // Calculate distance
    final distance = Geolocator.distanceBetween(
      userLat, userLng, storeLat, storeLng,
    ) / 1000; // Convert to kilometers

    // Calculate delivery fee
    double deliveryFee;
    if (customDeliveryFee != null) {
      deliveryFee = customDeliveryFee;
    } else {
      deliveryFee = _calculateDeliveryFee(distance, deliveryPreference);
    }

    final result = {
      'distance': distance,
      'fee': deliveryFee,
    };

    // Cache the result
    _deliveryCache[cacheKey] = result;
    _deliveryCacheTimestamps[cacheKey] = DateTime.now();

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds;

    if (kDebugMode) {
      print('🚚 Delivery calculation computed in ${duration}ms');
      print('📏 Distance: ${distance.toStringAsFixed(2)} km');
      print('💰 Fee: R${deliveryFee.toStringAsFixed(2)}');
    }

    return result;
  }

  /// Calculate delivery fee based on distance and preference
  double _calculateDeliveryFee(double distance, String? deliveryPreference) {
    // System delivery models
    if (deliveryPreference == 'system') {
      return _calculateSystemDeliveryFee(distance);
    }

    // Custom delivery fee calculation
    double baseFee = distance * 2.5; // R2.50 per km base rate
    
    // Minimum fee
    if (baseFee < 15.0) baseFee = 15.0;
    
    // Distance-based adjustments
    if (distance > 20.0) {
      baseFee += (distance - 20.0) * 0.5; // Extra R0.50 per km over 20km
    }
    
    if (distance > 50.0) {
      baseFee *= 1.15; // 15% surcharge for long distances
    }

    return double.parse(baseFee.toStringAsFixed(2));
  }

  /// Calculate system delivery fee using predefined models
  double _calculateSystemDeliveryFee(double distance) {
    // Local delivery model (0-15km)
    if (distance <= 15.0) {
      double fee = distance * 3.0; // R3 per km
      return fee < 20.0 ? 20.0 : fee; // Minimum R20
    }
    
    // Regional delivery model (15-50km)
    if (distance <= 50.0) {
      double fee = 45.0 + ((distance - 15.0) * 2.5); // Base R45 + R2.50 per km
      return fee;
    }
    
    // Long distance delivery model (50km+)
    double fee = 132.5 + ((distance - 50.0) * 2.0); // Base R132.50 + R2 per km
    return fee * 1.1; // 10% surcharge for very long distances
  }

  /// Pre-warm location cache
  static Future<void> prewarmLocationCache() async {
    final service = LocationOptimizationService();
    try {
      await service.getCachedLocation();
      if (kDebugMode) print('🔥 Location cache prewarmed');
    } catch (e) {
      if (kDebugMode) print('⚠️ Location cache prewarm failed: $e');
    }
  }

  /// Clear all caches
  static void clearCache() {
    _cachedLocation = null;
    _locationCacheTimestamp = null;
    _deliveryCache.clear();
    _deliveryCacheTimestamps.clear();
    if (kDebugMode) print('🗑️ LocationOptimizationService cache cleared');
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'locationCached': _cachedLocation != null,
      'locationCacheAge': _locationCacheTimestamp != null 
          ? DateTime.now().difference(_locationCacheTimestamp!).inMinutes
          : null,
      'deliveryCalculations': _deliveryCache.length,
      'cacheHitRate': 'Not tracked', // Could be implemented with counters
    };
  }
}

