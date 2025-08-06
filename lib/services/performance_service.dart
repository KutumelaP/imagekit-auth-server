import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Memory cache for Firestore data
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Debouncing for search operations
  Timer? _debounceTimer;
  
  // Pagination cache
  final Map<String, List<DocumentSnapshot>> _paginationCache = {};
  final Map<String, DocumentSnapshot?> _lastDocuments = {};

  /// Cache Firestore data with expiry
  void cacheData(String key, dynamic data) {
    _memoryCache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
    
    // Cleanup old cache entries
    _cleanupExpiredCache();
  }

  /// Get cached data if not expired
  T? getCachedData<T>(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null || DateTime.now().difference(timestamp) > _cacheExpiry) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    return _memoryCache[key] as T?;
  }

  /// Clear specific cache entry
  void clearCache(String key) {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
  }

  /// Clear all cache
  void clearAllCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _paginationCache.clear();
    _lastDocuments.clear();
  }

  /// Cleanup expired cache entries
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Debounced search function
  void debounceSearch(String query, Function(String) onSearch, {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () => onSearch(query));
  }

  /// Cache pagination results
  void cachePaginationData(String key, List<DocumentSnapshot> docs, DocumentSnapshot? lastDoc) {
    _paginationCache[key] = docs;
    _lastDocuments[key] = lastDoc;
  }

  /// Get cached pagination data
  Map<String, dynamic> getCachedPaginationData(String key) {
    return {
      'docs': _paginationCache[key],
      'lastDoc': _lastDocuments[key],
    };
  }

  /// Preload critical data for better performance
  Future<void> preloadCriticalData() async {
    try {
      // Preload categories
      if (getCachedData<List<Map<String, dynamic>>>('categories') == null) {
        final categoriesSnapshot = await FirebaseFirestore.instance
            .collection('categories')
            .limit(20)
            .get();
        
        final categories = categoriesSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        
        cacheData('categories', categories);
      }

      // Preload featured products
      if (getCachedData<List<Map<String, dynamic>>>('featured_products') == null) {
        final productsSnapshot = await FirebaseFirestore.instance
            .collection('products')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();
        
        final products = productsSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        
        cacheData('featured_products', products);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading data: $e');
      }
    }
  }

  /// Reduce widget rebuilds by providing optimized state management
  StreamController<String>? _searchController;
  
  Stream<String> get searchStream {
    _searchController ??= StreamController<String>.broadcast();
    return _searchController!.stream.distinct().where((query) => query.length >= 2);
  }

  void updateSearch(String query) {
    debounceSearch(query, (debouncedQuery) {
      _searchController?.add(debouncedQuery);
    });
  }

  /// Memory usage optimization
  void optimizeMemoryUsage() {
    // Clear image cache periodically
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Force garbage collection in debug mode
    if (kDebugMode) {
      // Only available in debug mode
    }
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _searchController?.close();
    clearAllCache();
  }
}

/// Performance monitoring utilities
class PerformanceMonitor {
  static final Map<String, Stopwatch> _stopwatches = {};

  /// Start performance measurement
  static void startMeasurement(String key) {
    _stopwatches[key] = Stopwatch()..start();
  }

  /// End performance measurement and log result
  static void endMeasurement(String key) {
    final stopwatch = _stopwatches[key];
    if (stopwatch != null) {
      stopwatch.stop();
      if (kDebugMode) {
        print('Performance [$key]: ${stopwatch.elapsedMilliseconds}ms');
      }
      _stopwatches.remove(key);
    }
  }

  /// Measure async function performance
  static Future<T> measureAsync<T>(String key, Future<T> Function() function) async {
    startMeasurement(key);
    try {
      final result = await function();
      endMeasurement(key);
      return result;
    } catch (e) {
      endMeasurement(key);
      rethrow;
    }
  }
}

/// Widget performance utilities
class PerformanceUtils {
  /// Wrap expensive widgets with RepaintBoundary
  static Widget withRepaintBoundary(Widget child, {String? debugLabel}) {
    return RepaintBoundary(
      child: child,
    );
  }

  /// Create optimized ListView with better performance
  static Widget optimizedListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
    double? itemExtent,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
  }) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      itemExtent: itemExtent,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      cacheExtent: 250.0, // Improve scrolling performance
      itemBuilder: (context, index) {
        Widget item = itemBuilder(context, index);
        
        // Wrap with RepaintBoundary for better performance
        if (addRepaintBoundaries) {
          item = RepaintBoundary(child: item);
        }
        
        return item;
      },
    );
  }

  /// Create optimized GridView
  static Widget optimizedGridView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required SliverGridDelegate gridDelegate,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
  }) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      cacheExtent: 250.0,
      itemBuilder: (context, index) {
        Widget item = itemBuilder(context, index);
        
        if (addRepaintBoundaries) {
          item = RepaintBoundary(child: item);
        }
        
        return item;
      },
    );
  }
} 