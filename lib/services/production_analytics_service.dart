import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductionAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Real-time business intelligence and analytics
  static Future<void> trackCheckoutConversion({
    required String stage, // 'started', 'payment_selected', 'completed', 'abandoned'
    required Map<String, dynamic> context,
  }) async {
    try {
      await _firestore.collection('conversion_funnel').add({
        'stage': stage,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'sessionId': context['sessionId'] ?? 'unknown',
        'cartValue': context['cartValue'] ?? 0.0,
        'itemCount': context['itemCount'] ?? 0,
        'deliveryMethod': context['deliveryMethod'],
        'paymentMethod': context['paymentMethod'],
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': context,
      });
      
      // Real-time dashboard update
      await _updateRealtimeDashboard(stage, context);
    } catch (e) {
      print('Analytics error: $e');
    }
  }
  
  static Future<void> _updateRealtimeDashboard(String stage, Map<String, dynamic> context) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      await _firestore.collection('realtime_metrics').doc(today).set({
        'date': today,
        'checkoutStarts': stage == 'started' ? FieldValue.increment(1) : 0,
        'checkoutCompletions': stage == 'completed' ? FieldValue.increment(1) : 0,
        'checkoutAbandoned': stage == 'abandoned' ? FieldValue.increment(1) : 0,
        'totalRevenue': stage == 'completed' ? FieldValue.increment(context['cartValue'] ?? 0.0) : 0,
        'averageOrderValue': stage == 'completed' ? context['cartValue'] ?? 0.0 : 0,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Dashboard update error: $e');
    }
  }
  
  /// Track user behavior for optimization
  static Future<void> trackUserBehavior({
    required String action, // 'product_view', 'add_to_cart', 'checkout_start', etc.
    required Map<String, dynamic> properties,
  }) async {
    try {
      await _firestore.collection('user_behavior').add({
        'action': action,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'properties': properties,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'mobile_app',
      });
    } catch (e) {
      print('Behavior tracking error: $e');
    }
  }
  
  /// A/B Testing framework
  static Future<String> getExperimentVariant(String experimentName) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      
      // Check if user already assigned to variant
      final userExperiment = await _firestore
          .collection('user_experiments')
          .doc(userId)
          .collection('experiments')
          .doc(experimentName)
          .get();
      
      if (userExperiment.exists) {
        return userExperiment.data()!['variant'] as String;
      }
      
      // Get experiment configuration
      final experimentDoc = await _firestore
          .collection('experiments')
          .doc(experimentName)
          .get();
      
      if (!experimentDoc.exists) {
        return 'control'; // Default variant
      }
      
      final experimentData = experimentDoc.data()!;
      final variants = experimentData['variants'] as Map<String, dynamic>;
      final isActive = experimentData['isActive'] as bool? ?? false;
      
      if (!isActive) {
        return 'control';
      }
      
      // Assign variant based on user hash
      final userHash = userId.hashCode.abs();
      var cumulativeWeight = 0;
      final totalWeight = variants.values.fold<int>(0, (sum, weight) => sum + weight as int);
      final randomValue = userHash % totalWeight;
      
      String selectedVariant = 'control';
      for (final entry in variants.entries) {
        cumulativeWeight += entry.value as int;
        if (randomValue < cumulativeWeight) {
          selectedVariant = entry.key;
          break;
        }
      }
      
      // Store assignment
      await _firestore
          .collection('user_experiments')
          .doc(userId)
          .collection('experiments')
          .doc(experimentName)
          .set({
        'variant': selectedVariant,
        'assignedAt': FieldValue.serverTimestamp(),
        'experimentName': experimentName,
      });
      
      return selectedVariant;
    } catch (e) {
      print('A/B testing error: $e');
      return 'control';
    }
  }
  
  /// Performance monitoring
  static Future<void> trackPerformance({
    required String operation,
    required int durationMs,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('performance_metrics').add({
        'operation': operation,
        'duration': durationMs,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
        'platform': 'flutter_app',
      });
      
      // Alert if operation is slow
      if (durationMs > 5000) { // 5 seconds
        await _firestore.collection('performance_alerts').add({
          'operation': operation,
          'duration': durationMs,
          'severity': 'high',
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': metadata,
        });
      }
    } catch (e) {
      print('Performance tracking error: $e');
    }
  }
  
  /// Error monitoring and alerting
  static Future<void> trackError({
    required String error,
    required String stackTrace,
    required String context,
    String severity = 'medium',
  }) async {
    try {
      await _firestore.collection('error_tracking').add({
        'error': error,
        'stackTrace': stackTrace,
        'context': context,
        'severity': severity,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'flutter_app',
        'resolved': false,
      });
      
      // Send alert for critical errors
      if (severity == 'critical') {
        await _sendCriticalErrorAlert(error, context);
      }
    } catch (e) {
      print('Error tracking failed: $e');
    }
  }
  
  static Future<void> _sendCriticalErrorAlert(String error, String context) async {
    try {
      await _firestore.collection('alerts').add({
        'type': 'critical_error',
        'message': 'Critical error in production: $error',
        'context': context,
        'timestamp': FieldValue.serverTimestamp(),
        'notified': false,
      });
    } catch (e) {
      print('Alert sending failed: $e');
    }
  }
  
  /// Revenue tracking and optimization
  static Future<void> trackRevenue({
    required String orderId,
    required double amount,
    required String currency,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await _firestore.collection('revenue_tracking').add({
        'orderId': orderId,
        'amount': amount,
        'currency': currency,
        'items': items,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'mobile_app',
      });
      
      // Update daily revenue metrics
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await _firestore.collection('daily_revenue').doc(today).set({
        'date': today,
        'totalRevenue': FieldValue.increment(amount),
        'orderCount': FieldValue.increment(1),
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Revenue tracking error: $e');
    }
  }
  
  /// Customer lifetime value tracking
  static Future<void> updateCustomerLTV(String userId, double orderValue) async {
    try {
      await _firestore.collection('customer_ltv').doc(userId).set({
        'userId': userId,
        'totalSpent': FieldValue.increment(orderValue),
        'orderCount': FieldValue.increment(1),
        'lastOrderAt': FieldValue.serverTimestamp(),
        'averageOrderValue': orderValue, // Will be calculated properly in cloud function
      }, SetOptions(merge: true));
    } catch (e) {
      print('LTV tracking error: $e');
    }
  }
}
