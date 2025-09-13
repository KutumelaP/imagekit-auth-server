import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProductionMonitoringService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _healthCheckTimer;
  static StreamSubscription? _connectivitySubscription;
  
  /// Initialize comprehensive app monitoring
  static Future<void> initialize() async {
    try {
      await _startHealthChecks();
      await _monitorConnectivity();
      await _monitorAppState();
      await _setupCrashReporting();
      
      print('🔍 Production monitoring initialized');
    } catch (e) {
      print('❌ Monitoring initialization failed: $e');
    }
  }
  
  /// Real-time health monitoring
  static Future<void> _startHealthChecks() async {
    _healthCheckTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      await _performHealthCheck();
    });
    
    // Initial health check
    await _performHealthCheck();
  }
  
  static Future<void> _performHealthCheck() async {
    try {
      final startTime = DateTime.now();
      
      // Test Firestore connectivity
      await _firestore.collection('health_check').doc('test').set({
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'healthy',
      });
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // Record health metrics
      await _firestore.collection('app_health').add({
        'type': 'health_check',
        'status': 'healthy',
        'responseTime': responseTime,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
      
      // Alert if response time is slow
      if (responseTime > 3000) {
        await _reportSlowResponse(responseTime);
      }
      
    } catch (e) {
      await _reportHealthIssue(e.toString());
    }
  }
  
  /// Network connectivity monitoring
  static Future<void> _monitorConnectivity() async {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      await _handleConnectivityChange(result);
    });
  }
  
  static Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    try {
      final isOnline = result != ConnectivityResult.none;
      
      await _firestore.collection('connectivity_events').add({
        'type': isOnline ? 'online' : 'offline',
        'connectionType': result.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
      
      if (!isOnline) {
        await _handleOfflineMode();
      } else {
        await _handleOnlineMode();
      }
    } catch (e) {
      print('Connectivity monitoring error: $e');
    }
  }
  
  static Future<void> _handleOfflineMode() async {
    // Cache critical data for offline use
    // Show offline indicator to user
    print('📱 App went offline - enabling offline mode');
  }
  
  static Future<void> _handleOnlineMode() async {
    // Sync cached data when back online
    // Hide offline indicator
    print('🌐 App back online - syncing data');
  }
  
  /// App state monitoring
  static Future<void> _monitorAppState() async {
    try {
      await _firestore.collection('app_sessions').add({
        'type': 'app_start',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'appVersion': '1.0.0', // Get from package info
      });
    } catch (e) {
      print('App state monitoring error: $e');
    }
  }
  
  /// Advanced crash reporting
  static Future<void> _setupCrashReporting() async {
    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) async {
      await _reportCrash(
        error: details.exception.toString(),
        stackTrace: details.stack.toString(),
        context: 'flutter_error',
      );
    };
    
    // Handle Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportCrash(
        error: error.toString(),
        stackTrace: stack.toString(),
        context: 'dart_error',
      );
      return true;
    };
  }
  
  static Future<void> _reportCrash({
    required String error,
    required String stackTrace,
    required String context,
  }) async {
    try {
      await _firestore.collection('crash_reports').add({
        'error': error,
        'stackTrace': stackTrace,
        'context': context,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'appVersion': '1.0.0',
        'severity': 'critical',
        'resolved': false,
      });
      
      // Send immediate alert for critical crashes
      await _sendCrashAlert(error, context);
    } catch (e) {
      print('Crash reporting failed: $e');
    }
  }
  
  /// Memory usage monitoring
  static Future<void> monitorMemoryUsage() async {
    try {
      // Get memory usage info (would use process_info package in production)
      final memoryUsage = 150.0; // Mock value in MB
      
      await _firestore.collection('performance_metrics').add({
        'type': 'memory_usage',
        'memoryMB': memoryUsage,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
      
      // Alert if memory usage is high
      if (memoryUsage > 200) {
        await _reportHighMemoryUsage(memoryUsage);
      }
    } catch (e) {
      print('Memory monitoring error: $e');
    }
  }
  
  /// API response time monitoring
  static Future<void> trackAPICall({
    required String endpoint,
    required int durationMs,
    required bool success,
    String? errorMessage,
  }) async {
    try {
      await _firestore.collection('api_monitoring').add({
        'endpoint': endpoint,
        'duration': durationMs,
        'success': success,
        'error': errorMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
      
      // Alert for slow API calls
      if (durationMs > 5000) {
        await _reportSlowAPI(endpoint, durationMs);
      }
      
      // Alert for failed API calls
      if (!success) {
        await _reportAPIFailure(endpoint, errorMessage ?? 'Unknown error');
      }
    } catch (e) {
      print('API monitoring error: $e');
    }
  }
  
  /// User experience monitoring
  static Future<void> trackUserFlow({
    required String flow, // 'checkout', 'registration', 'product_browse'
    required String step,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      await _firestore.collection('user_flow_tracking').add({
        'flow': flow,
        'step': step,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'sessionId': metadata['sessionId'] ?? 'unknown',
      });
    } catch (e) {
      print('User flow tracking error: $e');
    }
  }
  
  /// Business metrics monitoring
  static Future<void> trackBusinessMetric({
    required String metric, // 'order_completion_rate', 'cart_abandonment', etc.
    required double value,
    Map<String, dynamic>? context,
  }) async {
    try {
      await _firestore.collection('business_metrics').add({
        'metric': metric,
        'value': value,
        'context': context ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().substring(0, 10),
      });
      
      // Update real-time dashboard
      await _updateBusinessDashboard(metric, value);
    } catch (e) {
      print('Business metrics error: $e');
    }
  }
  
  /// Feature usage monitoring
  static Future<void> trackFeatureUsage({
    required String feature,
    required String action, // 'used', 'clicked', 'viewed'
    Map<String, dynamic>? properties,
  }) async {
    try {
      await _firestore.collection('feature_usage').add({
        'feature': feature,
        'action': action,
        'properties': properties ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      print('Feature usage tracking error: $e');
    }
  }
  
  // Alert and notification methods
  
  static Future<void> _reportSlowResponse(int responseTime) async {
    await _firestore.collection('performance_alerts').add({
      'type': 'slow_response',
      'responseTime': responseTime,
      'severity': 'medium',
      'timestamp': FieldValue.serverTimestamp(),
      'resolved': false,
    });
  }
  
  static Future<void> _reportHealthIssue(String error) async {
    await _firestore.collection('health_alerts').add({
      'type': 'health_check_failed',
      'error': error,
      'severity': 'high',
      'timestamp': FieldValue.serverTimestamp(),
      'resolved': false,
    });
  }
  
  static Future<void> _sendCrashAlert(String error, String context) async {
    await _firestore.collection('critical_alerts').add({
      'type': 'app_crash',
      'error': error,
      'context': context,
      'severity': 'critical',
      'timestamp': FieldValue.serverTimestamp(),
      'notified': false,
    });
  }
  
  static Future<void> _reportHighMemoryUsage(double memoryMB) async {
    await _firestore.collection('performance_alerts').add({
      'type': 'high_memory_usage',
      'memoryMB': memoryMB,
      'severity': 'medium',
      'timestamp': FieldValue.serverTimestamp(),
      'resolved': false,
    });
  }
  
  static Future<void> _reportSlowAPI(String endpoint, int duration) async {
    await _firestore.collection('api_alerts').add({
      'type': 'slow_api_call',
      'endpoint': endpoint,
      'duration': duration,
      'severity': 'medium',
      'timestamp': FieldValue.serverTimestamp(),
      'resolved': false,
    });
  }
  
  static Future<void> _reportAPIFailure(String endpoint, String error) async {
    await _firestore.collection('api_alerts').add({
      'type': 'api_failure',
      'endpoint': endpoint,
      'error': error,
      'severity': 'high',
      'timestamp': FieldValue.serverTimestamp(),
      'resolved': false,
    });
  }
  
  static Future<void> _updateBusinessDashboard(String metric, double value) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      await _firestore.collection('daily_business_metrics').doc(today).set({
        metric: value,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Dashboard update error: $e');
    }
  }
  
  /// Cleanup and disposal
  static void dispose() {
    _healthCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
