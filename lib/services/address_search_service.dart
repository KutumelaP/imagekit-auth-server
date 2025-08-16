import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressSuggestion {
  final String label;
  final String street;
  final String locality;
  final String administrativeArea;
  final String postalCode;
  final double? latitude;
  final double? longitude;

  const AddressSuggestion({
    required this.label,
    required this.street,
    required this.locality,
    required this.administrativeArea,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
  });
}

class AddressSearchService extends ChangeNotifier {
  Timer? _searchTimer;
  List<AddressSuggestion> _suggestions = [];
  bool _isSearching = false;
  int _currentSearchId = 0;
  double? _userLat;
  double? _userLng;

  // HERE Maps API configuration
  static const String _hereApiKey = 'F2ZQ7Djp9L9lUHpw4qvxlrgCePbtSgD7efexLP_kU_A';
  static const String _hereGeocodingUrl = 'https://geocode.search.hereapi.com/v1/geocode';
  static const String _hereAutocompleteUrl = 'https://autocomplete.search.hereapi.com/v1/autocomplete';

  List<AddressSuggestion> get suggestions => _suggestions;
  bool get isSearching => _isSearching;

  // Set user location for biasing results
  void setUserLocation({required double latitude, required double longitude}) {
    _userLat = latitude;
    _userLng = longitude;
  }

  // Search addresses using HERE Maps API (web-compatible)
  Future<void> searchAddresses(String query) async {
    print('🔍 AddressSearchService.searchAddresses called with: "$query"');
    
    if (query.trim().isEmpty) {
      print('🔍 Query is empty, clearing suggestions');
      _suggestions = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    // Cancel previous search
    _searchTimer?.cancel();
    print('🔍 Previous search cancelled');

    // Set searching state
    _isSearching = true;
    notifyListeners();
    print('🔍 Set searching state to true');

    // Increment search id to track latest search
    _currentSearchId++;
    final int localSearchId = _currentSearchId;

    // Debounce search for 300ms
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      print('🔍 Starting debounced search for: "$query"');
      
      try {
        List<AddressSuggestion> results = [];
        
        // Check if we're on web platform
        if (kIsWeb) {
          print('🔍 Web platform detected, using web-specific search');
          results = await _searchForWeb(query);
        } else {
          // Try HERE Maps first (works on mobile)
          results = await _searchWithHereMaps(query);
          
          // If HERE Maps fails, try fallback search
          if (results.isEmpty) {
            print('🔍 HERE Maps returned no results, trying fallback search');
            results = await _searchWithFallback(query);
          }
        }
        
        print('🔍 Search returned ${results.length} results');

        // Ignore stale results from older searches
        if (localSearchId < _currentSearchId) {
          print('🔍 Stale results ignored for searchId=$localSearchId (current=${_currentSearchId})');
          return;
        }
        
        _suggestions = results;
        _isSearching = false;
        notifyListeners();
        
        print('✅ Found ${_suggestions.length} address suggestions');
      } catch (e) {
        print('❌ Error in address search: $e');
        // Ignore stale errors as well
        if (localSearchId < _currentSearchId) {
          print('🔍 Stale error ignored for searchId=$localSearchId (current=${_currentSearchId})');
          return;
        }
        _suggestions = [_createFallbackSuggestion(query)];
        _isSearching = false;
        notifyListeners();
        print('✅ Created fallback address suggestion');
      }
    });
  }

  // Search using HERE Maps Geocoding API (web-compatible)
  Future<List<AddressSuggestion>> _searchWithHereMaps(String query) async {
    try {
      // Build query parameters for HERE Maps
      final Map<String, String> queryParams = {
        'q': query,
        'apiKey': _hereApiKey,
        'limit': '7',
        'lang': 'en',
        'countryCode': 'ZAF', // South Africa
      };

      // Add location bias if user location is available
      if (_userLat != null && _userLng != null) {
        queryParams['at'] = '${_userLat!.toStringAsFixed(6)},${_userLng!.toStringAsFixed(6)}';
        queryParams['radius'] = '50000'; // 50km radius
      }

      print('🔍 HERE Maps API request params: $queryParams');
      
      final uri = Uri.parse(_hereGeocodingUrl).replace(queryParameters: queryParams);
      
      // Handle CORS issues on web by using a different approach
      http.Response response;
      try {
        response = await http.get(uri).timeout(const Duration(seconds: 10));
      } catch (e) {
        print('⚠️ Direct HTTP request failed, trying with CORS headers: $e');
        // Try with additional headers for web compatibility
        response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
      }
      
      print('🔍 HERE Maps API response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('⚠️ HERE Maps API returned non-200 status: ${response.statusCode}');
        print('🔍 Response body: ${response.body}');
        return [];
      }
      
      final data = json.decode(response.body);
      
      if (data['error'] != null) {
        print('⚠️ HERE Maps API error: ${data['error']}');
        return [];
      }
      
      final items = data['items'] as List<dynamic>? ?? [];
      print('🔍 HERE Maps API returned ${items.length} items');
      
      List<AddressSuggestion> suggestions = [];
      
      // Convert HERE Maps items to address suggestions
      for (final item in items) {
        try {
          final suggestion = _createSuggestionFromHereItem(item);
          if (suggestion != null) {
            suggestions.add(suggestion);
          }
        } catch (e) {
          print('⚠️ Error processing HERE Maps item: $e');
          continue;
        }
      }
      
      print('🔍 Processed ${suggestions.length} valid suggestions');
      return suggestions;
      
    } catch (e) {
      print('❌ HERE Maps API search failed: $e');
      return [];
    }
  }

  // Fallback search method for web compatibility
  Future<List<AddressSuggestion>> _searchWithFallback(String query) async {
    try {
      print('🔍 Using fallback search for: $query');
      
      // Create basic suggestions based on the query
      List<AddressSuggestion> suggestions = [];
      
      // Add the query itself as a suggestion
      suggestions.add(AddressSuggestion(
        label: query,
        street: query,
        locality: 'Enter manually',
        administrativeArea: 'South Africa',
        postalCode: '',
        latitude: null,
        longitude: null,
      ));
      
      // Add some common South African cities if query matches
      final lowerQuery = query.toLowerCase();
      final commonCities = [
        'Johannesburg', 'Cape Town', 'Durban', 'Pretoria', 'Port Elizabeth',
        'Bloemfontein', 'East London', 'Kimberley', 'Nelspruit', 'Polokwane'
      ];
      
      for (final city in commonCities) {
        if (city.toLowerCase().contains(lowerQuery) || lowerQuery.contains(city.toLowerCase())) {
          suggestions.add(AddressSuggestion(
            label: city,
            street: city,
            locality: city,
            administrativeArea: 'South Africa',
            postalCode: '',
            latitude: null,
            longitude: null,
          ));
        }
      }
      
      // Add postal code suggestions if query looks like a postal code
      if (RegExp(r'^\d{4}$').hasMatch(query)) {
        suggestions.add(AddressSuggestion(
          label: 'Postal Code: $query',
          street: 'Postal Code: $query',
          locality: 'South Africa',
          administrativeArea: 'South Africa',
          postalCode: query,
          latitude: null,
          longitude: null,
        ));
      }
      
      print('🔍 Fallback search returned ${suggestions.length} suggestions');
      return suggestions;
      
    } catch (e) {
      print('❌ Fallback search failed: $e');
      return [];
    }
  }

  // Web-specific search method that avoids CORS issues
  Future<List<AddressSuggestion>> _searchForWeb(String query) async {
    try {
      print('🔍 Using web-specific search for: $query');
      
      List<AddressSuggestion> suggestions = [];
      final lowerQuery = query.toLowerCase();
      
      // Add the query itself as a suggestion
      suggestions.add(AddressSuggestion(
        label: query,
        street: query,
        locality: 'Enter manually',
        administrativeArea: 'South Africa',
        postalCode: '',
        latitude: null,
        longitude: null,
      ));
      
      // South African cities and major areas
      final cities = [
        'Johannesburg', 'Cape Town', 'Durban', 'Pretoria', 'Port Elizabeth',
        'Bloemfontein', 'East London', 'Kimberley', 'Nelspruit', 'Polokwane',
        'Rustenburg', 'Welkom', 'Pietermaritzburg', 'Benoni', 'Vereeniging',
        'Soweto', 'Sandton', 'Centurion', 'Randburg', 'Roodepoort'
      ];
      
      // Add matching cities
      for (final city in cities) {
        if (city.toLowerCase().contains(lowerQuery) || lowerQuery.contains(city.toLowerCase())) {
          suggestions.add(AddressSuggestion(
            label: city,
            street: city,
            locality: city,
            administrativeArea: 'South Africa',
            postalCode: '',
            latitude: null,
            longitude: null,
          ));
        }
      }
      
      // South African provinces
      final provinces = [
        'Gauteng', 'Western Cape', 'KwaZulu-Natal', 'Eastern Cape',
        'Free State', 'Mpumalanga', 'Limpopo', 'North West', 'Northern Cape'
      ];
      
      // Add matching provinces
      for (final province in provinces) {
        if (province.toLowerCase().contains(lowerQuery) || lowerQuery.contains(province.toLowerCase())) {
          suggestions.add(AddressSuggestion(
            label: '$province Province',
            street: '$province Province',
            locality: '$province Province',
            administrativeArea: 'South Africa',
            postalCode: '',
            latitude: null,
            longitude: null,
          ));
        }
      }
      
      // Common street types
      final streetTypes = [
        'Street', 'Road', 'Avenue', 'Drive', 'Lane', 'Close', 'Way',
        'Crescent', 'Place', 'Square', 'Boulevard', 'Highway', 'Main Road'
      ];
      
      // Add street suggestions
      for (final streetType in streetTypes) {
        if (lowerQuery.contains(streetType.toLowerCase())) {
          suggestions.add(AddressSuggestion(
            label: '$query $streetType',
            street: '$query $streetType',
            locality: 'Enter city manually',
            administrativeArea: 'South Africa',
            postalCode: '',
            latitude: null,
            longitude: null,
          ));
        }
      }
      
      // Postal code suggestions
      if (RegExp(r'^\d{4}$').hasMatch(query)) {
        suggestions.add(AddressSuggestion(
          label: 'Postal Code: $query',
          street: 'Postal Code: $query',
          locality: 'South Africa',
          administrativeArea: 'South Africa',
          postalCode: query,
          latitude: null,
          longitude: null,
        ));
      }
      
      // Remove duplicates based on label
      final uniqueSuggestions = <String, AddressSuggestion>{};
      for (final suggestion in suggestions) {
        uniqueSuggestions[suggestion.label] = suggestion;
      }
      
      final result = uniqueSuggestions.values.toList();
      print('🔍 Web search returned ${result.length} unique suggestions');
      return result;
      
    } catch (e) {
      print('❌ Web search failed: $e');
      return [];
    }
  }

  // Create suggestion from HERE Maps response
  AddressSuggestion? _createSuggestionFromHereItem(Map<String, dynamic> item) {
    try {
      final title = item['title'] as String? ?? '';
      final address = item['address'] as Map<String, dynamic>? ?? {};
      final position = item['position'] as Map<String, dynamic>? ?? {};
      
      if (title.isEmpty) {
        return null;
      }
      
      // Extract address components from HERE Maps structure
      final street = address['street'] as String? ?? '';
      final locality = address['city'] as String? ?? '';
      final administrativeArea = address['state'] as String? ?? '';
      final postalCode = address['postalCode'] as String? ?? '';
      final formattedAddress = address['label'] as String? ?? '';
      
      final lat = position['lat']?.toDouble();
      final lng = position['lng']?.toDouble();
      
      return AddressSuggestion(
        label: title.isNotEmpty ? title : formattedAddress,
        street: street,
        locality: locality,
        administrativeArea: administrativeArea,
        postalCode: postalCode,
        latitude: lat,
        longitude: lng,
      );
      
    } catch (e) {
      print('⚠️ Error creating suggestion from HERE Maps item: $e');
      return null;
    }
  }

  // Create a fallback suggestion when search fails
  AddressSuggestion _createFallbackSuggestion(String query) {
    return AddressSuggestion(
      label: query,
      street: query,
      locality: 'Unknown',
      administrativeArea: 'Unknown',
      postalCode: '',
      latitude: null,
      longitude: null,
    );
  }

  // Format address for display
  String formatAddress(AddressSuggestion suggestion) => suggestion.label;

  // Get coordinates for delivery fee calculation
  Map<String, double>? getCoordinatesForAddress(String address) {
    // Try to find coordinates from current suggestions
    for (final suggestion in _suggestions) {
      if (suggestion.label.toLowerCase().contains(address.toLowerCase()) ||
          address.toLowerCase().contains(suggestion.street.toLowerCase())) {
        if (suggestion.latitude != null && suggestion.longitude != null) {
          return {
            'latitude': suggestion.latitude!,
            'longitude': suggestion.longitude!,
          };
        }
      }
    }
    return null;
  }

  // Clear search results
  void clearSearch() {
    print('🔍 Clearing search results');
    _suggestions = [];
    _isSearching = false;
    _searchTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    print('🔍 Disposing AddressSearchService');
    _searchTimer?.cancel();
    super.dispose();
  }
}