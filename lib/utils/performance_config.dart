import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class PerformanceConfig {
  static void initialize() {
    if (!kDebugMode) {
      // Production optimizations
      
      // More aggressive image cache limits for low-end devices
      PaintingBinding.instance.imageCache.maximumSize = 100; // Reduced from 150
      PaintingBinding.instance.imageCache.maximumSizeBytes = 15 << 20; // 15MB instead of 20MB
      
      // Platform channel optimizations are handled automatically in newer Flutter versions
      
      // Disable unnecessary debug checks in production
      if (kReleaseMode) {
        // Even more aggressive optimizations for release mode on low-end devices
        PaintingBinding.instance.imageCache.maximumSizeBytes = 10 << 20; // 10MB for release
        PaintingBinding.instance.imageCache.maximumSize = 75; // Further reduced
      }
    } else {
      // Debug mode optimizations for development on low-end devices
      PaintingBinding.instance.imageCache.maximumSize = 50;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 8 << 20; // 8MB for debug
    }
  }
  
  static void optimizeForWeb() {
    if (kIsWeb) {
      // Web-specific optimizations
      PaintingBinding.instance.imageCache.maximumSize = 100;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 10 << 20; // 10MB for web
    }
  }
  
  static void clearCaches() {
    // Clear image cache when memory pressure is high
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
