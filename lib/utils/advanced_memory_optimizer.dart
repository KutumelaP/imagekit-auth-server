import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Advanced pagination with memory management
class OptimizedPagination<T> {
  final List<T> _items = [];
  final int _pageSize;
  final int _maxCachedPages;
  int _currentPage = 0;
  bool _hasMore = true;
  
  OptimizedPagination({
    int pageSize = 15, // Smaller page size
    int maxCachedPages = 3, // Only keep 3 pages in memory
  }) : _pageSize = pageSize, _maxCachedPages = maxCachedPages;

  void addItems(List<T> newItems) {
    _items.addAll(newItems);
    
    // Remove old pages if we exceed max cached pages
    if (_items.length > _pageSize * _maxCachedPages) {
      final itemsToRemove = _items.length - (_pageSize * _maxCachedPages);
      _items.removeRange(0, itemsToRemove);
    }
  }

  List<T> getCurrentPage() {
    final start = _currentPage * _pageSize;
    final end = start + _pageSize;
    return _items.sublist(start, end.clamp(0, _items.length));
  }

  List<T> getAllItems() {
    return List.from(_items);
  }

  void nextPage() {
    if (_hasMore) {
      _currentPage++;
    }
  }

  void clear() {
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
  }
}

/// Optimized Firestore queries with memory management
class OptimizedFirestoreQuery {
  static Future<List<DocumentSnapshot>> getOptimizedQuery({
    required String collection,
    String? whereField,
    dynamic whereValue,
    int limit = 15, // Smaller limit
    String? orderBy,
    bool descending = true,
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection(collection);
      
      if (whereField != null && whereValue != null) {
        query = query.where(whereField, isEqualTo: whereValue);
      }
      
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      
      query = query.limit(limit);
      
      final snapshot = await query.get();
      return snapshot.docs;
    } catch (e) {
      print('❌ Optimized query failed: $e');
      return [];
    }
  }
}

/// Smart cache with automatic cleanup
class SmartCache {
  static final Map<String, dynamic> _dataCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 3); // Shorter expiry
  static bool _isLowMemoryMode = false;

  static T? get<T>(String key) {
    final data = _dataCache[key];
    final timestamp = _cacheTimestamps[key];
    
    if (data != null && timestamp != null) {
      if (DateTime.now().difference(timestamp) < _cacheExpiry) {
        return data as T;
      } else {
        // Remove expired cache
        _dataCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
    return null;
  }

  static void set<T>(String key, T data) {
    // Check memory pressure before caching
    if (_isLowMemoryMode) {
      _clearOldestCache();
    }
    
    _dataCache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  static void clear() {
    _dataCache.clear();
    _cacheTimestamps.clear();
  }

  static void _clearOldestCache() {
    if (_cacheTimestamps.isEmpty) return;
    
    // Find oldest cache entry
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _cacheTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime!)) {
        oldestKey = entry.key;
        oldestTime = entry.value;
      }
    }
    
    // Remove oldest entry
    if (oldestKey != null) {
      _dataCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }

  static int getCacheSize() {
    return _dataCache.length;
  }

  static void setLowMemoryMode(bool enabled) {
    _isLowMemoryMode = enabled;
  }
}

/// Optimized stream management
class StreamManager {
  static final Map<String, StreamSubscription> _activeStreams = {};

  static void addStream(String key, StreamSubscription subscription) {
    // Remove existing stream if any
    removeStream(key);
    
    _activeStreams[key] = subscription;
  }

  static void removeStream(String key) {
    _activeStreams[key]?.cancel();
    _activeStreams.remove(key);
  }

  static void removeAllStreams() {
    for (final subscription in _activeStreams.values) {
      subscription.cancel();
    }
    _activeStreams.clear();
  }

  static int getActiveStreamCount() {
    return _activeStreams.length;
  }

  static List<String> getActiveStreamKeys() {
    return _activeStreams.keys.toList();
  }
}

/// Debounced operations to reduce memory pressure
class DebouncedOperation {
  static final Map<String, Timer> _debounceTimers = {};

  static void debounce(String key, VoidCallback operation, {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, operation);
  }

  static void cancelDebounce(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
  }

  static void cancelAllDebounces() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  static int getActiveDebounceCount() {
    return _debounceTimers.length;
  }
}

class AdvancedMemoryOptimizer {
  // Memory pressure detection
  static bool _isLowMemoryMode = false;
  static Timer? _memoryMonitorTimer;

  /// Initialize advanced memory optimization
  static void initialize() {
    _startMemoryMonitoring();
    _initializeLowMemoryDetection();
    print('🧠 Advanced memory optimization initialized');
  }

  /// Memory-efficient widget builder
  static Widget buildOptimizedList<T>({
    required List<T> items,
    required Widget Function(BuildContext, T, int) itemBuilder,
    ScrollController? controller,
    bool addRepaintBoundaries = true,
    bool addAutomaticKeepAlives = false, // Disable for better memory
  }) {
    return ListView.builder(
      controller: controller,
      itemCount: items.length,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      itemBuilder: (context, index) {
        final item = items[index];
        Widget widget = itemBuilder(context, item, index);
        
        // Wrap with RepaintBoundary for better performance
        if (addRepaintBoundaries) {
          widget = RepaintBoundary(child: widget);
        }
        
        return widget;
      },
    );
  }

  /// Memory pressure detection and response
  static void _initializeLowMemoryDetection() {
    // Monitor memory usage every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkMemoryPressure();
    });
  }

  static void _checkMemoryPressure() {
    final cache = PaintingBinding.instance.imageCache;
    final usagePercent = (cache.currentSize / cache.maximumSize * 100).round();
    
    if (usagePercent > 70 && !_isLowMemoryMode) {
      _enableLowMemoryMode();
    } else if (usagePercent < 50 && _isLowMemoryMode) {
      _disableLowMemoryMode();
    }
  }

  static void _enableLowMemoryMode() {
    _isLowMemoryMode = true;
    print('🚨 Low memory mode enabled');
    
    // Reduce cache sizes
    PaintingBinding.instance.imageCache.maximumSize = 200;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 25 << 20; // 25MB
    
    // Clear old caches
    SmartCache.clear();
    SmartCache.setLowMemoryMode(true);
    
    // Cancel non-essential streams
    _removeNonEssentialStreams();
  }

  static void _disableLowMemoryMode() {
    _isLowMemoryMode = false;
    print('✅ Low memory mode disabled');
    
    // Restore normal cache sizes
    PaintingBinding.instance.imageCache.maximumSize = 500;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB
    SmartCache.setLowMemoryMode(false);
  }

  static void _removeNonEssentialStreams() {
    // Keep only essential streams (like user data, current orders)
    final essentialKeys = ['user_data', 'current_orders'];
    
    final keysToRemove = <String>[];
    for (final key in StreamManager.getActiveStreamKeys()) {
      if (!essentialKeys.contains(key)) {
        keysToRemove.add(key);
      }
    }
    
    for (final key in keysToRemove) {
      StreamManager.removeStream(key);
    }
  }

  /// Start memory monitoring
  static void _startMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    
    _memoryMonitorTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _logMemoryStats();
    });
  }

  static void _logMemoryStats() {
    final cache = PaintingBinding.instance.imageCache;
    final streamCount = StreamManager.getActiveStreamCount();
    final cacheSize = SmartCache.getCacheSize();
    
    print('📊 Advanced Memory Stats:');
    print('   Image Cache: ${cache.currentSize}/${cache.maximumSize} images');
    print('   Active Streams: $streamCount');
    print('   Data Cache Entries: $cacheSize');
    print('   Low Memory Mode: $_isLowMemoryMode');
  }

  /// Get comprehensive memory statistics
  static Map<String, dynamic> getComprehensiveStats() {
    final cache = PaintingBinding.instance.imageCache;
    return {
      'imageCache': {
        'currentSize': cache.currentSize,
        'maximumSize': cache.maximumSize,
        'usagePercent': (cache.currentSize / cache.maximumSize * 100).round(),
      },
      'streams': {
        'activeCount': StreamManager.getActiveStreamCount(),
        'activeKeys': StreamManager.getActiveStreamKeys(),
      },
      'dataCache': {
        'entries': SmartCache.getCacheSize(),
      },
      'system': {
        'lowMemoryMode': _isLowMemoryMode,
        'debounceTimers': DebouncedOperation.getActiveDebounceCount(),
      },
    };
  }

  /// Emergency cleanup for critical memory situations
  static void emergencyCleanup() {
    print('🚨 Emergency cleanup triggered');
    
    // Clear all caches
    SmartCache.clear();
    
    // Cancel all streams
    StreamManager.removeAllStreams();
    
    // Cancel all debounce timers
    DebouncedOperation.cancelAllDebounces();
    
    // Clear image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Enable low memory mode
    _enableLowMemoryMode();
    
    print('🚨 Emergency cleanup completed');
  }

  /// Dispose all resources
  static void dispose() {
    _memoryMonitorTimer?.cancel();
    StreamManager.removeAllStreams();
    DebouncedOperation.cancelAllDebounces();
    SmartCache.clear();
    print('🧠 Advanced memory optimizer disposed');
  }
} 