import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

class PerformanceConfig {
  static void initialize() {
    if (!kDebugMode) {
      // Production optimizations
      
      // Reduce image cache for better memory management
      PaintingBinding.instance.imageCache.maximumSize = 150;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 20 << 20; // 20MB
      
      // Optimize platform channel performance
      SystemChannels.platform.setMessageHandler(null);
      
      // Disable unnecessary debug checks in production
      if (kReleaseMode) {
        // Additional release-mode optimizations
        PaintingBinding.instance.imageCache.maximumSizeBytes = 15 << 20; // 15MB for release
      }
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
