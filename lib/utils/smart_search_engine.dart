import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class SmartSearchEngine {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search products with smart filtering
  static Future<List<Map<String, dynamic>>> searchProducts({
    required String query,
    String? category,
    String? subcategory,
    double? maxPrice,
    double? minPrice,
    double? maxDistance,
    Position? userLocation,
    List<String>? tags,
    bool? inStock,
    String? sortBy, // 'relevance', 'price_low', 'price_high', 'rating', 'distance'
  }) async {
    try {
      // Build query
      Query productsQuery = _firestore.collection('products');

      // Apply filters
      if (category != null) {
        productsQuery = productsQuery.where('category', isEqualTo: category);
      }
      if (subcategory != null) {
        productsQuery = productsQuery.where('subcategory', isEqualTo: subcategory);
      }
      if (inStock != null) {
        productsQuery = productsQuery.where('quantity', isGreaterThan: 0);
      }

      // Get products
      QuerySnapshot snapshot = await productsQuery.get();
      List<Map<String, dynamic>> products = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> product = doc.data() as Map<String, dynamic>;
        product['productId'] = doc.id;

        // Apply text search
        if (query.isNotEmpty) {
          String productName = (product['name'] ?? '').toString().toLowerCase();
          String description = (product['description'] ?? '').toString().toLowerCase();
          String searchQuery = query.toLowerCase();

          if (!productName.contains(searchQuery) && 
              !description.contains(searchQuery)) {
            continue;
          }
      }

        // Apply price filters
        double price = (product['price'] ?? 0.0).toDouble();
        if (minPrice != null && price < minPrice) continue;
        if (maxPrice != null && price > maxPrice) continue;

        // Apply tag filters
        if (tags != null && tags.isNotEmpty) {
          List<String> productTags = List<String>.from(product['tags'] ?? []);
          bool hasMatchingTag = tags.any((tag) => productTags.contains(tag));
          if (!hasMatchingTag) continue;
        }

        // Calculate distance if user location provided
        if (userLocation != null) {
          double? storeLat = product['storeLatitude'];
          double? storeLng = product['storeLongitude'];
          
          if (storeLat != null && storeLng != null) {
            double distance = Geolocator.distanceBetween(
              userLocation.latitude,
              userLocation.longitude,
              storeLat,
              storeLng,
            ) / 1000; // Convert to km
            
            product['distance'] = distance;
            
            // Apply distance filter
            if (maxDistance != null && distance > maxDistance) {
              continue;
            }
          }
        }

        products.add(product);
      }

      // Sort results
      products = _sortProducts(products, sortBy ?? 'relevance', query);

      return products;
    } catch (e) {
      print('Error in smart product search: $e');
      return [];
    }
  }

  /// Search stores with smart filtering
  static Future<List<Map<String, dynamic>>> searchStores({
    required String query,
    String? category,
    double? maxDistance,
    Position? userLocation,
    bool? deliveryAvailable,
    bool? verified,
    double? minRating,
    String? sortBy, // 'relevance', 'rating', 'distance', 'name'
  }) async {
    try {
      // Build query
      Query storesQuery = _firestore.collection('users')
          .where('role', isEqualTo: 'seller')
          .where('status', isEqualTo: 'approved');

      // Apply filters
      if (category != null) {
        storesQuery = storesQuery.where('storeCategory', isEqualTo: category);
      }
      if (deliveryAvailable != null) {
        storesQuery = storesQuery.where('deliveryAvailable', isEqualTo: deliveryAvailable);
      }
      if (verified != null) {
        storesQuery = storesQuery.where('verified', isEqualTo: verified);
      }

      // Get stores
      QuerySnapshot snapshot = await storesQuery.get();
      List<Map<String, dynamic>> stores = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> store = doc.data() as Map<String, dynamic>;
        store['storeId'] = doc.id;

        // Apply text search
        if (query.isNotEmpty) {
          String storeName = (store['storeName'] ?? '').toString().toLowerCase();
          String location = (store['location'] ?? '').toString().toLowerCase();
          String searchQuery = query.toLowerCase();

          if (!storeName.contains(searchQuery) && 
              !location.contains(searchQuery)) {
            continue;
          }
        }

        // Apply rating filter
        double rating = (store['avgRating'] ?? 0.0).toDouble();
        if (minRating != null && rating < minRating) continue;

        // Calculate distance if user location provided
        if (userLocation != null) {
          double? storeLat = store['latitude'];
          double? storeLng = store['longitude'];
          
          if (storeLat != null && storeLng != null) {
            double distance = Geolocator.distanceBetween(
              userLocation.latitude,
              userLocation.longitude,
              storeLat,
              storeLng,
            ) / 1000; // Convert to km
            
            store['distance'] = distance;
            
            // Apply distance filter
            if (maxDistance != null && distance > maxDistance) {
              continue;
            }
          }
        }

        stores.add(store);
      }

      // Sort results
      stores = _sortStores(stores, sortBy ?? 'relevance', query);

      return stores;
    } catch (e) {
      print('Error in smart store search: $e');
      return [];
    }
  }

  /// Get search suggestions based on query
  static Future<List<String>> getSearchSuggestions(String query) async {
    try {
      List<String> suggestions = [];
      
      if (query.length < 2) return suggestions;

      // Get popular search terms from recent searches
      QuerySnapshot recentSearches = await _firestore
          .collection('search_history')
          .where('query', isGreaterThanOrEqualTo: query)
          .where('query', isLessThan: query + '\uf8ff')
          .orderBy('query')
          .limit(5)
          .get();

      for (var doc in recentSearches.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String suggestion = data['query'] ?? '';
        if (suggestion.isNotEmpty) {
          suggestions.add(suggestion);
        }
      }

      // Add category suggestions
      List<String> categories = ['Food', 'Beverages', 'Desserts', 'Snacks'];
      for (String category in categories) {
        if (category.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(category);
        }
      }

      // Add common product names
      List<String> commonProducts = ['Pizza', 'Burger', 'Coffee', 'Cake', 'Bread'];
      for (String product in commonProducts) {
        if (product.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(product);
        }
      }

      return suggestions.take(10).toList();
    } catch (e) {
      print('Error getting search suggestions: $e');
      return [];
    }
  }

  /// Save search query to history
  static Future<void> saveSearchQuery(String query) async {
    try {
      await _firestore.collection('search_history').add({
        'query': query,
        'timestamp': FieldValue.serverTimestamp(),
        'count': 1,
      });
    } catch (e) {
      print('Error saving search query: $e');
    }
  }

  /// Get trending searches
  static Future<List<String>> getTrendingSearches() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('search_history')
          .orderBy('count', descending: true)
          .limit(10)
          .get();

      List<String> trending = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String query = data['query'] ?? '';
        if (query.isNotEmpty) {
          trending.add(query);
        }
      }

      return trending;
    } catch (e) {
      print('Error getting trending searches: $e');
      return [];
    }
  }

  /// Sort products based on criteria
  static List<Map<String, dynamic>> _sortProducts(
    List<Map<String, dynamic>> products,
    String sortBy,
    String query,
  ) {
    switch (sortBy) {
      case 'price_low':
        products.sort((a, b) => (a['price'] ?? 0.0).compareTo(b['price'] ?? 0.0));
        break;
      case 'price_high':
        products.sort((a, b) => (b['price'] ?? 0.0).compareTo(a['price'] ?? 0.0));
        break;
      case 'rating':
        products.sort((a, b) => (b['rating'] ?? 0.0).compareTo(a['rating'] ?? 0.0));
        break;
      case 'distance':
        products.sort((a, b) => (a['distance'] ?? double.infinity).compareTo(b['distance'] ?? double.infinity));
        break;
      case 'relevance':
      default:
        // Sort by relevance (query match in name first, then description)
        products.sort((a, b) {
          String nameA = (a['name'] ?? '').toString().toLowerCase();
          String nameB = (b['name'] ?? '').toString().toLowerCase();
          String queryLower = query.toLowerCase();
          
          bool aNameMatch = nameA.contains(queryLower);
          bool bNameMatch = nameB.contains(queryLower);
          
          if (aNameMatch && !bNameMatch) return -1;
          if (!aNameMatch && bNameMatch) return 1;
          
          // If both match in name or neither, sort by rating
          return (b['rating'] ?? 0.0).compareTo(a['rating'] ?? 0.0);
        });
        break;
    }

    return products;
  }

  /// Sort stores based on criteria
  static List<Map<String, dynamic>> _sortStores(
    List<Map<String, dynamic>> stores,
    String sortBy,
    String query,
  ) {
    switch (sortBy) {
      case 'rating':
        stores.sort((a, b) => (b['avgRating'] ?? 0.0).compareTo(a['avgRating'] ?? 0.0));
        break;
      case 'distance':
        stores.sort((a, b) => (a['distance'] ?? double.infinity).compareTo(b['distance'] ?? double.infinity));
        break;
      case 'name':
        stores.sort((a, b) => (a['storeName'] ?? '').compareTo(b['storeName'] ?? ''));
        break;
      case 'relevance':
      default:
        // Sort by relevance (query match in name first, then location)
        stores.sort((a, b) {
          String nameA = (a['storeName'] ?? '').toString().toLowerCase();
          String nameB = (b['storeName'] ?? '').toString().toLowerCase();
          String queryLower = query.toLowerCase();
          
          bool aNameMatch = nameA.contains(queryLower);
          bool bNameMatch = nameB.contains(queryLower);
          
          if (aNameMatch && !bNameMatch) return -1;
          if (!aNameMatch && bNameMatch) return 1;
          
          // If both match in name or neither, sort by rating
          return (b['avgRating'] ?? 0.0).compareTo(a['avgRating'] ?? 0.0);
        });
        break;
    }

    return stores;
  }
} 