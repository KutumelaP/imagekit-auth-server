import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class AddressSearchService extends ChangeNotifier {
  Timer? _searchTimer;
  List<Placemark> _suggestions = [];
  bool _isSearching = false;

  // Alternative geocoding services
  static const String _photonApiUrl = 'https://photon.komoot.io/api/';
  static const String _nominatimApiUrl = 'https://nominatim.openstreetmap.org/search';
  
  // Fallback local database for when APIs are not available
  static const Map<String, List<Map<String, dynamic>>> _localAddresses = {
    'johannesburg': [
      {
        'address': 'Sandton, Johannesburg, Gauteng',
        'lat': -26.1076,
        'lng': 28.0567,
        'street': 'Sandton',
        'locality': 'Johannesburg',
        'province': 'Gauteng'
      },
      {
        'address': 'Rosebank, Johannesburg, Gauteng',
        'lat': -26.1445,
        'lng': 28.0453,
        'street': 'Rosebank',
        'locality': 'Johannesburg',
        'province': 'Gauteng'
      },
      {
        'address': 'Melville, Johannesburg, Gauteng',
        'lat': -26.1708,
        'lng': 28.0026,
        'street': 'Melville',
        'locality': 'Johannesburg',
        'province': 'Gauteng'
      },
      {
        'address': 'Parktown, Johannesburg, Gauteng',
        'lat': -26.1869,
        'lng': 28.0386,
        'street': 'Parktown',
        'locality': 'Johannesburg',
        'province': 'Gauteng'
      },
      {
        'address': 'Braamfontein, Johannesburg, Gauteng',
        'lat': -26.1997,
        'lng': 28.0447,
        'street': 'Braamfontein',
        'locality': 'Johannesburg',
        'province': 'Gauteng'
      },
    ],
    'cape town': [
      {
        'address': 'Sea Point, Cape Town, Western Cape',
        'lat': -33.9249,
        'lng': 18.4241,
        'street': 'Sea Point',
        'locality': 'Cape Town',
        'province': 'Western Cape'
      },
      {
        'address': 'Green Point, Cape Town, Western Cape',
        'lat': -33.9144,
        'lng': 18.4196,
        'street': 'Green Point',
        'locality': 'Cape Town',
        'province': 'Western Cape'
      },
      {
        'address': 'V&A Waterfront, Cape Town, Western Cape',
        'lat': -33.9036,
        'lng': 18.4201,
        'street': 'V&A Waterfront',
        'locality': 'Cape Town',
        'province': 'Western Cape'
      },
      {
        'address': 'Camps Bay, Cape Town, Western Cape',
        'lat': -33.9561,
        'lng': 18.3833,
        'street': 'Camps Bay',
        'locality': 'Cape Town',
        'province': 'Western Cape'
      },
      {
        'address': 'Claremont, Cape Town, Western Cape',
        'lat': -33.9816,
        'lng': 18.4653,
        'street': 'Claremont',
        'locality': 'Cape Town',
        'province': 'Western Cape'
      },
    ],
    'durban': [
      {
        'address': 'Berea, Durban, KwaZulu-Natal',
        'lat': -29.8587,
        'lng': 31.0218,
        'street': 'Berea',
        'locality': 'Durban',
        'province': 'KwaZulu-Natal'
      },
      {
        'address': 'Morningside, Durban, KwaZulu-Natal',
        'lat': -29.8587,
        'lng': 31.0218,
        'street': 'Morningside',
        'locality': 'Durban',
        'province': 'KwaZulu-Natal'
      },
      {
        'address': 'Umhlanga, Durban, KwaZulu-Natal',
        'lat': -29.6482,
        'lng': 31.1044,
        'street': 'Umhlanga',
        'locality': 'Durban',
        'province': 'KwaZulu-Natal'
      },
      {
        'address': 'Ballito, Durban, KwaZulu-Natal',
        'lat': -29.5389,
        'lng': 31.2074,
        'street': 'Ballito',
        'locality': 'Durban',
        'province': 'KwaZulu-Natal'
      },
    ],
    'pretoria': [
      {
        'address': 'Arcadia, Pretoria, Gauteng',
        'lat': -25.7479,
        'lng': 28.2293,
        'street': 'Arcadia',
        'locality': 'Pretoria',
        'province': 'Gauteng'
      },
      {
        'address': 'Hatfield, Pretoria, Gauteng',
        'lat': -25.7479,
        'lng': 28.2293,
        'street': 'Hatfield',
        'locality': 'Pretoria',
        'province': 'Gauteng'
      },
      {
        'address': 'Brooklyn, Pretoria, Gauteng',
        'lat': -25.7479,
        'lng': 28.2293,
        'street': 'Brooklyn',
        'locality': 'Pretoria',
        'province': 'Gauteng'
      },
      {
        'address': 'Menlyn, Pretoria, Gauteng',
        'lat': -25.7479,
        'lng': 28.2293,
        'street': 'Menlyn',
        'locality': 'Pretoria',
        'province': 'Gauteng'
      },
    ],
  };

  List<Placemark> get suggestions => _suggestions;
  bool get isSearching => _isSearching;

  // Search addresses with debouncing
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

    // Debounce search for 300ms
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      print('🔍 Starting debounced search for: "$query"');
      
      try {
        List<Placemark> placemarks = [];
        
        // Strategy 1: Try Photon API (best for autocomplete)
        print('🔍 Strategy 1: Trying Photon API...');
        placemarks = await _tryPhotonSearch(query);
        print('🔍 Photon API returned ${placemarks.length} results');
        
        // Strategy 2: If no Photon results, try Nominatim
        if (placemarks.isEmpty) {
          print('🔍 Strategy 2: No Photon results, trying Nominatim...');
          placemarks = await _tryNominatimSearch(query);
          print('🔍 Nominatim API returned ${placemarks.length} results');
        }
        
        // Strategy 3: If no API results, try local database
        if (placemarks.isEmpty) {
          print('🔍 Strategy 3: No API results, trying local database...');
          placemarks = await _searchLocalDatabase(query);
          print('🔍 Local database returned ${placemarks.length} results');
        }
        
        // Strategy 4: If still no results, create a fallback placemark
        if (placemarks.isEmpty) {
          print('🔍 Strategy 4: No placemarks found, creating fallback...');
          placemarks = [_createFallbackPlacemark(query)];
          print('🔍 Created fallback placemark');
        }

        print('🔍 Final results: ${placemarks.length} placemarks');
        
        _suggestions = placemarks;
        _isSearching = false;
        notifyListeners();
        
        print('✅ Found ${_suggestions.length} address suggestions');
      } catch (e) {
        print('❌ Error in address search: $e');
        print('❌ Stack trace: ${StackTrace.current}');
        _suggestions = [_createFallbackPlacemark(query)];
        _isSearching = false;
        notifyListeners();
        print('✅ Created fallback address suggestion');
      }
    });
  }

  // Try Photon API for address search
  Future<List<Placemark>> _tryPhotonSearch(String query) async {
    try {
      print('🔍 Trying Photon API for: "$query"');
      
      final url = Uri.parse('$_photonApiUrl?q=${Uri.encodeComponent(query)}&lang=en&limit=5&countrycodes=za');
      print('🔍 Photon API URL: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('🔍 Photon API timeout');
          throw TimeoutException('Photon API request timed out');
        },
      );
      
      print('🔍 Photon API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        
        print('🔍 Photon API features count: ${features?.length ?? 0}');
        
        if (features != null && features.isNotEmpty) {
          List<Placemark> placemarks = [];
          
          for (final feature in features) {
            final properties = feature['properties'];
            final geometry = feature['geometry'];
            
            if (properties != null && geometry != null) {
              final coordinates = geometry['coordinates'] as List?;
              if (coordinates != null && coordinates.length >= 2) {
                final placemark = Placemark(
                  name: properties['name'] ?? '',
                  street: properties['street'] ?? properties['name'] ?? '',
                  locality: properties['city'] ?? properties['town'] ?? '',
                  administrativeArea: properties['state'] ?? '',
                  country: 'South Africa',
                  postalCode: properties['postcode'] ?? '',
                  isoCountryCode: 'ZA',
                );
                placemarks.add(placemark);
                print('🔍 Added Photon placemark: ${placemark.name}');
              }
            }
          }
          
          print('🔍 Photon API found ${placemarks.length} results');
          return placemarks;
        }
      } else {
        print('🔍 Photon API error status: ${response.statusCode}');
      }
      
      print('🔍 Photon API returned no results or error');
      return [];
    } catch (e) {
      print('🔍 Photon API search failed: $e');
      return [];
    }
  }

  // Try Nominatim API for address search
  Future<List<Placemark>> _tryNominatimSearch(String query) async {
    try {
      print('🔍 Trying Nominatim API for: "$query"');
      
      final url = Uri.parse('$_nominatimApiUrl?q=${Uri.encodeComponent(query)}&countrycodes=za&format=json&limit=5&addressdetails=1');
      print('🔍 Nominatim API URL: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('🔍 Nominatim API timeout');
          throw TimeoutException('Nominatim API request timed out');
        },
      );
      
      print('🔍 Nominatim API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data as List?;
        
        print('🔍 Nominatim API results count: ${results?.length ?? 0}');
        
        if (results != null && results.isNotEmpty) {
          List<Placemark> placemarks = [];
          
          for (final result in results) {
            final address = result['address'] as Map<String, dynamic>?;
            if (address != null) {
              final placemark = Placemark(
                name: result['display_name'] ?? '',
                street: address['road'] ?? address['suburb'] ?? '',
                locality: address['city'] ?? address['town'] ?? address['suburb'] ?? '',
                administrativeArea: address['state'] ?? '',
                country: 'South Africa',
                postalCode: address['postcode'] ?? '',
                isoCountryCode: 'ZA',
              );
              placemarks.add(placemark);
              print('🔍 Added Nominatim placemark: ${placemark.name}');
            }
          }
          
          print('🔍 Nominatim API found ${placemarks.length} results');
          return placemarks;
        }
      } else {
        print('🔍 Nominatim API error status: ${response.statusCode}');
      }
      
      print('🔍 Nominatim API returned no results or error');
      return [];
    } catch (e) {
      print('🔍 Nominatim API search failed: $e');
      return [];
    }
  }

  // Search local database with real coordinates
  Future<List<Placemark>> _searchLocalDatabase(String query) async {
    try {
      print('🔍 Searching local database for: "$query"');
      
      final queryLower = query.toLowerCase().trim();
      List<Placemark> results = [];
      
      // Search through all cities
      for (final city in _localAddresses.keys) {
        if (queryLower.contains(city) || city.contains(queryLower)) {
          // Add all addresses for this city
          for (final addressData in _localAddresses[city]!) {
            if (_matchesQuery(addressData['address'], queryLower)) {
              results.add(_createPlacemarkFromLocalData(addressData));
            }
          }
        }
      }
      
      // If no city match, search all addresses
      if (results.isEmpty) {
        for (final city in _localAddresses.keys) {
          for (final addressData in _localAddresses[city]!) {
            if (_matchesQuery(addressData['address'], queryLower)) {
              results.add(_createPlacemarkFromLocalData(addressData));
            }
          }
        }
      }
      
      // Limit results to 5
      results = results.take(5).toList();
      
      print('🔍 Local search found ${results.length} results');
      return results;
    } catch (e) {
      print('🔍 Local database search failed: $e');
      return [];
    }
  }

  // Check if address matches query
  bool _matchesQuery(String address, String query) {
    final addressLower = address.toLowerCase();
    final queryWords = query.split(' ').where((word) => word.length > 2).toList();
    
    if (queryWords.isEmpty) return addressLower.contains(query);
    
    // Check if all query words are in the address
    return queryWords.every((word) => addressLower.contains(word));
  }

  // Create placemark from local data with real coordinates
  Placemark _createPlacemarkFromLocalData(Map<String, dynamic> addressData) {
    return Placemark(
      name: addressData['street'],
      street: addressData['street'],
      locality: addressData['locality'],
      administrativeArea: addressData['province'],
      country: 'South Africa',
      postalCode: '',
      isoCountryCode: 'ZA',
    );
  }

  // Create a fallback placemark when all else fails
  Placemark _createFallbackPlacemark(String query) {
    return Placemark(
      name: query,
      street: query,
      locality: 'Unknown',
      administrativeArea: 'Unknown',
      country: 'South Africa',
      postalCode: '',
      isoCountryCode: 'ZA',
    );
  }

  // Format address for display
  String formatAddress(Placemark placemark) {
    final parts = <String>[];
    
    if (placemark.street?.isNotEmpty == true) {
      parts.add(placemark.street!);
    }
    if (placemark.subLocality?.isNotEmpty == true) {
      parts.add(placemark.subLocality!);
    }
    if (placemark.locality?.isNotEmpty == true) {
      parts.add(placemark.locality!);
    }
    if (placemark.administrativeArea?.isNotEmpty == true) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.postalCode?.isNotEmpty == true) {
      parts.add(placemark.postalCode!);
    }
    
    return parts.join(', ');
  }

  // Get coordinates for delivery fee calculation
  Map<String, double>? getCoordinatesForAddress(String address) {
    for (final city in _localAddresses.keys) {
      for (final addressData in _localAddresses[city]!) {
        if (addressData['address'].toLowerCase().contains(address.toLowerCase()) ||
            address.toLowerCase().contains(addressData['street'].toLowerCase())) {
          return {
            'latitude': addressData['lat'],
            'longitude': addressData['lng'],
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