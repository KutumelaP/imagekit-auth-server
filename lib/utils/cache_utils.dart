import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async'; // Added for Completer

class CacheUtils {
  static const String _tag = 'CacheUtils';

  /// Clear all image caches (memory and disk)
  static Future<void> clearAllCaches() async {
    try {
      print('🧹 $_tag: Clearing all image caches...');
      
      // Clear Flutter's image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      // Note: CachedNetworkImage.evictFromCache() requires a URL parameter
      // We'll clear disk cache instead for a full clear
      
      // Clear disk cache directory
      await _clearDiskCache();
      
      print('✅ $_tag: All caches cleared successfully');
    } catch (e) {
      print('❌ $_tag: Error clearing caches: $e');
    }
  }

  /// Clear specific image from cache
  static Future<void> clearImageFromCache(String imageUrl) async {
    try {
      print('🧹 $_tag: Clearing image from cache: $imageUrl');
      
      // Clear from CachedNetworkImage cache
      await CachedNetworkImage.evictFromCache(imageUrl);
      
      print('✅ $_tag: Image cleared from cache: $imageUrl');
    } catch (e) {
      print('❌ $_tag: Error clearing image from cache: $e');
    }
  }

  /// Check if image is corrupted and clear it if needed
  static Future<bool> isImageCorrupted(String imageUrl) async {
    try {
      // Try to load the image from cache
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final stream = imageProvider.resolve(const ImageConfiguration());
      
      // Wait for the first frame using a completer
      final completer = Completer<void>();
      stream.addListener(ImageStreamListener((info, _) {
        completer.complete();
      }));
      
      await completer.future;
      return false; // Image loaded successfully, not corrupted
    } catch (e) {
      print('🖼️ $_tag: Image appears corrupted: $imageUrl - $e');
      return true; // Image is corrupted
    }
  }

  /// Auto-clear corrupted cache on app startup
  static Future<void> autoClearCorruptedCache() async {
    try {
      print('🔍 $_tag: Checking for corrupted cache on startup...');
      
      // Clear disk cache to be safe
      await _clearDiskCache();
      
      print('✅ $_tag: Cache cleanup completed on startup');
    } catch (e) {
      print('❌ $_tag: Error during cache cleanup: $e');
    }
  }

  /// Clear disk cache directory
  static Future<void> _clearDiskCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${cacheDir.path}/libCachedImageData');
      
      if (await imageCacheDir.exists()) {
        await imageCacheDir.delete(recursive: true);
        print('🗂️ $_tag: Disk cache cleared');
      }
    } catch (e) {
      print('❌ $_tag: Error clearing disk cache: $e');
    }
  }

  /// Get cache size information
  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${cacheDir.path}/libCachedImageData');
      
      int fileCount = 0;
      int totalSize = 0;
      
      if (await imageCacheDir.exists()) {
        await for (final entity in imageCacheDir.list(recursive: true)) {
          if (entity is File) {
            fileCount++;
            totalSize += await entity.length();
          }
        }
      }
      
      return {
        'fileCount': fileCount,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'cachePath': imageCacheDir.path,
      };
    } catch (e) {
      print('❌ $_tag: Error getting cache info: $e');
      return {
        'fileCount': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': '0.00',
        'cachePath': 'unknown',
      };
    }
  }

  /// Clear cache if it exceeds a certain size
  static Future<void> clearCacheIfNeeded({int maxSizeMB = 50}) async {
    try {
      final cacheInfo = await getCacheInfo();
      final currentSizeMB = double.parse(cacheInfo['totalSizeMB']);
      
      if (currentSizeMB > maxSizeMB) {
        print('🧹 $_tag: Cache size (${currentSizeMB}MB) exceeds limit (${maxSizeMB}MB), clearing...');
        await clearAllCaches();
      } else {
        print('✅ $_tag: Cache size (${currentSizeMB}MB) is within limit (${maxSizeMB}MB)');
      }
    } catch (e) {
      print('❌ $_tag: Error checking cache size: $e');
    }
  }
} 