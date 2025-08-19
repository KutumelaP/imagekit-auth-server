import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/here_config.dart';

class AddressSearchService extends ChangeNotifier {
  // Rate limiting for OpenStreetMap (1 request per second)
  static DateTime? _lastOpenStreetMapRequest;
  static const Duration _openStreetMapRateLimit = Duration(seconds: 1);

  // OpenStreetMap Configuration (fallback)
  static const String _openStreetMapUrl = 'https://nominatim.openstreetmap.org/search';

  /// Search for addresses using HERE API (primary) or OpenStreetMap (fallback)
  Future<List<Map<String, dynamic>>> searchAddresses(String query, {
    double? latitude,
    double? longitude,
    int limit = 10,
  }) async {
    try {
      // Try HERE API first (better for web)
      if (HereConfig.isConfigured) {
        try {
          final hereResults = await _searchWithHereApi(query, latitude, longitude, limit);
          if (hereResults.isNotEmpty) {
            print('✅ HERE API search successful: ${hereResults.length} results');
            return hereResults;
          }
        } catch (e) {
          print('⚠️ HERE API failed, falling back to OpenStreetMap: $e');
        }
      }

      // Fallback to OpenStreetMap
      return await _searchWithOpenStreetMap(query, latitude, longitude, limit);
    } catch (e) {
      print('❌ All address search methods failed: $e');
      return [];
    }
  }

  /// Search using HERE API
  Future<List<Map<String, dynamic>>> _searchWithHereApi(
    String query,
    double? latitude,
    double? longitude,
    int limit,
  ) async {
    final queryParams = <String, String>{
      'q': query,
      'limit': limit.toString(),
      'apiKey': HereConfig.validatedApiKey,
    };

    // Add location bias if coordinates provided
    if (latitude != null && longitude != null) {
      queryParams['at'] = '$latitude,$longitude';
      queryParams['radius'] = '50000'; // 50km radius
    }

    final uri = Uri.parse(HereConfig.discoverUrl).replace(queryParameters: queryParams);
    
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
      
      return items.map<Map<String, dynamic>>((item) {
        final position = item['position'] ?? {};
        final address = item['address'] ?? {};
        
        return {
          'id': item['id'] ?? '',
          'title': item['title'] ?? '',
          'address': address['label'] ?? '',
          'suburb': address['subdistrict'] ?? '',
          'city': address['city'] ?? '',
          'province': address['state'] ?? '',
          'postalCode': address['postalCode'] ?? '',
          'country': address['countryCode'] ?? '',
          'latitude': position['lat']?.toDouble() ?? 0.0,
          'longitude': position['lng']?.toDouble() ?? 0.0,
          'distance': item['distance']?.toDouble() ?? 0.0,
          'source': 'HERE API',
        };
      }).toList();
    } else {
      throw Exception('HERE API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Search using OpenStreetMap (fallback)
  Future<List<Map<String, dynamic>>> _searchWithOpenStreetMap(
    String query,
    double? latitude,
    double? longitude,
    int limit,
  ) async {
    // Rate limiting for OpenStreetMap
    if (_lastOpenStreetMapRequest != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastOpenStreetMapRequest!);
      if (timeSinceLastRequest < _openStreetMapRateLimit) {
        final waitTime = _openStreetMapRateLimit - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }
    }
    _lastOpenStreetMapRequest = DateTime.now();

    final queryParams = <String, String>{
      'q': query,
      'format': 'json',
      'limit': limit.toString(),
      'addressdetails': '1',
      'countrycodes': 'za', // Focus on South Africa
    };

    // Add location bias if coordinates provided
    if (latitude != null && longitude != null) {
      queryParams['viewbox'] = '${longitude - 0.1},${latitude + 0.1},${longitude + 0.1},${latitude - 0.1}';
      queryParams['bounded'] = '1';
    }

    final uri = Uri.parse(_openStreetMapUrl).replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'MzansiMarketplace/1.0',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is List ? data : [data];
      
      return items.map<Map<String, dynamic>>((item) {
        final address = item['address'] ?? {};
        
        return {
          'id': item['place_id']?.toString() ?? '',
          'title': item['display_name'] ?? '',
          'address': item['display_name'] ?? '',
          'suburb': address['suburb'] ?? address['neighbourhood'] ?? '',
          'city': address['city'] ?? address['town'] ?? '',
          'province': address['state'] ?? address['province'] ?? '',
          'postalCode': address['postcode'] ?? '',
          'country': address['country_code']?.toUpperCase() ?? '',
          'latitude': double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0,
          'longitude': double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0,
          'distance': 0.0, // OpenStreetMap doesn't provide distance
          'source': 'OpenStreetMap',
        };
      }).toList();
    } else {
      throw Exception('OpenStreetMap error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Search for pickup points specifically
  Future<List<Map<String, dynamic>>> searchPickupPoints(
    double latitude,
    double longitude, {
    int limit = 10,
    String query = 'pargo pickup point',
  }) async {
    try {
      // Try HERE API first for pickup points
      if (HereConfig.isConfigured) {
        try {
          final hereResults = await _searchWithHereApi(query, latitude, longitude, limit);
          if (hereResults.isNotEmpty) {
            print('✅ HERE API pickup points search successful: ${hereResults.length} results');
            return hereResults;
          }
        } catch (e) {
          print('⚠️ HERE API pickup points failed: $e');
        }
      }

      // Fallback to generic address search
      return await searchAddresses(query, latitude: latitude, longitude: longitude, limit: limit);
    } catch (e) {
      print('❌ Pickup points search failed: $e');
      return [];
    }
  }

  /// Test HERE API integration
  Future<void> testHereApiIntegration() async {
    if (!HereConfig.isConfigured) {
      print('⚠️ HERE API key not configured. Please set your API key in HereConfig.apiKey');
      return;
    }

    try {
      print('🧪 Testing HERE API integration...');
      
      // Test address search
      final results = await _searchWithHereApi('Johannesburg', -26.2041, 28.0473, 5);
      print('✅ HERE API test successful: ${results.length} results');
      
      // Test pickup points search
      final pickupResults = await searchPickupPoints(-26.2041, 28.0473, limit: 3);
      print('✅ Pickup points search successful: ${pickupResults.length} results');
      
    } catch (e) {
      print('❌ HERE API test failed: $e');
    }
  }

  /// Test OpenStreetMap integration
  Future<void> testOpenStreetMapIntegration() async {
    print('🧪 Testing OpenStreetMap integration...');
    
    try {
      final testResults = await _searchWithOpenStreetMap('Pretoria', null, null, 5);
      print('✅ OpenStreetMap test successful: ${testResults.length} results');
      
      if (testResults.isNotEmpty) {
        final firstResult = testResults.first;
        print('📍 First result: ${firstResult['title']}');
        print('📍 Coordinates: ${firstResult['latitude']}, ${firstResult['longitude']}');
        print('📍 Address: ${firstResult['address']}');
      }
    } catch (e) {
      print('❌ OpenStreetMap test failed: $e');
    }
  }
}