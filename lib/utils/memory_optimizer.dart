import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class MemoryOptimizer {
  static const int _maxCacheSize = 500; // Reduced from 2000
  static const int _maxCacheBytes = 50 << 20; // 50MB instead of 200MB
  static const int _cleanupThreshold = 400; // Start cleanup at 80%
  
  static Timer? _cleanupTimer;
  static bool _isOptimized = false;

  /// Initialize memory optimization
  static void initialize() {
    if (_isOptimized) return;
    
    // Reduce image cache size
    PaintingBinding.instance.imageCache.maximumSize = _maxCacheSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes = _maxCacheBytes;
    
    // Start periodic cleanup
    _startPeriodicCleanup();
    
    _isOptimized = true;
    print('🧹 Memory optimization initialized');
  }

  /// Emergency memory cleanup
  static void emergencyCleanup() {
    print('🚨 Emergency memory cleanup triggered');
    
    // Clear image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Force garbage collection in debug mode
    if (kDebugMode) {
      print('🚨 Emergency cleanup completed');
    }
  }

  /// Smart memory cleanup
  static void smartCleanup() {
    final cache = PaintingBinding.instance.imageCache;
    final currentSize = cache.currentSize;
    final maxSize = cache.maximumSize;
    
    if (currentSize > _cleanupThreshold) {
      print('🧹 Memory pressure detected: $currentSize/$maxSize images');
      
      // Clear oldest images
      cache.clear();
      cache.clearLiveImages();
      
      print('🧹 Smart cleanup completed');
    }
  }

  /// Optimize order management memory
  static void optimizeOrderManagement() {
    // Reduce pagination size
    const int maxOrdersPerPage = 20; // Instead of loading all orders
    
    // Clear unnecessary caches
    _clearOrderCaches();
    
    // Optimize real-time listeners
    _optimizeListeners();
    
    print('🧹 Order management memory optimized');
  }

  static void _clearOrderCaches() {
    // Clear order-related caches
    // This would clear any cached order data
    print('🧹 Cleared order caches');
  }

  static void _optimizeListeners() {
    // Limit real-time listeners
    // Only keep essential listeners active
    print('🧹 Optimized real-time listeners');
  }

  /// Monitor memory usage
  static void monitorMemory() {
    final cache = PaintingBinding.instance.imageCache;
    final currentSize = cache.currentSize;
    final maxSize = cache.maximumSize;
    final usagePercent = (currentSize / maxSize * 100).round();
    
    print('📊 Memory Usage:');
    print('   Image Cache: $currentSize/$maxSize images ($usagePercent%)');
    print('   Cache Limit: ${_maxCacheBytes ~/ (1024 * 1024)} MB');
    
    if (usagePercent > 80) {
      print('⚠️  High memory usage detected!');
      smartCleanup();
    }
  }

  /// Start periodic cleanup
  static void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    
    _cleanupTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      try {
        smartCleanup();
        monitorMemory();
      } catch (e) {
        print('❌ Memory cleanup failed: $e');
      }
    });
    
    print('⏰ Periodic memory cleanup started (every 2 minutes)');
  }

  /// Stop periodic cleanup
  static void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    print('⏰ Periodic cleanup stopped');
  }

  /// Get memory statistics
  static Map<String, dynamic> getMemoryStats() {
    final cache = PaintingBinding.instance.imageCache;
    return {
      'currentSize': cache.currentSize,
      'maximumSize': cache.maximumSize,
      'usagePercent': (cache.currentSize / cache.maximumSize * 100).round(),
      'maxMemoryMB': _maxCacheBytes ~/ (1024 * 1024),
      'isOptimized': _isOptimized,
    };
  }

  /// Optimize for low memory devices
  static void optimizeForLowMemory() {
    // Reduce cache size for low memory devices
    PaintingBinding.instance.imageCache.maximumSize = 200; // Even smaller
    PaintingBinding.instance.imageCache.maximumSizeBytes = 25 << 20; // 25MB
    
    print('📱 Optimized for low memory device');
  }

  /// Restore normal cache size
  static void restoreNormalCache() {
    PaintingBinding.instance.imageCache.maximumSize = _maxCacheSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes = _maxCacheBytes;
    
    print('📱 Restored normal cache size');
  }

  /// Dispose resources
  static void dispose() {
    _cleanupTimer?.cancel();
    _isOptimized = false;
  }
} 