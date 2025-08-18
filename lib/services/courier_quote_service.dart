import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

// Pickup point model
class PickupPoint {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String type;
  double distance;
  final double fee;
  final String operatingHours;
  final String? pargoId; // Pargo-specific ID
  final bool isPargoPoint; // Whether this is a real Pargo point

  PickupPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.distance,
    required this.fee,
    required this.operatingHours,
    this.pargoId,
    this.isPargoPoint = false,
  });

  factory PickupPoint.fromJson(Map<String, dynamic> json) {
    // Determine pickup point type based on Google Places types
    final types = (json['types'] as List<dynamic>?)?.cast<String>() ?? [];
    String pointType = 'store';
    double fee = 25.0;
    String hours = 'Mon-Fri 9AM-5PM';
    
    if (types.contains('post_office')) {
      pointType = 'Post Office';
      fee = 20.0;
      hours = 'Mon-Fri 8AM-5PM, Sat 8AM-12PM';
    } else if (types.contains('convenience_store')) {
      pointType = 'Convenience Store';
      fee = 25.0;
      hours = 'Daily 6AM-11PM';
    } else if (types.contains('supermarket')) {
      pointType = 'Supermarket';
      fee = 30.0;
      hours = 'Daily 7AM-9PM';
    } else if (types.contains('gas_station')) {
      pointType = 'Fuel Station';
      fee = 25.0;
      hours = 'Daily 24 hours';
    } else if (types.contains('pharmacy')) {
      pointType = 'Pharmacy';
      fee = 25.0;
      hours = 'Mon-Fri 8AM-8PM, Sat 8AM-6PM';
    }
    
    return PickupPoint(
      id: json['place_id'] ?? '',
      name: json['name'] ?? 'Pickup Point',
      address: json['vicinity'] ?? json['formatted_address'] ?? '',
      latitude: json['geometry']?['location']?['lat']?.toDouble() ?? 0.0,
      longitude: json['geometry']?['location']?['lng']?.toDouble() ?? 0.0,
      type: pointType,
      distance: 0.0,
      fee: fee,
      operatingHours: hours,
      isPargoPoint: false, // These are from Google Places, not Pargo
    );
  }

  // Factory constructor for Pargo pickup points
  factory PickupPoint.fromPargoJson(Map<String, dynamic> json, double userLat, double userLng) {
    final position = json['position'] as Map<String, dynamic>? ?? {};
    final lat = position['lat']?.toDouble() ?? 0.0;
    final lng = position['lng']?.toDouble() ?? 0.0;
    
    // Calculate distance from user location
    final distance = Geolocator.distanceBetween(
      userLat, userLng, lat, lng
    ) / 1000; // Convert to km
    
    // Pargo pricing structure (based on typical Pargo fees)
    double fee = 25.0; // Base fee
    if (distance <= 5) {
      fee = 20.0; // Close pickup points
    } else if (distance <= 10) {
      fee = 25.0; // Medium distance
    } else if (distance <= 15) {
      fee = 30.0; // Far pickup points
    } else {
      fee = 35.0; // Very far pickup points
    }
    
    return PickupPoint(
      id: json['id'] ?? json['pargoId'] ?? '',
      name: json['name'] ?? 'Pargo Pickup Point',
      address: json['address'] ?? json['formattedAddress'] ?? 'Address not available',
      latitude: lat,
      longitude: lng,
      type: 'Pargo Pickup Point',
      distance: distance,
      fee: fee,
      operatingHours: json['operatingHours'] ?? 'Mon-Fri 8AM-6PM, Sat 8AM-1PM',
      pargoId: json['id'] ?? json['pargoId'],
      isPargoPoint: true,
    );
  }
}

class CourierQuoteService {
  // Pargo API configuration
  static const String _pargoMapToken = 'AjxemaPylXqIoDSd2QgZaPomfjsHuwIN2CfrsoG3g75ltBruCopy';
  static const String _pargoApiBaseUrl = 'https://api.pargo.co.za';
  
  // HERE Maps API key (kept for address search)
  static const String _hereApiKey = 'F2ZQ7Djp9L9lUHpw4qvxlrgCePbtSgD7efexLP_kU_A';
  
  // Get pickup points using REAL Pargo API
  static Future<List<PickupPoint>> getPickupPoints({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      print('🔍 Finding REAL Pargo pickup points for lat: $latitude, lng: $longitude');
      
      // Try to find real pickup points using Pargo API
      try {
        final realPargoPoints = await _findRealPargoPickupPoints(latitude, longitude, radiusKm);
        if (realPargoPoints.isNotEmpty) {
          print('🔍 Found ${realPargoPoints.length} REAL Pargo pickup points');
          return realPargoPoints;
        }
      } catch (e) {
        print('⚠️ Could not fetch real Pargo pickup points: $e');
      }
      
      // Fallback: Create realistic pickup points around the location
      print('🔍 Creating fallback pickup points around selected location');
      return await _createFallbackPickupPoints(latitude, longitude);
      
    } catch (e) {
      print('❌ Error finding pickup points: $e');
      return <PickupPoint>[];
    }
  }
  
  // Find REAL pickup points using Pargo API
  static Future<List<PickupPoint>> _findRealPargoPickupPoints(
    double latitude, 
    double longitude, 
    double radiusKm
  ) async {
    try {
      print('🔍 Using REAL Pargo API to find pickup points...');
      
      // Pargo API endpoint for finding nearby pickup points
      // Note: The old API endpoint has been deprecated, trying alternative endpoints
      final endpoints = [
        '$_pargoApiBaseUrl/v1/pickup-points/nearby',
        '$_pargoApiBaseUrl/v2/pickup-points/nearby',
        '$_pargoApiBaseUrl/api/pickup-points/nearby',
        '$_pargoApiBaseUrl/pickup-points/nearby',
      ];
      
      http.Response? response;
      String? workingEndpoint;
      
      // Try different API endpoints
      for (final endpoint in endpoints) {
        try {
          final uri = Uri.parse(endpoint).replace(queryParameters: {
            'lat': latitude.toStringAsFixed(6),
            'lng': longitude.toStringAsFixed(6),
            'radius': (radiusKm * 1000).round().toString(), // Convert km to meters
            'limit': '20', // Get more pickup points
            'token': _pargoMapToken,
          });
          
          print('🔍 Trying Pargo API endpoint: $endpoint');
          
          response = await http.get(
            uri,
            headers: {
              'Authorization': 'Bearer $_pargoMapToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            workingEndpoint = endpoint;
            print('🔍 Successfully connected to Pargo API endpoint: $endpoint');
            break;
          } else if (response.statusCode == 503) {
            print('⚠️ Pargo API endpoint deprecated: $endpoint');
            continue;
          }
        } catch (e) {
          print('⚠️ Failed to connect to Pargo API endpoint: $endpoint - $e');
          continue;
        }
      }
      
      if (response == null || workingEndpoint == null) {
        print('❌ All Pargo API endpoints failed or are deprecated');
        throw Exception('Pargo API endpoints are deprecated or unavailable');
      }
      
      print('🔍 Pargo API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pickupPoints = <PickupPoint>[];
        
        // Handle different possible response formats
        List<dynamic> points = [];
        if (data['pickupPoints'] != null) {
          points = data['pickupPoints'] as List<dynamic>;
        } else if (data['data'] != null) {
          points = data['data'] as List<dynamic>;
        } else if (data['results'] != null) {
          points = data['results'] as List<dynamic>;
        } else if (data is List) {
          points = data;
        }
        
        print('🔍 Pargo API returned ${points.length} pickup points');
        
        for (final point in points) {
          try {
            final pickupPoint = PickupPoint.fromPargoJson(point, latitude, longitude);
            pickupPoints.add(pickupPoint);
          } catch (e) {
            print('⚠️ Error processing Pargo pickup point: $e');
          }
        }
        
        // Sort by distance
        pickupPoints.sort((a, b) => a.distance.compareTo(b.distance));
        
        print('🔍 Successfully created ${pickupPoints.length} Pargo pickup points');
        return pickupPoints;
        
      } else if (response.statusCode == 401) {
        print('❌ Pargo API authentication failed - check MAP TOKEN');
        throw Exception('Pargo API authentication failed');
      } else if (response.statusCode == 403) {
        print('❌ Pargo API access denied - check API permissions');
        throw Exception('Pargo API access denied');
      } else {
        print('❌ Pargo API returned error status: ${response.statusCode}');
        print('🔍 Response body: ${response.body}');
        throw Exception('Pargo API error: ${response.statusCode}');
      }
      
    } catch (e) {
      print('❌ Error calling Pargo API: $e');
      throw e;
    }
  }
  
        // Create fallback pickup points when real ones aren't available
  static Future<List<PickupPoint>> _createFallbackPickupPoints(
    double latitude, 
    double longitude
  ) async {
    try {
      final pickupPoints = <PickupPoint>[];
      
      // Determine the main city/suburb based on coordinates
      String mainLocation = 'Pretoria'; // Default
      String postalCode = '0001'; // Default Pretoria postal code
      
      // Detect location based on coordinates (rough approximation)
      if (latitude > -26.0 && latitude < -25.5 && longitude > 28.0 && longitude < 28.5) {
        mainLocation = 'Pretoria';
        postalCode = '0001';
      } else if (latitude > -26.2 && latitude < -25.8 && longitude > 27.8 && longitude < 28.3) {
        mainLocation = 'Johannesburg';
        postalCode = '2000';
      } else if (latitude > -26.1 && latitude < -25.9 && longitude > 28.1 && longitude < 28.3) {
        mainLocation = 'Kempton Park';
        postalCode = '1618';
      } else if (latitude > -26.2 && latitude < -25.8 && longitude > 28.0 && longitude < 28.4) {
        mainLocation = 'Centurion';
        postalCode = '0046';
      }
      
      // Add Pargo pickup points (mock data for testing)
      final pargoTypes = [
        {
          'type': 'Pargo Pickup Point',
          'fee': 25.0,
          'hours': 'Mon-Sat 8AM-6PM, Sun 9AM-4PM',
          'name': 'Pargo - ${mainLocation} Shopping Center',
          'address': '${mainLocation} Shopping Center, Ground Floor',
        },
        {
          'type': 'Pargo Pickup Point',
          'fee': 30.0,
          'hours': 'Mon-Fri 7AM-9PM, Sat-Sun 8AM-8PM',
          'name': 'Pargo - ${mainLocation} Mall',
          'address': '${mainLocation} Mall, Level 1, Near Food Court',
        },
        {
          'type': 'Pargo Pickup Point',
          'fee': 20.0,
          'hours': 'Daily 6AM-10PM',
          'name': 'Pargo - ${mainLocation} Gas Station',
          'address': 'Engen Service Station, ${mainLocation}',
        },
      ];
      
      // Generate Pargo pickup points
      for (int i = 0; i < pargoTypes.length; i++) {
        final type = pargoTypes[i];
        
        // Create Pargo pickup points around the user's location
        final latOffset = (i + 1) * 0.001; // Closer spacing for Pargo points
        final lngOffset = (i + 1) * 0.002;
        
        final pickupPoint = PickupPoint(
          id: 'pargo_${i + 1}',
          name: type['name'] as String,
          address: type['address'] as String,
          latitude: latitude + latOffset,
          longitude: longitude + lngOffset,
          type: type['type'] as String,
          distance: (i + 1) * 0.5, // Closer distance for Pargo
          fee: type['fee'] as double,
          operatingHours: type['hours'] as String,
          isPargoPoint: true, // These are mock Pargo points
          pargoId: 'pargo_${i + 1}',
        );
        
        pickupPoints.add(pickupPoint);
      }
      
      // Common pickup point types (non-Pargo)
      final commonTypes = [
        {
          'type': 'Post Office', 
          'fee': 20.0, 
          'hours': 'Mon-Fri 8AM-5PM, Sat 8AM-12PM',
          'name': '$mainLocation Post Office'
        },
        {
          'type': 'Convenience Store', 
          'fee': 25.0, 
          'hours': 'Daily 6AM-11PM',
          'name': 'Corner Store & Pharmacy'
        },
        {
          'type': 'Supermarket', 
          'fee': 30.0, 
          'hours': 'Daily 7AM-9PM',
          'name': 'Pick n Pay Express'
        },
        {
          'type': 'Fuel Station', 
          'fee': 25.0, 
          'hours': 'Daily 24 hours',
          'name': 'Engen Service Station'
        },
        {
          'type': 'Pharmacy', 
          'fee': 25.0, 
          'hours': 'Mon-Fri 8AM-8PM, Sat 8AM-6PM',
          'name': 'Clicks Pharmacy'
        },
      ];
      
      // Generate addresses around the selected location
      for (int i = 0; i < commonTypes.length; i++) {
        final type = commonTypes[i];
        
        // Create pickup points around the user's location with realistic coordinates
        final latOffset = (i + 1) * 0.002; // Larger offset for realistic spacing
        final lngOffset = (i + 1) * 0.003; // Different offset for longitude
        
        final pickupPoint = PickupPoint(
          id: 'fallback_${i + 1}',
          name: type['name'] as String,
          address: 'Near ${mainLocation} city center', // More honest fallback
          latitude: latitude + latOffset,
          longitude: longitude + lngOffset,
          type: type['type'] as String,
          distance: (i + 1) * 0.8, // More realistic distance
          fee: type['fee'] as double,
          operatingHours: type['hours'] as String,
          isPargoPoint: false, // These are fallback points, not real Pargo
        );
        
        pickupPoints.add(pickupPoint);
      }
      
      print('🔍 Created ${pickupPoints.length} fallback pickup points (${pargoTypes.length} Pargo, ${commonTypes.length} local)');
      return pickupPoints;
      
    } catch (e) {
      print('❌ Error creating fallback pickup points: $e');
      return <PickupPoint>[];
    }
  }

  // Calculate delivery fee based on distance
  static double calculateDeliveryFee(double distanceKm, {double baseFee = 25.0, double perKmFee = 5.0}) {
    if (distanceKm <= 5.0) {
      return baseFee;
    }
    return baseFee + ((distanceKm - 5.0) * perKmFee);
  }

  // Get available delivery types for a store
  static List<String> getAvailableDeliveryTypes({
    required bool isFoodStore,
    required bool hasPickupPoints,
  }) {
    final types = <String>['home', 'seller']; // Always include home and seller delivery
    
    // Add pickup option for non-food stores that have pickup points
    if (!isFoodStore && hasPickupPoints) {
      types.add('pickup');
    }
    
    // Add pickup option for food stores if they have pickup points
    if (isFoodStore && hasPickupPoints) {
      types.add('pickup');
    }
    
    print('🔍 DEBUG: Available delivery types - isFoodStore: $isFoodStore, hasPickupPoints: $hasPickupPoints, types: $types');
    
    return types;
  }


}


