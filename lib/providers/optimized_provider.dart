import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/performance_service.dart';

/// Optimized provider that reduces unnecessary rebuilds and provides caching
class OptimizedDataProvider extends ChangeNotifier {
  final PerformanceService _performanceService = PerformanceService();
  
  // Categories cache
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = false;
  DateTime? _categoriesLastLoaded;
  
  // Products cache
  final Map<String, List<Map<String, dynamic>>> _productsByCategory = {};
  final Map<String, bool> _loadingStates = {};
  final Map<String, DateTime?> _lastLoadedTimes = {};
  
  // Cache expiry duration
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // Getters
  List<Map<String, dynamic>> get categories => _categories;
  bool get isLoadingCategories => _isLoadingCategories;
  
  /// Get products for a specific category with caching
  List<Map<String, dynamic>> getProductsForCategory(String category) {
    return _productsByCategory[category] ?? [];
  }
  
  /// Check if products are loading for a category
  bool isLoadingProductsForCategory(String category) {
    return _loadingStates[category] ?? false;
  }
  
  /// Load categories with caching and smart updates
  Future<void> loadCategories({bool forceRefresh = false}) async {
    // Check if we need to refresh
    if (!forceRefresh && 
        _categories.isNotEmpty && 
        _categoriesLastLoaded != null &&
        DateTime.now().difference(_categoriesLastLoaded!) < _cacheExpiry) {
      return; // Use cached data
    }
    
    // Check performance service cache first
    if (!forceRefresh) {
      final cachedCategories = _performanceService.getCachedData<List<Map<String, dynamic>>>('categories');
      if (cachedCategories != null) {
        _updateCategories(cachedCategories);
        return;
      }
    }
    
    if (_isLoadingCategories) return; // Prevent duplicate requests
    
    _isLoadingCategories = true;
    notifyListeners();
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .limit(20)
          .get();
      
      final categories = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      
      _updateCategories(categories);
      
      // Cache the data
      _performanceService.cacheData('categories', categories);
      _categoriesLastLoaded = DateTime.now();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error loading categories: $e');
      }
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }
  
  /// Load products for a category with pagination and caching
  Future<void> loadProductsForCategory(
    String category, {
    bool forceRefresh = false,
    bool loadMore = false,
  }) async {
    final cacheKey = 'products_$category';
    
    // Check if we need to refresh
    if (!forceRefresh && 
        !loadMore &&
        _productsByCategory[category]?.isNotEmpty == true &&
        _lastLoadedTimes[category] != null &&
        DateTime.now().difference(_lastLoadedTimes[category]!) < _cacheExpiry) {
      return; // Use cached data
    }
    
    // Check performance service cache first
    if (!forceRefresh && !loadMore) {
      final cachedProducts = _performanceService.getCachedData<List<Map<String, dynamic>>>(cacheKey);
      if (cachedProducts != null) {
        _updateProductsForCategory(category, cachedProducts);
        return;
      }
    }
    
    if (_loadingStates[category] == true) return; // Prevent duplicate requests
    
    _loadingStates[category] = true;
    notifyListeners();
    
    try {
      Query query = FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: category)
          .orderBy('timestamp', descending: true)
          .limit(20);
      
      final snapshot = await query.get();
      final products = <Map<String, dynamic>>[];
      
      // Process products efficiently
      final futures = snapshot.docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        final ownerId = data['ownerId'] ?? data['sellerId'];
        
        if (ownerId != null) {
          // Use cached seller data if available
          final sellerCacheKey = 'seller_$ownerId';
          Map<String, dynamic>? sellerData = _performanceService.getCachedData(sellerCacheKey);
          
          if (sellerData == null) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(ownerId)
                .get();
            
            if (userDoc.exists) {
              sellerData = userDoc.data() as Map<String, dynamic>;
              _performanceService.cacheData(sellerCacheKey, sellerData);
            }
          }
          
          if (sellerData?['paused'] != true) {
            return {
              'id': doc.id,
              ...data,
              'sellerName': sellerData?['name'] ?? sellerData?['storeName'] ?? 'Unknown Seller',
            };
          }
        }
        return null;
      });
      
      final results = await Future.wait(futures);
      products.addAll(results.where((product) => product != null).cast<Map<String, dynamic>>());
      
      if (loadMore) {
        _productsByCategory[category] = [
          ..._productsByCategory[category] ?? [],
          ...products,
        ];
      } else {
        _updateProductsForCategory(category, products);
      }
      
      // Cache the data
      _performanceService.cacheData(cacheKey, _productsByCategory[category] ?? []);
      _lastLoadedTimes[category] = DateTime.now();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error loading products for category $category: $e');
      }
    } finally {
      _loadingStates[category] = false;
      notifyListeners();
    }
  }
  
  /// Search products with debouncing and caching
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.length < 2) return [];
    
    final cacheKey = 'search_${query.toLowerCase()}';
    
    // Check cache first
    final cachedResults = _performanceService.getCachedData<List<Map<String, dynamic>>>(cacheKey);
    if (cachedResults != null) {
      return cachedResults;
    }
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + '\uf8ff')
          .limit(20)
          .get();
      
      final results = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
      
      // Cache search results for 2 minutes
      _performanceService.cacheData(cacheKey, results);
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        print('Error searching products: $e');
      }
      return [];
    }
  }
  
  /// Clear all cached data
  void clearCache() {
    _categories.clear();
    _productsByCategory.clear();
    _loadingStates.clear();
    _lastLoadedTimes.clear();
    _categoriesLastLoaded = null;
    _performanceService.clearAllCache();
    notifyListeners();
  }
  
  /// Optimize memory usage
  void optimizeMemory() {
    _performanceService.optimizeMemoryUsage();
    
    // Clear old cached data (keep only recent)
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _lastLoadedTimes.entries) {
      if (entry.value != null && now.difference(entry.value!) > const Duration(minutes: 10)) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _productsByCategory.remove(key);
      _loadingStates.remove(key);
      _lastLoadedTimes.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      notifyListeners();
    }
  }
  
  /// Update categories and notify listeners only if changed
  void _updateCategories(List<Map<String, dynamic>> newCategories) {
    if (!_categoriesChanged(newCategories)) return;
    
    _categories = newCategories;
    notifyListeners();
  }
  
  /// Update products for category and notify listeners only if changed
  void _updateProductsForCategory(String category, List<Map<String, dynamic>> products) {
    if (!_productsChanged(category, products)) return;
    
    _productsByCategory[category] = products;
    notifyListeners();
  }
  
  /// Check if categories have actually changed
  bool _categoriesChanged(List<Map<String, dynamic>> newCategories) {
    if (_categories.length != newCategories.length) return true;
    
    for (int i = 0; i < _categories.length; i++) {
      if (_categories[i]['id'] != newCategories[i]['id']) return true;
    }
    
    return false;
  }
  
  /// Check if products have actually changed
  bool _productsChanged(String category, List<Map<String, dynamic>> newProducts) {
    final currentProducts = _productsByCategory[category];
    if (currentProducts == null) return true;
    if (currentProducts.length != newProducts.length) return true;
    
    for (int i = 0; i < currentProducts.length; i++) {
      if (currentProducts[i]['id'] != newProducts[i]['id']) return true;
    }
    
    return false;
  }
  
  @override
  void dispose() {
    _performanceService.dispose();
    super.dispose();
  }
} 