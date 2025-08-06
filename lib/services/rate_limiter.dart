import 'dart:async';

/// Rate limiting service to prevent abuse and improve security
class RateLimiter {
  static final Map<String, DateTime> _lastRequests = {};
  static final Map<String, int> _requestCounts = {};
  static final Map<String, Timer> _resetTimers = {};
  
  // Default rate limits
  static const Duration _defaultCooldown = Duration(seconds: 1);
  static const Duration _defaultWindow = Duration(minutes: 1);
  static const int _defaultMaxRequests = 60; // 60 requests per minute
  
  /// Check if a user can make a request
  static bool canMakeRequest(String userId, {
    Duration cooldown = _defaultCooldown,
    Duration window = _defaultWindow,
    int maxRequests = _defaultMaxRequests,
  }) {
    final now = DateTime.now();
    final lastRequest = _lastRequests[userId];
    
    // Check cooldown (minimum time between requests)
    if (lastRequest != null) {
      if (now.difference(lastRequest) < cooldown) {
        return false;
      }
    }
    
    // Check rate limit window
    final windowStart = now.subtract(window);
    final requestCount = _requestCounts[userId] ?? 0;
    
    if (requestCount >= maxRequests) {
      return false;
    }
    
    // Update tracking
    _lastRequests[userId] = now;
    _requestCounts[userId] = (requestCount + 1);
    
    // Set up timer to reset count after window
    _resetTimers[userId]?.cancel();
    _resetTimers[userId] = Timer(window, () {
      _requestCounts[userId] = 0;
      _resetTimers.remove(userId);
    });
    
    return true;
  }
  
  /// Check if a specific action is allowed (e.g., login attempts)
  static bool canPerformAction(String userId, String action, {
    Duration cooldown = const Duration(seconds: 5),
    Duration window = const Duration(minutes: 15),
    int maxAttempts = 5,
  }) {
    final key = '${userId}_$action';
    return canMakeRequest(key, cooldown: cooldown, window: window, maxRequests: maxAttempts);
  }
  
  /// Check if file upload is allowed
  static bool canUploadFile(String userId, {
    Duration cooldown = const Duration(seconds: 2),
    Duration window = const Duration(minutes: 5),
    int maxUploads = 10,
  }) {
    return canMakeRequest('${userId}_upload', cooldown: cooldown, window: window, maxRequests: maxUploads);
  }
  
  /// Check if message sending is allowed (for chat)
  static bool canSendMessage(String userId, String chatId, {
    Duration cooldown = const Duration(seconds: 1),
    Duration window = const Duration(minutes: 1),
    int maxMessages = 30,
  }) {
    return canMakeRequest('${userId}_${chatId}_message', cooldown: cooldown, window: window, maxRequests: maxMessages);
  }
  
  /// Check if search is allowed
  static bool canSearch(String userId, {
    Duration cooldown = const Duration(seconds: 1),
    Duration window = const Duration(minutes: 1),
    int maxSearches = 20,
  }) {
    return canMakeRequest('${userId}_search', cooldown: cooldown, window: window, maxRequests: maxSearches);
  }
  
  /// Get remaining requests for a user
  static int getRemainingRequests(String userId, {
    Duration window = _defaultWindow,
    int maxRequests = _defaultMaxRequests,
  }) {
    final requestCount = _requestCounts[userId] ?? 0;
    return maxRequests - requestCount;
  }
  
  /// Get time until next request is allowed
  static Duration? getTimeUntilNextRequest(String userId, {
    Duration cooldown = _defaultCooldown,
  }) {
    final lastRequest = _lastRequests[userId];
    if (lastRequest == null) return null;
    
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(lastRequest);
    
    if (timeSinceLastRequest >= cooldown) {
      return null; // Can make request now
    }
    
    return cooldown - timeSinceLastRequest;
  }
  
  /// Clear rate limit data for a user (for admin purposes)
  static void clearUserData(String userId) {
    _lastRequests.remove(userId);
    _requestCounts.remove(userId);
    _resetTimers[userId]?.cancel();
    _resetTimers.remove(userId);
  }
  
  /// Clear all rate limit data (for testing or admin purposes)
  static void clearAllData() {
    _lastRequests.clear();
    _requestCounts.clear();
    for (final timer in _resetTimers.values) {
      timer.cancel();
    }
    _resetTimers.clear();
  }
  
  /// Get current rate limit statistics
  static Map<String, dynamic> getStatistics() {
    return {
      'activeUsers': _lastRequests.length,
      'totalRequests': _requestCounts.values.fold<int>(0, (sum, count) => sum + count),
      'activeTimers': _resetTimers.length,
    };
  }
} 