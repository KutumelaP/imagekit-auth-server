import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;

class CacheManagementService {
  static const String APP_VERSION = '1.0.0+3';
  static final CacheManagementService _instance = CacheManagementService._internal();
  factory CacheManagementService() => _instance;
  CacheManagementService._internal();

  static const String _lastVersionKey = 'last_app_version';
  static const String _forceClearKey = 'force_clear_cache';
  static const String _lastClearKey = 'last_cache_clear';
  
  String? _currentVersion;
  String? _currentBuildNumber;

  /// Initialize cache management service
  Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      _currentBuildNumber = packageInfo.buildNumber;
      
      print('🗂️ Cache Management: Current version $_currentVersion+$_currentBuildNumber');
      
      await _checkVersionChange();
      await _checkRemoteCacheClearFlag();
    } catch (e) {
      print('❌ Error initializing CacheManagementService: $e');
    }
  }

  /// Check if app version has changed and clear cache if needed
  Future<void> _checkVersionChange() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVersion = prefs.getString(_lastVersionKey);
      final currentFullVersion = '$_currentVersion+$_currentBuildNumber';
      
      if (lastVersion != currentFullVersion) {
        print('🔄 Version changed from $lastVersion to $currentFullVersion - clearing caches');
        
        await clearAllCaches();
        await prefs.setString(_lastVersionKey, currentFullVersion);
        
        // For web, also clear browser caches
        if (kIsWeb) {
          await _clearWebCaches();
        }
      }
    } catch (e) {
      print('❌ Error checking version change: $e');
    }
  }

  /// Check remote flag for forced cache clearing
  Future<void> _checkRemoteCacheClearFlag() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('cache_management')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final forceClear = data['force_clear_cache'] as bool? ?? false;
        final clearVersion = data['clear_version'] as String?;
        
        if (forceClear && clearVersion != null) {
          final prefs = await SharedPreferences.getInstance();
          final lastClearVersion = prefs.getString(_forceClearKey);
          
          if (lastClearVersion != clearVersion) {
            print('🚨 Remote cache clear triggered - version: $clearVersion');
            await clearAllCaches();
            await prefs.setString(_forceClearKey, clearVersion);
            
            if (kIsWeb) {
              await _clearWebCaches();
              _reloadWebPage();
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error checking remote cache clear flag: $e');
    }
  }

  /// Clear all application caches
  Future<void> clearAllCaches() async {
    try {
      print('🧹 Clearing all application caches...');
      
      // Clear SharedPreferences cache (keep essential data)
      final prefs = await SharedPreferences.getInstance();
      final essentialKeys = [_lastVersionKey, _forceClearKey, 'user_id', 'auth_token'];
      final allKeys = prefs.getKeys();
      
      for (final key in allKeys) {
        if (!essentialKeys.contains(key)) {
          await prefs.remove(key);
        }
      }
      
      // Clear image caches
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      // Clear performance service caches
      try {
        // Import dynamically if available
        final PerformanceService = await _tryImportPerformanceService();
        PerformanceService?.clearAllCache();
      } catch (_) {
        // Performance service not available, skip
      }
      
      // Record cache clear timestamp
      await prefs.setInt(_lastClearKey, DateTime.now().millisecondsSinceEpoch);
      
      print('✅ All caches cleared successfully');
    } catch (e) {
      print('❌ Error clearing caches: $e');
    }
  }

  /// Clear web-specific caches
  Future<void> _clearWebCaches() async {
    if (!kIsWeb) return;
    
    try {
      print('🌐 Clearing web browser caches...');
      
      // Clear service worker caches
      html.window.navigator.serviceWorker?.getRegistrations().then((registrations) {
        for (final registration in registrations) {
          registration.unregister();
        }
      });
      
      // Clear browser storage
      html.window.localStorage.clear();
      html.window.sessionStorage.clear();
      
      // Clear cached network requests
      if (html.window.caches != null) {
        html.window.caches!.keys().then((cacheNames) {
          for (final cacheName in cacheNames) {
            html.window.caches!.delete(cacheName);
          }
        });
      }
      
      print('✅ Web caches cleared successfully');
    } catch (e) {
      print('❌ Error clearing web caches: $e');
    }
  }

  /// Force reload web page
  void _reloadWebPage() {
    if (kIsWeb) {
      html.window.location.reload();
    }
  }

  /// Get cache-busting version string for URLs
  String getCacheBustingVersion() {
    return '$_currentVersion-$_currentBuildNumber';
  }

  /// Add cache-busting parameter to URL
  String addCacheBusting(String url) {
    final version = getCacheBustingVersion();
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$version';
  }

  /// Check if cache needs to be cleared based on age
  Future<bool> shouldClearCacheByAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastClear = prefs.getInt(_lastClearKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Clear cache if older than 7 days
      const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds
      return (now - lastClear) > maxAge;
    } catch (e) {
      return false;
    }
  }

  /// Periodic cache maintenance
  Future<void> performPeriodicMaintenance() async {
    try {
      if (await shouldClearCacheByAge()) {
        print('🧹 Performing periodic cache maintenance...');
        await clearAllCaches();
      }
      
      // Check for remote cache clear flags
      await _checkRemoteCacheClearFlag();
    } catch (e) {
      print('❌ Error during periodic maintenance: $e');
    }
  }

  /// Get cache status information
  Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVersion = prefs.getString(_lastVersionKey);
      final lastClear = prefs.getInt(_lastClearKey) ?? 0;
      final imageCache = PaintingBinding.instance.imageCache;
      
      return {
        'current_version': '$_currentVersion+$_currentBuildNumber',
        'last_version': lastVersion,
        'last_cache_clear': DateTime.fromMillisecondsSinceEpoch(lastClear).toIso8601String(),
        'image_cache_size': imageCache.currentSize,
        'image_cache_max': imageCache.maximumSize,
        'needs_clear_by_age': await shouldClearCacheByAge(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Try to import performance service dynamically
  Future<dynamic> _tryImportPerformanceService() async {
    try {
      // This will only work if performance_service.dart exists
      // For now, we'll just return null to avoid compilation errors
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Web-specific cache busting extensions
class WebCacheBuster {
  static const String _versionMetaTag = 'app-version';
  
  /// Update meta tag with current version
  static void updateVersionMetaTag(String version) {
    if (!kIsWeb) return;
    
    try {
      var metaTag = html.document.querySelector('meta[name="$_versionMetaTag"]');
      if (metaTag == null) {
        metaTag = html.MetaElement()
          ..name = _versionMetaTag
          ..content = version;
        html.document.head?.append(metaTag);
      } else {
        metaTag.setAttribute('content', version);
      }
    } catch (e) {
      print('❌ Error updating version meta tag: $e');
    }
  }
  
  /// Force service worker update
  static Future<void> forceServiceWorkerUpdate() async {
    if (!kIsWeb) return;
    
    try {
      final registration = await html.window.navigator.serviceWorker?.getRegistration();
      if (registration != null) {
        await registration.update();
        
        // If there's a waiting service worker, activate it immediately
        if (registration.waiting != null) {
          registration.waiting!.postMessage({'type': 'SKIP_WAITING'});
        }
      }
    } catch (e) {
      print('❌ Error forcing service worker update: $e');
    }
  }
}
