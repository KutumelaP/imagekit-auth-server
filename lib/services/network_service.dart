import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'error_tracking_service.dart';

/// Lightweight network monitoring service
/// Designed to be crash-safe and performance-friendly
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  bool _isInitialized = false;
  bool _isConnected = true;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  /// Initialize network monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check initial connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      _isConnected = connectivityResult != ConnectivityResult.none;

      // Listen for connectivity changes
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen((ConnectivityResult result) {
        bool wasConnected = _isConnected;
        _isConnected = result != ConnectivityResult.none;

        // Log connectivity changes
        if (wasConnected != _isConnected) {
          print('🌐 Network status: ${_isConnected ? "Connected" : "Disconnected"}');
          // Network status change logged
        }
      });

      _isInitialized = true;
      print('✅ Network monitoring initialized');
    } catch (e) {
      print('❌ Network monitoring initialization failed: $e');
      ErrorTrackingService.logError('Network monitoring init failed', null);
    }
  }

  /// Check if device is connected to internet
  bool get isConnected => _isConnected;

  /// Test Firebase connectivity
  Future<bool> testFirebaseConnection() async {
    if (!_isConnected) return false;

    try {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('platform')
          .get()
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      ErrorTrackingService.logError('Firebase test failed: ${e.toString()}', null);
      return false;
    }
  }

  /// Test general internet connectivity
  Future<bool> testInternetConnection() async {
    if (!_isConnected) return false;

    try {
      // Simple connectivity test
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      ErrorTrackingService.logError('Internet connectivity test failed', null);
      return false;
    }
  }

  /// Get connection type
  Future<String> getConnectionType() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.toString();
    } catch (e) {
      return 'unknown';
    }
  }

  /// Check if connection is stable (for uploads/downloads)
  Future<bool> isConnectionStable() async {
    if (!_isConnected) return false;

    try {
      // Test with a small Firestore operation
      await FirebaseFirestore.instance
          .collection('config')
          .doc('platform')
          .get()
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get network status summary
  String getNetworkStatus() {
    return 'Network: ${_isConnected ? "Connected" : "Disconnected"}';
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _isInitialized = false;
  }
}

/// Network-aware widget mixin
mixin NetworkAwareWidget {
  bool get isNetworkAvailable => NetworkService().isConnected;

  Future<bool> get isFirebaseAvailable async {
    return await NetworkService().testFirebaseConnection();
  }

  void logNetworkError(String operation, String error) {
    ErrorTrackingService.logError('Network error in $operation: $error', null);
  }
} 