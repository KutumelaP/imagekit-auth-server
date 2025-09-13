import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../config/here_config.dart';

class HereMapsAddressService {
  static const String _baseUrl = 'https://geocode.search.hereapi.com/v1';
  static const String _autocompleteUrl = 'https://autosuggest.search.hereapi.com/v1';
  
  /// Search addresses with autocomplete
  static Future<List<Map<String, dynamic>>> searchAddresses({
    required String query,
    String? countryCode = 'ZA', // South Africa
    int limit = 10,
    double? latitude,
    double? longitude,
  }) async {
    if (query.length < 3) return [];
    
    try {
      final queryParams = <String, String>{
        'apikey': HereConfig.validatedApiKey,
        'q': query,
        'limit': limit.toString(),
      };
      
      // Add country code if provided
      if (countryCode != null) {
        queryParams['countryCode'] = countryCode;
      }
      
      // Add location context if provided (improves relevance)
      if (latitude != null && longitude != null) {
        queryParams['at'] = '$latitude,$longitude';
      }
      
      final url = Uri.parse('$_autocompleteUrl/autosuggest').replace(queryParameters: queryParams);
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        
        return items.map<Map<String, dynamic>>((item) {
          final address = item['address'] ?? {};
          final position = item['position'] ?? {};
          
          return {
            'title': item['title'] ?? '',
            'label': item['address']?['label'] ?? '',
            'street': address['street'] ?? '',
            'district': address['district'] ?? '',
            'city': address['city'] ?? '',
            'county': address['county'] ?? '',
            'state': address['state'] ?? '',
            'countryName': address['countryName'] ?? '',
            'postalCode': address['postalCode'] ?? '',
            'latitude': position['lat']?.toDouble() ?? 0.0,
            'longitude': position['lng']?.toDouble() ?? 0.0,
            'resultType': item['resultType'] ?? 'address',
          };
        }).toList();
      } else {
        print('HERE API Error: ${response.statusCode} - ${response.body}');
        return _getFallbackAddresses(query);
      }
    } catch (e) {
      print('Address search error: $e');
      return _getFallbackAddresses(query);
    }
  }

  /// Fallback address suggestions for when HERE API is unavailable
  static List<Map<String, dynamic>> _getFallbackAddresses(String query) {
    final lowerQuery = query.toLowerCase();
    final fallbackAddresses = [
      // Major South African cities and common areas
      {
        'title': 'Cape Town City Centre',
        'label': 'Cape Town City Centre, Cape Town, 8001, South Africa',
        'street': '',
        'houseNumber': '',
        'district': 'City Centre',
        'city': 'Cape Town',
        'county': 'Cape Town',
        'state': 'Western Cape',
        'countryName': 'South Africa',
        'postalCode': '8001',
        'latitude': -33.9249,
        'longitude': 18.4241,
        'resultType': 'address',
      },
      {
        'title': 'Johannesburg City Centre',
        'label': 'Johannesburg City Centre, Johannesburg, 2001, South Africa',
        'street': '',
        'houseNumber': '',
        'district': 'City Centre',
        'city': 'Johannesburg',
        'county': 'Johannesburg',
        'state': 'Gauteng',
        'countryName': 'South Africa',
        'postalCode': '2001',
        'latitude': -26.2041,
        'longitude': 28.0473,
        'resultType': 'address',
      },
      {
        'title': 'Sandton',
        'label': 'Sandton, Johannesburg, 2196, South Africa',
        'street': '',
        'houseNumber': '',
        'district': 'Sandton',
        'city': 'Johannesburg',
        'county': 'Johannesburg',
        'state': 'Gauteng',
        'countryName': 'South Africa',
        'postalCode': '2196',
        'latitude': -26.1076,
        'longitude': 28.0567,
        'resultType': 'address',
      },
      {
        'title': 'Pretoria City Centre',
        'label': 'Pretoria City Centre, Pretoria, 0001, South Africa',
        'street': '',
        'houseNumber': '',
        'district': 'City Centre',
        'city': 'Pretoria',
        'county': 'Pretoria',
        'state': 'Gauteng',
        'countryName': 'South Africa',
        'postalCode': '0001',
        'latitude': -25.7479,
        'longitude': 28.2293,
        'resultType': 'address',
      },
      {
        'title': 'Durban City Centre',
        'label': 'Durban City Centre, Durban, 4001, South Africa',
        'street': '',
        'houseNumber': '',
        'district': 'City Centre',
        'city': 'Durban',
        'county': 'eThekwini',
        'state': 'KwaZulu-Natal',
        'countryName': 'South Africa',
        'postalCode': '4001',
        'latitude': -29.8587,
        'longitude': 31.0218,
        'resultType': 'address',
      },
    ];

    // Filter fallback addresses based on query
    if (query.length < 2) return fallbackAddresses.take(3).toList();
    
    return fallbackAddresses.where((address) {
      return (address['title'] as String).toLowerCase().contains(lowerQuery) ||
             (address['city'] as String).toLowerCase().contains(lowerQuery) ||
             (address['state'] as String).toLowerCase().contains(lowerQuery) ||
             (address['district'] as String).toLowerCase().contains(lowerQuery);
    }).toList();
  }
  
  /// Reverse geocoding - get address from coordinates
  static Future<Map<String, dynamic>?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/revgeocode').replace(queryParameters: {
        'apikey': HereConfig.validatedApiKey,
        'at': '$latitude,$longitude',
        // Remove types parameter as 'houseNumber' is not supported
      });
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        
        if (items.isNotEmpty) {
          final item = items.first;
          final address = item['address'] ?? {};
          
          return {
            'title': item['title'] ?? '',
            'label': address['label'] ?? '',
            'street': address['street'] ?? '',
            'houseNumber': address['houseNumber'] ?? '',
            'district': address['district'] ?? '',
            'city': address['city'] ?? '',
            'county': address['county'] ?? '',
            'state': address['state'] ?? '',
            'countryName': address['countryName'] ?? 'South Africa',
            'postalCode': address['postalCode'] ?? '',
            'latitude': latitude,
            'longitude': longitude,
          };
        }
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    }
    return null;
  }
  
  /// Get current user location and address
  static Future<Map<String, dynamic>?> getCurrentLocationAddress() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      
      // Get address from coordinates
      final address = await getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      return address;
    } catch (e) {
      print('Current location error: $e');
      return null;
    }
  }
  
  /// Validate South African address format
  static bool isValidSouthAfricanAddress(Map<String, dynamic> address) {
    final city = address['city']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    final countryName = address['countryName']?.toString() ?? '';
    
    // Check if it's in South Africa
    if (!countryName.toLowerCase().contains('south africa') && 
        state.toLowerCase() != 'gauteng' &&
        state.toLowerCase() != 'western cape' &&
        state.toLowerCase() != 'kwazulu-natal') {
      return false;
    }
    
    // Must have city and some address components
    return city.isNotEmpty && 
           (address['street']?.toString().isNotEmpty == true ||
            address['district']?.toString().isNotEmpty == true);
  }
  
  /// Calculate delivery zone based on address
  static String getDeliveryZone(Map<String, dynamic> address) {
    final city = address['city']?.toString().toLowerCase() ?? '';
    final state = address['state']?.toString().toLowerCase() ?? '';
    final district = address['district']?.toString().toLowerCase() ?? '';
    
    // Major urban areas
    if (city.contains('johannesburg') || city.contains('sandton') || 
        city.contains('rosebank') || district.contains('johannesburg')) {
      return 'johannesburg_metro';
    }
    
    if (city.contains('cape town') || city.contains('bellville') ||
        district.contains('cape town')) {
      return 'cape_town_metro';
    }
    
    if (city.contains('durban') || city.contains('pietermaritzburg') ||
        district.contains('durban')) {
      return 'durban_metro';
    }
    
    if (city.contains('pretoria') || city.contains('centurion') ||
        district.contains('pretoria')) {
      return 'pretoria_metro';
    }
    
    // Provincial areas
    if (state.contains('gauteng')) {
      return 'gauteng_urban';
    }
    
    if (state.contains('western cape')) {
      return 'western_cape_urban';
    }
    
    if (state.contains('kwazulu')) {
      return 'kwazulu_natal_urban';
    }
    
    // Default to rural
    return 'rural';
  }
  
  /// Get delivery fee for address
  static double getDeliveryFeeForAddress(Map<String, dynamic> address, double distance) {
    final zone = getDeliveryZone(address);
    
    switch (zone) {
      case 'johannesburg_metro':
      case 'cape_town_metro':
      case 'durban_metro':
      case 'pretoria_metro':
        return 15.0 + (distance * 3.0); // R15 base + R3/km
        
      case 'gauteng_urban':
      case 'western_cape_urban':
      case 'kwazulu_natal_urban':
        return 20.0 + (distance * 4.0); // R20 base + R4/km
        
      default: // rural
        return 30.0 + (distance * 6.0); // R30 base + R6/km
    }
  }
  
  /// Check if address is in excluded delivery zone
  static bool isAddressInExcludedZone(Map<String, dynamic> address) {
    final state = address['state']?.toString().toLowerCase() ?? '';
    final city = address['city']?.toString().toLowerCase() ?? '';
    
    // Example excluded areas (customize as needed)
    final excludedAreas = [
      'northern cape', // Remote province
      'limpopo',       // Remote areas
    ];
    
    return excludedAreas.any((area) => 
        state.contains(area) || city.contains(area));
  }
  
  /// Format address for display
  static String formatAddressForDisplay(Map<String, dynamic> address) {
    final components = <String>[];
    
    if (address['houseNumber']?.toString().isNotEmpty == true) {
      components.add(address['houseNumber'].toString());
    }
    
    if (address['street']?.toString().isNotEmpty == true) {
      components.add(address['street'].toString());
    }
    
    if (address['district']?.toString().isNotEmpty == true) {
      components.add(address['district'].toString());
    }
    
    if (address['city']?.toString().isNotEmpty == true) {
      components.add(address['city'].toString());
    }
    
    if (address['postalCode']?.toString().isNotEmpty == true) {
      components.add(address['postalCode'].toString());
    }
    
    return components.join(', ');
  }
}
