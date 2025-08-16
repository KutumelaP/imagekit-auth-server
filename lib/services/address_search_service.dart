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



  // Search addresses using Google Places API
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
        List<AddressSuggestion> results = await _searchWithHereMaps(query);
        
        print('🔍 HERE Maps API returned ${results.length} results');

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

  // Search using HERE Maps Geocoding API
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
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
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