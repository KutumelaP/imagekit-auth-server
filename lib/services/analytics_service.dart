import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Analytics service to track user behavior and app performance
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Track a custom event
  static Future<void> logEvent(String eventName, Map<String, dynamic> parameters) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters.cast<String, Object>(),
      );
      
      // Also log to Firestore for custom analytics
      await _logToFirestore(eventName, parameters);
      
      print('📊 Analytics: $eventName - $parameters');
    } catch (e) {
      print('❌ Analytics error: $e');
    }
  }
  
  /// Track user login
  static Future<void> logLogin(String method) async {
    await logEvent('user_login', {
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track user registration
  static Future<void> logRegistration(String method) async {
    await logEvent('user_registration', {
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track product view
  static Future<void> logProductView(String productId, String productName) async {
    await logEvent('product_view', {
      'product_id': productId,
      'product_name': productName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track product search
  static Future<void> logSearch(String query, int resultsCount) async {
    await logEvent('search', {
      'query': query,
      'results_count': resultsCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track add to cart
  static Future<void> logAddToCart(String productId, String productName, double price) async {
    await logEvent('add_to_cart', {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track purchase
  static Future<void> logPurchase(String orderId, double total, List<String> productIds) async {
    await logEvent('purchase', {
      'order_id': orderId,
      'total': total,
      'product_ids': productIds,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track chat message sent
  static Future<void> logChatMessage(String chatId, String messageType) async {
    await logEvent('chat_message_sent', {
      'chat_id': chatId,
      'message_type': messageType,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track chat initiated
  static Future<void> logChatInitiated(String sellerId, String productId) async {
    await logEvent('chat_initiated', {
      'seller_id': sellerId,
      'product_id': productId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track app performance
  static Future<void> logPerformance(String operation, int durationMs) async {
    await logEvent('performance', {
      'operation': operation,
      'duration_ms': durationMs,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track error
  static Future<void> logError(String errorType, String errorMessage, String? context) async {
    await logEvent('error', {
      'error_type': errorType,
      'error_message': errorMessage,
      'context': context ?? 'general',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track user engagement
  static Future<void> logEngagement(String action, String screen) async {
    await logEvent('engagement', {
      'action': action,
      'screen': screen,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track user session
  static Future<void> logSessionStart() async {
    await logEvent('session_start', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track user session end
  static Future<void> logSessionEnd(int durationSeconds) async {
    await logEvent('session_end', {
      'duration_seconds': durationSeconds,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track user profile update
  static Future<void> logProfileUpdate(String field) async {
    await logEvent('profile_update', {
      'field': field,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Track notification interaction
  static Future<void> logNotificationInteraction(String notificationType, String action) async {
    await logEvent('notification_interaction', {
      'notification_type': notificationType,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Log to Firestore for custom analytics
  static Future<void> _logToFirestore(String eventName, Map<String, dynamic> parameters) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'anonymous';
      
      await _firestore.collection('analytics').add({
        'event_name': eventName,
        'user_id': userId,
        'parameters': parameters,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Firestore analytics error: $e');
    }
  }
  
  /// Get user analytics from Firestore
  static Future<List<Map<String, dynamic>>> getUserAnalytics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('analytics')
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'event_name': data['event_name'],
          'parameters': data['parameters'],
          'timestamp': data['timestamp'],
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting user analytics: $e');
      return [];
    }
  }
  
  /// Get app-wide analytics summary
  static Future<Map<String, dynamic>> getAnalyticsSummary() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      
      // Get events from last 24 hours
      final snapshot = await _firestore
          .collection('analytics')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .get();
      
      final events = snapshot.docs;
      
      // Count events by type
      final eventCounts = <String, int>{};
      final userCounts = <String, int>{};
      
      for (final doc in events) {
        final data = doc.data();
        final eventName = data['event_name'] as String? ?? 'unknown';
        final userId = data['user_id'] as String? ?? 'anonymous';
        
        eventCounts[eventName] = (eventCounts[eventName] ?? 0) + 1;
        userCounts[userId] = (userCounts[userId] ?? 0) + 1;
      }
      
      return {
        'total_events': events.length,
        'unique_users': userCounts.length,
        'event_counts': eventCounts,
        'period': 'last_24_hours',
      };
    } catch (e) {
      print('❌ Error getting analytics summary: $e');
      return {
        'total_events': 0,
        'unique_users': 0,
        'event_counts': {},
        'period': 'last_24_hours',
      };
    }
  }
  
  /// Set user properties for Firebase Analytics
  static Future<void> setUserProperties({
    String? userRole,
    String? userType,
    String? location,
  }) async {
    try {
      if (userRole != null) {
        await _analytics.setUserProperty(name: 'user_role', value: userRole);
      }
      if (userType != null) {
        await _analytics.setUserProperty(name: 'user_type', value: userType);
      }
      if (location != null) {
        await _analytics.setUserProperty(name: 'location', value: location);
      }
    } catch (e) {
      print('❌ Error setting user properties: $e');
    }
  }
  
  /// Set current screen for analytics
  static Future<void> setCurrentScreen(String screenName) async {
    try {
      await _analytics.setCurrentScreen(screenName: screenName);
    } catch (e) {
      print('❌ Error setting current screen: $e');
    }
  }
} 