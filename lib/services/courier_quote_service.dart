import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Firebase
import '../config/here_config.dart'; // Added for HERE Maps API
import '../config/paxi_config.dart'; // Added for PAXI pricing

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
  final String? paxiId; // PAXI-specific ID
  final bool isPaxiPoint; // Whether this is a PAXI point
  // Optional venue title (e.g., "PEP - Festival Mall") enriched from HERE
  String? venueTitle;

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
    this.paxiId,
    this.isPaxiPoint = false,
    this.venueTitle,
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
      paxiId: null,
      isPaxiPoint: false,
    );
  }

  // Factory constructor for PAXI pickup points
  factory PickupPoint.fromPaxiJson(Map<String, dynamic> json, double userLat, double userLng) {
    final lat = json['latitude']?.toDouble() ?? 0.0;
    final lng = json['longitude']?.toDouble() ?? 0.0;
    
    // Calculate distance from user location
    final distance = Geolocator.distanceBetween(
      userLat, userLng, lat, lng
    ) / 1000; // Convert to km
    
    return PickupPoint(
      id: json['id'] ?? '',
      name: json['name'] ?? 'PAXI Pickup Point',
      address: json['address'] ?? '',
      latitude: lat,
      longitude: lng,
      type: 'PAXI Point',
      distance: distance,
      fee: json['fee']?.toDouble() ?? 59.95,
      operatingHours: json['operatingHours'] ?? 'Mon-Sun 8AM-8PM',
      pargoId: null,
      isPargoPoint: false,
      paxiId: json['id'],
      isPaxiPoint: true,
    );
  }
}

class CourierQuoteService {
  // Pargo API configuration
  static const String _pargoMapToken = 'AjxemaPylXqIoDSd2QgZaPomfjsHuwIN2CfrsoG3g75ltBruCopy';
  static const String _pargoApiBaseUrl = 'https://api.pargo.co.za';
  
  // HERE Maps API key (kept for address search)
  static const String _hereApiKey = 'F2ZQ7Djp9L9lUHpw4qvxlrgCePbtSgD7efexLP_kU_A';
  
  // Get pickup points using both Pargo and PAXI APIs
  static Future<List<PickupPoint>> getPickupPoints({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      print('🔍 Finding pickup points for lat: $latitude, lng: $longitude');
      
      final allPickupPoints = <PickupPoint>[];
      bool hasPargoPoints = false;
      bool hasPaxiPoints = false;
      
      // Try to find real pickup points using Pargo API
      try {
        final realPargoPoints = await _findRealPargoPickupPoints(latitude, longitude, radiusKm);
        if (realPargoPoints.isNotEmpty) {
          print('🔍 Found ${realPargoPoints.length} REAL Pargo pickup points');
          allPickupPoints.addAll(realPargoPoints);
          hasPargoPoints = true;
        }
      } catch (e) {
        print('⚠️ Could not fetch real Pargo pickup points: $e');
      }
      
      // Try to find PAXI pickup points from your store database
      try {
        final paxiPoints = await _findPaxiStoresFromDatabase(latitude, longitude, radiusKm);
        if (paxiPoints.isNotEmpty) {
          print('🔍 Found ${paxiPoints.length} PAXI stores from database');
          hasPaxiPoints = true;
          allPickupPoints.addAll(paxiPoints);
        }
      } catch (e) {
        print('⚠️ Could not fetch PAXI stores from database: $e');
      }
      
      // If we have points from either service, but missing Pargo points, add some fallback Pargo points
      if (allPickupPoints.isNotEmpty && !hasPargoPoints) {
        print('🔍 PAXI points found but no Pargo points - adding fallback Pargo points for balance');
        try {
          final fallbackPargoPoints = await _createFallbackPargoPointsOnly(latitude, longitude);
          if (fallbackPargoPoints.isNotEmpty) {
            print('🔍 Added ${fallbackPargoPoints.length} fallback Pargo points');
            allPickupPoints.addAll(fallbackPargoPoints);
            hasPargoPoints = true;
          }
        } catch (e) {
          print('⚠️ Could not create fallback Pargo points: $e');
        }
      }
      
      // If we have points from either service, return them
      if (allPickupPoints.isNotEmpty) {
        // Sort all points by distance
        allPickupPoints.sort((a, b) => a.distance.compareTo(b.distance));
        print('🔍 Returning ${allPickupPoints.length} total pickup points (Pargo: ${allPickupPoints.where((p) => p.isPargoPoint).length}, PAXI: ${allPickupPoints.where((p) => p.isPaxiPoint).length})');
        return allPickupPoints;
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
  
  // Find real PAXI partner stores using HERE Maps API
  static Future<List<PickupPoint>> _findPaxiStoresFromDatabase(
    double latitude, 
    double longitude, 
    double radiusKm
  ) async {
    try {
      print('🔍 Finding real PAXI partner stores for lat: $latitude, lng: $longitude');
      
      // Increase search radius for PAXI stores to cover larger metropolitan areas
      // Expand radius to ensure sufficient PAXI results in metros
      double paxiSearchRadius = (radiusKm * 3);
      // If around Gauteng metro (rough bbox), allow up to 60km to bridge Pretoria/JHB
      final inGautengApprox = (latitude > -26.6 && latitude < -25.5 && longitude > 27.0 && longitude < 29.0);
      final maxCap = inGautengApprox ? 100.0 : 35.0;
      paxiSearchRadius = paxiSearchRadius.clamp(15.0, maxCap);
      print('🔍 PAXI search radius: ${radiusKm}km normal, ${paxiSearchRadius}km for PAXI stores');
      
      final pickupPoints = <PickupPoint>[];
      
      // PAXI partner brands to search for
      final paxiBrands = [
        'PEP',
        'Pephome', 
        'PEPcell',
        'Tekkie Town',
        'Shoe City',
      ];
      
      print('🔍 Searching for ${paxiBrands.length} PAXI brands using HERE Maps API...');
      
      // Search for each PAXI brand in the area
      for (final brand in paxiBrands) {
        try {
          print('🔍 Searching for: $brand near coordinates ($latitude, $longitude)');
          
          // Search using HERE Maps API (similar to address search)
          final stores = await _searchPaxiStoresWithHereApi(brand, latitude, longitude, paxiSearchRadius);
          
          if (stores.isNotEmpty) {
            print('🔍 Found ${stores.length} $brand stores via HERE Maps API');
            
            for (final store in stores) {
              final distance = Geolocator.distanceBetween(
                latitude, longitude, store['latitude'], store['longitude']
              ) / 1000; // Convert to km

              // HERE already applies the radius; include all returned results
              print('✅ $brand store: ${distance.toStringAsFixed(1)}km - ${store['address']}');

              final pickupPoint = PickupPoint(
                id: 'paxi_here_${store['id']}',
                name: 'PAXI - $brand',
                address: store['address'],
                latitude: store['latitude'],
                longitude: store['longitude'],
                type: 'PAXI Partner Store',
                distance: distance,
                fee: 59.95, // Standard PAXI fee
                operatingHours: 'Mon-Sun 8AM-8PM', // Default hours
                pargoId: null,
                isPargoPoint: false,
                paxiId: store['id'],
                isPaxiPoint: true,
              );

              pickupPoints.add(pickupPoint);
            }
          } else {
            print('🔍 No $brand stores found via HERE Maps API');
          }
          
        } catch (e) {
          print('⚠️ Error searching for $brand: $e');
          continue; // Continue with next brand
        }
      }
      
      // Sort by distance
      pickupPoints.sort((a, b) => a.distance.compareTo(b.distance));
      
      print('🔍 Found ${pickupPoints.length} real PAXI partner stores within ${paxiSearchRadius}km radius via HERE Maps API');
      
      // Debug: Print details of each PAXI store found
      for (final point in pickupPoints) {
        print('🔍 PAXI Store: ${point.name} at ${point.address}, Distance: ${point.distance.toStringAsFixed(1)}km, Hours: ${point.operatingHours}');
      }
      
      return pickupPoints;
      
    } catch (e) {
      print('❌ Error finding real PAXI partner stores: $e');
      return [];
    }
  }
  
  // Search for PAXI stores using HERE Maps API
  static Future<List<Map<String, dynamic>>> _searchPaxiStoresWithHereApi(
    String brand, 
    double latitude, 
    double longitude, 
    double radiusKm
  ) async {
    try {
      if (!HereConfig.isConfigured) {
        print('⚠️ HERE Maps API not configured, skipping $brand search');
        return [];
      }
      
      // Search query: brand name + store
      final searchQuery = '$brand store';

      // Use spatial filter with circle to strictly bound by radius
      final queryParams = <String, String>{
        'q': searchQuery,
        'limit': '20', // Fetch more then filter by distance
        'apiKey': HereConfig.validatedApiKey,
        'at': '$latitude,$longitude', // Provide context for ranking
        'in': 'circle:$latitude,$longitude;r=${(radiusKm * 1000).round()}', // Strict radius filter
        'lang': 'en-ZA',
      };
      
      final uri = Uri.parse(HereConfig.discoverUrl).replace(queryParameters: queryParams);
      
      print('🔍 HERE Maps API request for $brand: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        
        print('🔍 HERE Maps API returned ${items.length} results for $brand');
        
        // Map and distance-filter results to stay within radiusKm
        final List<Map<String, dynamic>> mapped = [];
        for (final item in items) {
          final position = item['position'] ?? {};
          final address = item['address'] ?? {};
          final double lat = (position['lat'] as num?)?.toDouble() ?? 0.0;
          final double lng = (position['lng'] as num?)?.toDouble() ?? 0.0;
          if (lat == 0.0 && lng == 0.0) continue;

          final double distanceKm = Geolocator.distanceBetween(latitude, longitude, lat, lng) / 1000.0;
          if (distanceKm <= radiusKm + 0.1) {
            mapped.add({
              'id': item['id'] ?? '',
              'title': item['title'] ?? '',
              'address': address['label'] ?? '',
              'latitude': lat,
              'longitude': lng,
              'source': 'HERE Maps API',
            });
          }
        }

        print('🔍 HERE Maps API kept ${mapped.length} results within ${radiusKm}km for $brand');
        return mapped;
        
      } else {
        print('⚠️ HERE Maps API error for $brand: ${response.statusCode} - ${response.body}');
        return [];
      }
      
    } catch (e) {
      print('❌ HERE Maps API search failed for $brand: $e');
      return [];
    }
  }
  
  // Helper method to parse coordinates from various types
  static double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }
  
  // Helper method to format operating hours from existing time fields
  static String _formatOperatingHours(Map<String, dynamic> storeData) {
    try {
      // Try to get operating hours from various possible field combinations
      final operatingStart = storeData['operatingStartHour'] ?? storeData['storeOpenHour'];
      final operatingEnd = storeData['operatingEndHour'] ?? storeData['storeCloseHour'];
      
      if (operatingStart != null && operatingEnd != null) {
        // Format: "08:00-20:00"
        return '$operatingStart-$operatingEnd';
      } else if (storeData['storeOpenHour'] != null && storeData['storeCloseHour'] != null) {
        // Fallback to store hours
        return '${storeData['storeOpenHour']}-${storeData['storeCloseHour']}';
      } else {
        // Default fallback
        return 'Mon-Sun 8AM-8PM';
      }
    } catch (e) {
      print('⚠️ Error formatting operating hours: $e');
      return 'Mon-Sun 8AM-8PM';
    }
  }
  
  // Get PAXI pricing from your admin configuration
  static Future<Map<String, double>> _getPaxiPricingFromConfig() async {
    try {
      // Try to get PAXI pricing from admin settings
      final configDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('paxi_pricing')
          .get();
      
      if (configDoc.exists) {
        final data = configDoc.data() as Map<String, dynamic>;
        return {
          'standard': (data['standard'] ?? 59.95).toDouble(),
          'express': (data['express'] ?? 109.95).toDouble(),
        };
      }
      
      // Fallback to default PAXI pricing from config
      return {
        'standard': PaxiConfig.getPrice('standard'),
        'express': PaxiConfig.getPrice('express'),
      };
      
    } catch (e) {
      print('⚠️ Could not fetch PAXI pricing from config, using defaults: $e');
      return {
        'standard': PaxiConfig.getPrice('standard'),
        'express': PaxiConfig.getPrice('express'),
      };
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
          isPaxiPoint: false, // These are Pargo points, not PAXI
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
          isPaxiPoint: false, // These are fallback points, not real PAXI
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
  
  // Create only Pargo fallback points (used when PAXI points exist but Pargo points don't)
  static Future<List<PickupPoint>> _createFallbackPargoPointsOnly(
    double latitude, 
    double longitude
  ) async {
    try {
      final pickupPoints = <PickupPoint>[];
      
      // Determine the main city/suburb based on coordinates
      String mainLocation = 'Pretoria'; // Default
      
      // Detect location based on coordinates (rough approximation)
      if (latitude > -26.0 && latitude < -25.5 && longitude > 28.0 && longitude < 28.5) {
        mainLocation = 'Pretoria';
      } else if (latitude > -26.2 && latitude < -25.8 && longitude > 27.8 && longitude < 28.3) {
        mainLocation = 'Johannesburg';
      } else if (latitude > -26.1 && latitude < -25.9 && longitude > 28.1 && longitude < 28.3) {
        mainLocation = 'Kempton Park';
      } else if (latitude > -26.2 && latitude < -25.8 && longitude > 28.0 && longitude < 28.4) {
        mainLocation = 'Centurion';
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
        {
          'type': 'Pargo Pickup Point',
          'fee': 28.0,
          'hours': 'Mon-Fri 8AM-7PM, Sat 8AM-5PM',
          'name': 'Pargo - ${mainLocation} Post Office',
          'address': '${mainLocation} Post Office, Main Branch',
        },
      ];
      
      // Generate Pargo pickup points
      for (int i = 0; i < pargoTypes.length; i++) {
        final type = pargoTypes[i];
        
        // Create Pargo pickup points around the user's location
        final latOffset = (i + 1) * 0.001; // Closer spacing for Pargo points
        final lngOffset = (i + 1) * 0.002;
        
        final pickupPoint = PickupPoint(
          id: 'pargo_fallback_${i + 1}',
          name: type['name'] as String,
          address: type['address'] as String,
          latitude: latitude + latOffset,
          longitude: longitude + lngOffset,
          type: type['type'] as String,
          distance: (i + 1) * 0.5, // Closer distance for Pargo
          fee: type['fee'] as double,
          operatingHours: type['hours'] as String,
          isPargoPoint: true, // These are mock Pargo points
          pargoId: 'pargo_fallback_${i + 1}',
          isPaxiPoint: false,
        );
        
        pickupPoints.add(pickupPoint);
      }
      
      print('🔍 Created ${pickupPoints.length} fallback Pargo pickup points');
      return pickupPoints;
      
    } catch (e) {
      print('❌ Error creating fallback Pargo pickup points: $e');
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


