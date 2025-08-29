import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Lightweight error tracking service
/// Designed to be crash-safe and performance-friendly
class ErrorTrackingService {
  static bool _isInitialized = false;
  static FirebaseCrashlytics? _crashlytics;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if Firebase Crashlytics is available
      if (kIsWeb) {
        // On web, Crashlytics might not be available
        if (kDebugMode) print('🔍 DEBUG: Running on web, Crashlytics may not be available');
        return;
      }
      
      _crashlytics = FirebaseCrashlytics.instance;
      
      // Safely set crashlytics collection
      try {
        await _crashlytics!.setCrashlyticsCollectionEnabled(false);
      } catch (e) {
        if (kDebugMode) print('🔍 DEBUG: Could not set Crashlytics collection enabled: $e');
      }
      
      _isInitialized = true;
      if (kDebugMode) print('🔍 DEBUG: ErrorTrackingService initialized successfully');
    } catch (e) {
      if (kDebugMode) print('🔍 DEBUG: Error initializing ErrorTrackingService: $e');
    }
  }

  static void logError(dynamic error, StackTrace? stackTrace) {
    try {
      // Log to console only in debug mode
      if (kDebugMode) {
        print('🚨 Error: $error');
        if (stackTrace != null) {
          print('🚨 Stack trace: $stackTrace');
        }
      }

      // Log to Crashlytics if available and not on web
      if (_crashlytics != null && !kIsWeb) {
      try {
          _crashlytics!.log('$error');
          if (stackTrace != null) {
            _crashlytics!.recordError(error, stackTrace);
      }
    } catch (e) {
          if (kDebugMode) print('🔍 DEBUG: Could not log to Crashlytics: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) print('🔍 DEBUG: Error in logError: $e');
    }
  }

  static void recordError(dynamic error, StackTrace? stackTrace) {
    logError(error, stackTrace);
  }

  static void handleFlutterError(FlutterErrorDetails details) {
    logError(details.exception, details.stack);
  }
} 