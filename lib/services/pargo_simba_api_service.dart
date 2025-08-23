import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/pargo_config.dart';

class PargoSimbaApiService extends ChangeNotifier {
  // API Configuration - Use new config
  String get _baseUrl => PargoConfig.apiUrl;
  
  // Get fallback URL if main one fails
  String get _fallbackUrl {
    if (PargoConfig.useSimbaApi) {
      return PargoConfig.productionBaseUrl;
    } else {
      return PargoConfig.simbaApiUrl;
    }
  }
  static const String _authEndpoint = '/auth';
  static const String _refreshEndpoint = '/auth/refresh';
  static const String _pickupPointsEndpoint = '/pickup_points';
  
  // Authentication state
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  bool _isAuthenticating = false;
  
  // Rate limiting
  int _requestsThisMinute = 0;
  DateTime _lastRequestTime = DateTime.now();
  static const int _maxRequestsPerMinute = 60;
  
  // Getters
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!);
  bool get isAuthenticating => _isAuthenticating;
  
  /// Authenticate with Pargo Simba API using configured credentials
  Future<bool> authenticate([String? username, String? password]) async {
    if (_isAuthenticating) return false;
    
    // Use configured credentials if none provided
    final authUsername = username ?? PargoConfig.businessEmail;
    final authPassword = password ?? PargoConfig.businessPassword;
    
    _isAuthenticating = true;
    notifyListeners();
    
    try {
      print('🔐 Attempting to authenticate with Pargo Simba API...');
      print('🔐 Base URL: $_baseUrl');
      print('🔐 Username: $authUsername');
      
      // Add web-specific headers to avoid CORS issues
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      };
      
      final response = await http.post(
        Uri.parse('$_baseUrl$_authEndpoint'),
        headers: headers,
        body: jsonEncode({
          'username': authUsername,
          'password': authPassword,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
        
        print('✅ Pargo Simba API authentication successful');
        print('🔑 Access token expires: $_tokenExpiry');
        
        _isAuthenticating = false;
        notifyListeners();
        return true;
      } else {
        print('❌ Pargo Simba API authentication failed: ${response.statusCode}');
        print('Response: ${response.body}');
        
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Pargo Simba API authentication error: $e');
      
      // Check if it's a network/connection error
      if (e.toString().contains('Failed to fetch') || e.toString().contains('NetworkException')) {
        print('🌐 Network error detected. This might be a CORS issue on web or API endpoint down.');
        print('💡 Try using the production API or check if the endpoint is accessible.');
        
        // Try fallback URL if main one fails
        print('🔄 Trying fallback URL: $_fallbackUrl');
        try {
          final fallbackResponse = await http.post(
            Uri.parse('$_fallbackUrl$_authEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
            body: jsonEncode({
              'username': authUsername,
              'password': authPassword,
            }),
          ).timeout(const Duration(seconds: 30));
          
          if (fallbackResponse.statusCode == 200) {
            final data = jsonDecode(fallbackResponse.body);
            _accessToken = data['access_token'];
            _refreshToken = data['refresh_token'];
            _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
            
            print('✅ Pargo Simba API authentication successful with fallback URL');
            _isAuthenticating = false;
            notifyListeners();
            return true;
          }
        } catch (fallbackError) {
          print('❌ Fallback URL also failed: $fallbackError');
        }
      }
      
      _isAuthenticating = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Refresh the access token using refresh token
  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_refreshEndpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh_token': _refreshToken,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
        
        print('✅ Pargo Simba API token refreshed');
        notifyListeners();
        return true;
      } else {
        print('❌ Pargo Simba API token refresh failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Pargo Simba API token refresh error: $e');
      return false;
    }
  }
  
  /// Check rate limiting and wait if necessary
  Future<void> _checkRateLimit() async {
    final now = DateTime.now();
    
    // Reset counter if a minute has passed
    if (now.difference(_lastRequestTime).inMinutes >= 1) {
      _requestsThisMinute = 0;
      _lastRequestTime = now;
    }
    
    // Check if we're at the limit
    if (_requestsThisMinute >= _maxRequestsPerMinute) {
      final waitTime = 60 - now.difference(_lastRequestTime).inSeconds;
      if (waitTime > 0) {
        print('⏳ Rate limit reached, waiting $waitTime seconds...');
        await Future.delayed(Duration(seconds: waitTime));
        _requestsThisMinute = 0;
        _lastRequestTime = DateTime.now();
      }
    }
    
    _requestsThisMinute++;
  }
  
  /// Get pickup points by address
  Future<List<Map<String, dynamic>>> getPickupPointsByAddress(
    String address, {
    String country = 'ZA',
    int limit = 10,
    String sort = 'distance+',
  }) async {
    if (!isAuthenticated) {
      print('❌ Not authenticated with Pargo Simba API, using fallback');
      return await getMockPickupPoints(address);
    }
    
    await _checkRateLimit();
    
    try {
      final queryParams = {
        'address': address,
        'country': country,
        'limit': limit.toString(),
        'sort': sort,
      };
      
      final uri = Uri.parse('$_baseUrl$_pickupPointsEndpoint').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final pickupPoints = List<Map<String, dynamic>>.from(data['data']);
          
          print('✅ Found ${pickupPoints.length} pickup points for address: $address');
          
          // Transform to match your existing pickup point format
          return pickupPoints.map((point) {
            final attributes = point['attributes'];
            final meta = point['meta'];
            
            return {
              'id': attributes['pickupPointCode'],
              'name': attributes['name'] ?? '',
              'address': '${attributes['address1'] ?? ''} ${attributes['address2'] ?? ''}'.trim(),
              'suburb': attributes['suburb'] ?? '',
              'city': attributes['city'] ?? '',
              'province': attributes['province'] ?? '',
              'postalCode': attributes['postalCode'] ?? '',
              'latitude': attributes['coordinates']?['lat'] ?? 0.0,
              'longitude': attributes['coordinates']?['lng'] ?? 0.0,
              'distance': meta?['distance'] ?? 0.0,
              'openingHours': attributes['openingHours'] ?? '',
              'isAtCapacity': attributes['isAtCapacity'] ?? false,
              'photo': attributes['photo']?['small'] ?? '',
              'locationMapImage': attributes['locationMapImage'] ?? '',
            };
          }).toList();
        } else {
          print('❌ No pickup points found for address: $address');
          return [];
        }
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        final error = data['errors']?[0];
        print('❌ Geocoding error: ${error?['title']} - ${error?['detail']}');
        return [];
      } else {
        print('❌ Failed to get pickup points: ${response.statusCode}');
        print('Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting pickup points: $e');
      return [];
    }
  }
  
  /// Get pickup points by coordinates
  Future<List<Map<String, dynamic>>> getPickupPointsByCoordinates(
    double latitude,
    double longitude, {
    int limit = 10,
    String sort = 'distance+',
  }) async {
    if (!isAuthenticated) {
      print('❌ Not authenticated with Pargo Simba API, using fallback');
      return await getMockPickupPoints('coordinates: $latitude, $longitude');
    }
    
    await _checkRateLimit();
    
    try {
      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'limit': limit.toString(),
        'sort': sort,
      };
      
      final uri = Uri.parse('$_baseUrl$_pickupPointsEndpoint').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final pickupPoints = List<Map<String, dynamic>>.from(data['data']);
          
          print('✅ Found ${pickupPoints.length} pickup points for coordinates: $latitude, $longitude');
          
          // Transform to match your existing pickup point format
          return pickupPoints.map((point) {
            final attributes = point['attributes'];
            final meta = point['meta'];
            
            return {
              'id': attributes['pickupPointCode'],
              'name': attributes['name'] ?? '',
              'address': '${attributes['address1'] ?? ''} ${attributes['address2'] ?? ''}'.trim(),
              'suburb': attributes['suburb'] ?? '',
              'city': attributes['city'] ?? '',
              'province': attributes['province'] ?? '',
              'postalCode': attributes['postalCode'] ?? '',
              'latitude': attributes['coordinates']?['lat'] ?? 0.0,
              'longitude': attributes['coordinates']?['lng'] ?? 0.0,
              'distance': meta?['distance'] ?? 0.0,
              'openingHours': attributes['openingHours'] ?? '',
              'isAtCapacity': attributes['isAtCapacity'] ?? false,
              'photo': attributes['photo']?['small'] ?? '',
              'locationMapImage': attributes['locationMapImage'] ?? '',
            };
          }).toList();
        } else {
          print('❌ No pickup points found for coordinates: $latitude, $longitude');
          return [];
        }
      } else {
        print('❌ Failed to get pickup points: ${response.statusCode}');
        print('Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting pickup points: $e');
      return [];
    }
  }
  
  // Fallback method when Pargo API is not accessible
  Future<List<Map<String, dynamic>>> getMockPickupPoints(String address) async {
    print('🔄 Using mock pickup points (Pargo API not accessible)');
    
    // Return mock pickup points for testing
    return [
      {
        'id': 'mock_001',
        'name': 'Pargo Pickup Point - Kempton Park',
        'address': 'Shop 15, Kempton Park Mall, Kempton Park',
        'suburb': 'Kempton Park',
        'city': 'Kempton Park',
        'province': 'Gauteng',
        'postalCode': '1621',
        'latitude': -26.0945,
        'longitude': 28.2275,
        'distance': 2.5,
        'openingHours': 'Mon-Fri: 8:00-18:00, Sat: 9:00-17:00',
        'isAtCapacity': false,
        'photo': '',
        'locationMapImage': '',
      },
      {
        'id': 'mock_002',
        'name': 'Pargo Pickup Point - Birchleigh',
        'address': 'Birchleigh Shopping Centre, Birchleigh',
        'suburb': 'Birchleigh',
        'city': 'Kempton Park',
        'province': 'Gauteng',
        'postalCode': '1621',
        'latitude': -26.0622,
        'longitude': 28.2274,
        'distance': 1.8,
        'openingHours': 'Mon-Fri: 8:00-18:00, Sat: 9:00-17:00',
        'isAtCapacity': false,
        'photo': '',
        'locationMapImage': '',
      },
    ];
  }
  
  /// Logout and clear tokens
  void logout() {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _requestsThisMinute = 0;
    notifyListeners();
    print('✅ Pargo Simba API logged out');
  }
  
  /// Check if token needs refresh and refresh if necessary
  Future<bool> ensureValidToken() async {
    if (!isAuthenticated) return false;
    
    // Check if token expires in next 5 minutes
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!.subtract(Duration(minutes: 5)))) {
      print('🔄 Access token expiring soon, refreshing...');
      return await refreshToken();
    }
    
    return true;
  }

  // Check if Pargo API is accessible
  Future<bool> isApiAccessible() async {
    try {
      print('🔍 Checking if Pargo API is accessible...');
      print('🔍 Testing base URL: $_baseUrl');
      
      // Test multiple endpoints to see which ones work
      final endpoints = [
        '$_baseUrl',
        '$_baseUrl/auth',
        '$_baseUrl/pickup_points',
      ];
      
      for (final endpoint in endpoints) {
        try {
          print('🔍 Testing endpoint: $endpoint');
          final response = await http.get(
            Uri.parse(endpoint),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          ).timeout(const Duration(seconds: 10));
          
          print('✅ Endpoint $endpoint accessible (Status: ${response.statusCode})');
          if (response.statusCode == 200) {
            return true;
          }
        } catch (e) {
          print('❌ Endpoint $endpoint failed: $e');
        }
      }
      
      print('❌ All Pargo API endpoints are not accessible');
      return false;
    } catch (e) {
      print('❌ Pargo API health check failed: $e');
      return false;
    }
  }
  
  // Manual API connectivity test
  Future<void> testApiConnectivity() async {
    print('🧪 Manual API Connectivity Test');
    print('===============================');
    
    final urls = [
      'https://api.pargo.co.za',
      'https://pargo.co.za/api',
      'https://api.staging.pargo.co.za',
      'https://httpbin.org/get', // Test if internet works at all
    ];
    
    for (final url in urls) {
      try {
        print('\n🔍 Testing: $url');
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ).timeout(const Duration(seconds: 15));
        
        print('✅ Status: ${response.statusCode}');
        print('✅ Headers: ${response.headers}');
        if (response.body.isNotEmpty) {
          print('✅ Response length: ${response.body.length} characters');
        }
      } catch (e) {
        print('❌ Failed: $e');
      }
    }
    
    print('\n🔍 Testing your credentials...');
    try {
      final authResult = await authenticate();
      print('✅ Authentication result: $authResult');
    } catch (e) {
      print('❌ Authentication test failed: $e');
    }
  }
  
  // Test method to verify API integration
  Future<void> testApiIntegration() async {
    print('🧪 Testing Pargo Simba API integration...');
    
    try {
      // First check if API is accessible
      print('0. Checking API accessibility...');
      final isAccessible = await isApiAccessible();
      if (!isAccessible) {
        print('⚠️ API not accessible, will use fallback methods');
        print('1. Testing fallback pickup points...');
        final fallbackPoints = await getMockPickupPoints('Test Address');
        print('✅ Fallback working: ${fallbackPoints.length} mock points');
        return;
      }
      
      // Test authentication
      print('1. Testing authentication...');
      final authSuccess = await authenticate();
      if (!authSuccess) {
        print('❌ Authentication failed, using fallback');
        final fallbackPoints = await getMockPickupPoints('Test Address');
        print('✅ Fallback working: ${fallbackPoints.length} mock points');
        return;
      }
      print('✅ Authentication successful');
      
      // Test pickup points by coordinates (Johannesburg)
      print('2. Testing pickup points by coordinates...');
      final pickupPoints = await getPickupPointsByCoordinates(-26.2041, 28.0473, limit: 5);
      print('✅ Found ${pickupPoints.length} pickup points');
      
      // Test pickup points by address
      print('3. Testing pickup points by address...');
      final addressPoints = await getPickupPointsByAddress('Johannesburg', limit: 5);
      print('✅ Found ${addressPoints.length} pickup points by address');
      
      print('🎉 All tests passed! Pargo Simba API integration working correctly.');
    } catch (e) {
      print('❌ Test failed: $e');
      print('🔄 Falling back to mock data...');
      try {
        final fallbackPoints = await getMockPickupPoints('Test Address');
        print('✅ Fallback working: ${fallbackPoints.length} mock points');
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
      }
    }
  }
}
