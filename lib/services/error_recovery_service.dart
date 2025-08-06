import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Error recovery service to handle different types of errors and attempt automatic recovery
class ErrorRecoveryService {
  static final Map<String, int> _errorCounts = {};
  static final Map<String, DateTime> _lastErrorTimes = {};
  
  // Error thresholds
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _errorCooldown = Duration(minutes: 5);
  
  /// Attempt to recover from different types of errors
  static Future<bool> attemptRecovery(dynamic error, {String? context}) async {
    final errorType = _getErrorType(error);
    final errorKey = '${errorType}_${context ?? 'general'}';
    
    // Check if we've exceeded retry limits
    if (_errorCounts[errorKey] != null && _errorCounts[errorKey]! >= _maxRetries) {
      final lastError = _lastErrorTimes[errorKey];
      if (lastError != null && DateTime.now().difference(lastError) < _errorCooldown) {
        print('❌ Max retries exceeded for $errorKey, waiting for cooldown');
        return false;
      } else {
        // Reset error count after cooldown
        _errorCounts[errorKey] = 0;
      }
    }
    
    // Increment error count
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
    _lastErrorTimes[errorKey] = DateTime.now();
    
    print('🔄 Attempting recovery for $errorType (attempt ${_errorCounts[errorKey]})');
    
    switch (errorType) {
      case 'firebase_auth':
        return await _handleFirebaseAuthError(error);
      case 'firestore':
        return await _handleFirestoreError(error);
      case 'network':
        return await _handleNetworkError(error);
      case 'permission':
        return await _handlePermissionError(error);
      case 'validation':
        return await _handleValidationError(error);
      case 'timeout':
        return await _handleTimeoutError(error);
      default:
        return await _handleGenericError(error);
    }
  }
  
  /// Determine the type of error
  static String _getErrorType(dynamic error) {
    if (error is FirebaseAuthException) return 'firebase_auth';
    if (error is FirebaseException) return 'firestore';
    if (error is SocketException) return 'network';
    if (error is HttpException) return 'network';
    if (error.toString().contains('permission')) return 'permission';
    if (error.toString().contains('validation')) return 'validation';
    if (error.toString().contains('timeout')) return 'timeout';
    if (error.toString().contains('network')) return 'network';
    return 'generic';
  }
  
  /// Handle Firebase Auth errors
  static Future<bool> _handleFirebaseAuthError(dynamic error) async {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'user-disabled':
          // User account issues - cannot auto-recover
          return false;
        case 'invalid-credential':
        case 'wrong-password':
          // Credential issues - cannot auto-recover
          return false;
        case 'too-many-requests':
          // Rate limiting - wait and retry
          await Future.delayed(const Duration(minutes: 1));
          return true;
        case 'network-request-failed':
          // Network issue - retry after delay
          await Future.delayed(_retryDelay);
          return true;
        default:
          return false;
      }
    }
    return false;
  }
  
  /// Handle Firestore errors
  static Future<bool> _handleFirestoreError(dynamic error) async {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          // Permission issue - cannot auto-recover
          return false;
        case 'unavailable':
        case 'deadline-exceeded':
          // Service unavailable - retry after delay
          await Future.delayed(_retryDelay);
          return true;
        case 'resource-exhausted':
          // Quota exceeded - wait longer
          await Future.delayed(const Duration(minutes: 2));
          return true;
        default:
          return false;
      }
    }
    return false;
  }
  
  /// Handle network errors
  static Future<bool> _handleNetworkError(dynamic error) async {
    // Network errors - retry after delay
    await Future.delayed(_retryDelay);
    return true;
  }
  
  /// Handle permission errors
  static Future<bool> _handlePermissionError(dynamic error) async {
    // Permission errors usually require user action
    return false;
  }
  
  /// Handle validation errors
  static Future<bool> _handleValidationError(dynamic error) async {
    // Validation errors usually require user action
    return false;
  }
  
  /// Handle timeout errors
  static Future<bool> _handleTimeoutError(dynamic error) async {
    // Timeout errors - retry after delay
    await Future.delayed(_retryDelay);
    return true;
  }
  
  /// Handle generic errors
  static Future<bool> _handleGenericError(dynamic error) async {
    // For generic errors, try a short delay and retry
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
  
  /// Get user-friendly error message
  static String getUserFriendlyMessage(dynamic error) {
    final errorType = _getErrorType(error);
    
    switch (errorType) {
      case 'firebase_auth':
        if (error is FirebaseAuthException) {
          switch (error.code) {
            case 'user-not-found':
              return 'Account not found. Please check your email and try again.';
            case 'wrong-password':
              return 'Incorrect password. Please try again.';
            case 'too-many-requests':
              return 'Too many login attempts. Please wait a moment and try again.';
            case 'network-request-failed':
              return 'Network error. Please check your connection and try again.';
            default:
              return 'Authentication error. Please try again.';
          }
        }
        return 'Authentication error. Please try again.';
        
      case 'firestore':
        if (error is FirebaseException) {
          switch (error.code) {
            case 'permission-denied':
              return 'Access denied. Please contact support.';
            case 'unavailable':
              return 'Service temporarily unavailable. Please try again.';
            case 'resource-exhausted':
              return 'Service quota exceeded. Please try again later.';
            default:
              return 'Database error. Please try again.';
          }
        }
        return 'Database error. Please try again.';
        
      case 'network':
        return 'Network error. Please check your connection and try again.';
        
      case 'permission':
        return 'Permission denied. Please check your settings.';
        
      case 'validation':
        return 'Invalid input. Please check your data and try again.';
        
      case 'timeout':
        return 'Request timed out. Please try again.';
        
      default:
        return 'An error occurred. Please try again.';
    }
  }
  
  /// Check if an error is recoverable
  static bool isRecoverable(dynamic error) {
    final errorType = _getErrorType(error);
    
    // Some errors are never recoverable
    switch (errorType) {
      case 'firebase_auth':
        if (error is FirebaseAuthException) {
          return ['too-many-requests', 'network-request-failed'].contains(error.code);
        }
        return false;
      case 'firestore':
        if (error is FirebaseException) {
          return ['unavailable', 'deadline-exceeded', 'resource-exhausted'].contains(error.code);
        }
        return false;
      case 'network':
      case 'timeout':
        return true;
      case 'permission':
      case 'validation':
        return false;
      default:
        return true;
    }
  }
  
  /// Clear error counts (for testing or admin purposes)
  static void clearErrorCounts() {
    _errorCounts.clear();
    _lastErrorTimes.clear();
  }
  
  /// Get error statistics
  static Map<String, dynamic> getErrorStats() {
    return {
      'errorCounts': Map.from(_errorCounts),
      'lastErrorTimes': _lastErrorTimes.map((key, value) => MapEntry(key, value.toIso8601String())),
    };
  }
} 