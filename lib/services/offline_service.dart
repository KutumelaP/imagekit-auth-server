import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';

class OfflineService {
  static const String _storesKey = 'cached_stores';
  static const String _reviewsKey = 'cached_reviews';
  static const String _userDataKey = 'cached_user_data';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // Check if device is online
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Cache stores data
  static Future<void> cacheStores(List<Map<String, dynamic>> stores) async {
    final prefs = await SharedPreferences.getInstance();
    final storesJson = stores.map((store) => jsonEncode(store)).toList();
    await prefs.setStringList(_storesKey, storesJson);
    await _updateLastSync();
  }

  // Get cached stores
  static Future<List<Map<String, dynamic>>> getCachedStores() async {
    final prefs = await SharedPreferences.getInstance();
    final storesJson = prefs.getStringList(_storesKey) ?? [];
    
    return storesJson.map((storeJson) {
      return Map<String, dynamic>.from(jsonDecode(storeJson));
    }).toList();
  }

  // Cache reviews data
  static Future<void> cacheReviews(String storeId, List<Map<String, dynamic>> reviews) async {
    final prefs = await SharedPreferences.getInstance();
    final reviewsJson = reviews.map((review) => jsonEncode(review)).toList();
    await prefs.setStringList('${_reviewsKey}_$storeId', reviewsJson);
  }

  // Get cached reviews
  static Future<List<Map<String, dynamic>>> getCachedReviews(String storeId) async {
    final prefs = await SharedPreferences.getInstance();
    final reviewsJson = prefs.getStringList('${_reviewsKey}_$storeId') ?? [];
    
    return reviewsJson.map((reviewJson) {
      return Map<String, dynamic>.from(jsonDecode(reviewJson));
    }).toList();
  }

  // Cache user data
  static Future<void> cacheUserData(String userId, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_userDataKey}_$userId', jsonEncode(userData));
  }

  // Get cached user data
  static Future<Map<String, dynamic>?> getCachedUserData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final userDataJson = prefs.getString('${_userDataKey}_$userId');
    
    if (userDataJson != null) {
      return Map<String, dynamic>.from(jsonDecode(userDataJson));
    }
    return null;
  }

  // Update last sync timestamp
  static Future<void> _updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Get last sync timestamp
  static Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  // Check if cache is stale (older than 1 hour)
  static Future<bool> isCacheStale() async {
    final lastSync = await getLastSync();
    if (lastSync == null) return true;
    
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    return difference.inHours >= 1;
  }

  // Clear all cached data
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Get cache size info
  static Future<Map<String, int>> getCacheInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    int totalSize = 0;
    Map<String, int> keySizes = {};
    
    for (String key in keys) {
      final value = prefs.get(key);
      if (value != null) {
        final size = value.toString().length;
        keySizes[key] = size;
        totalSize += size;
      }
    }
    
    return {
      'total_size': totalSize,
      'key_count': keys.length,
      ...keySizes,
    };
  }
} 