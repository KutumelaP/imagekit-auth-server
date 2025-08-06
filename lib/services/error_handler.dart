import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class ErrorHandler {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static String handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'weak-password':
          return 'Password is too weak. Please choose a stronger password.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'operation-not-allowed':
          return 'This operation is not allowed.';
        default:
          return 'Authentication failed: ${e.message}';
      }
    }
    return 'Authentication failed. Please try again.';
  }

  static String handleGeneralException(dynamic e) {
    if (e is FirebaseException) {
      return 'Database error: ${e.message}';
    } else if (e is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepTeal,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    ) ?? false;
  }

  static Future<String?> showInputDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    String? initialValue,
  }) async {
    final TextEditingController controller = TextEditingController(text: initialValue);
    
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your input...',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepTeal,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  /// Handles network-related errors with retry logic
  static Future<T> handleNetworkRequest<T>({
    required Future<T> Function() request,
    int maxRetries = 3,
    Duration? initialDelay,
  }) async {
    int retryCount = 0;
    Duration delay = initialDelay ?? const Duration(seconds: 1);

    while (retryCount < maxRetries) {
      try {
        return await request();
      } catch (e) {
        retryCount++;
        print('🔄 Network request failed (attempt $retryCount/$maxRetries): $e');

        if (retryCount >= maxRetries) {
          print('❌ Max retries reached, throwing error');
          rethrow;
        }

        // Check if it's a connection error that should be retried
        if (_shouldRetry(e)) {
          print('⏳ Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
          delay = Duration(seconds: delay.inSeconds * 2); // Exponential backoff
        } else {
          // Don't retry for non-network errors
          rethrow;
        }
      }
    }

    throw Exception('Request failed after $maxRetries attempts');
  }

  /// Determines if an error should trigger a retry
  static bool _shouldRetry(dynamic error) {
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (error.toString().contains('Connection reset by peer')) return true;
    if (error.toString().contains('Connection refused')) return true;
    if (error.toString().contains('Network is unreachable')) return true;
    if (error.toString().contains('timeout')) return true;
    
    return false;
  }

  /// Handles ImageKit-specific errors
  static String handleImageKitError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('authentication') || errorString.contains('token')) {
      return 'Authentication failed. Please try again.';
    } else if (errorString.contains('quota') || errorString.contains('limit')) {
      return 'Upload quota exceeded. Please try again later.';
    } else if (errorString.contains('file size') || errorString.contains('too large')) {
      return 'File size too large. Please choose a smaller image.';
    } else if (errorString.contains('format') || errorString.contains('unsupported')) {
      return 'Unsupported file format. Please use JPG, PNG, or WebP.';
    } else if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    } else {
      return 'Upload failed. Please try again.';
    }
  }

  /// Handles Firestore-specific errors
  static String handleFirestoreError(dynamic error) {
    if (error.toString().contains('permission-denied')) {
      return 'Access denied. Please log in to continue.';
    } else if (error.toString().contains('not-found')) {
      return 'Data not found. Please refresh and try again.';
    } else if (error.toString().contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again.';
    } else if (error.toString().contains('network')) {
      return 'Network error. Please check your connection.';
    } else {
      return 'Database error. Please try again.';
    }
  }

  /// Logs errors with context for debugging
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    print('❌ Error in $context: $error');
    if (stackTrace != null) {
      print('📚 Stack trace: $stackTrace');
    }
  }
} 