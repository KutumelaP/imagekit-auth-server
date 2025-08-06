import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Lightweight security service for input validation and sanitization
/// Designed to be crash-safe and performance-friendly
class SecurityService {
  static const int _maxInputLength = 1000;
  static const int _maxEmailLength = 254;
  static const int _maxPasswordLength = 128;
  static const int _minPasswordLength = 6;

  /// Sanitize user input to prevent XSS and injection attacks
  /// Returns null if input is unsafe
  static String? sanitizeInput(String? input) {
    if (input == null || input.isEmpty) return null;
    
    // Limit input length to prevent memory issues
    if (input.length > _maxInputLength) return null;
    
    // Remove potentially dangerous characters
    String sanitized = input
        .replaceAll(RegExp(r'<script.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<.*?>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*='), '')
        .trim();
    
    // Check if sanitization removed too much (suspicious input)
    if (sanitized.length < input.length * 0.5) {
      return null; // Too much was removed, likely malicious
    }
    
    return sanitized.isEmpty ? null : sanitized;
  }

  /// Validate email format safely
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    if (email.length > _maxEmailLength) return false;
    
    // Simple but effective email regex
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  /// Validate password strength safely
  static bool isValidPassword(String? password) {
    if (password == null || password.isEmpty) return false;
    if (password.length < _minPasswordLength || password.length > _maxPasswordLength) return false;
    
    // Check for basic strength requirements
    bool hasLetter = password.contains(RegExp(r'[a-zA-Z]'));
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    
    return hasLetter && hasNumber;
  }

  /// Validate product name safely
  static bool isValidProductName(String? name) {
    if (name == null || name.isEmpty) return false;
    if (name.length > 100) return false; // Reasonable limit
    
    // Remove dangerous characters but keep it simple
    String clean = name.replaceAll('<', '').replaceAll('>', '').replaceAll('"', '').replaceAll("'", '');
    return clean.length >= 2; // Minimum 2 characters
  }

  /// Validate price safely
  static bool isValidPrice(String? price) {
    if (price == null || price.isEmpty) return false;
    
    try {
      double value = double.parse(price);
      return value >= 0.01 && value <= 999999.99; // Reasonable range
    } catch (e) {
      return false;
    }
  }

  /// Create a simple hash for sensitive data (lightweight)
  static String createHash(String input) {
    try {
      final bytes = utf8.encode(input);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      // Fallback to simple hash if crypto fails
      return input.hashCode.toString();
    }
  }

  /// Rate limiting helper (simple implementation)
  static final Map<String, DateTime> _rateLimitMap = {};
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static const int _maxRequestsPerWindow = 10;

  static bool isRateLimited(String key) {
    final now = DateTime.now();
    final lastRequest = _rateLimitMap[key];
    
    if (lastRequest == null) {
      _rateLimitMap[key] = now;
      return false;
    }
    
    if (now.difference(lastRequest) > _rateLimitWindow) {
      _rateLimitMap[key] = now;
      return false;
    }
    
    // Simple rate limiting - just check if we have too many recent requests
    int recentRequests = 0;
    _rateLimitMap.forEach((k, v) {
      if (k.startsWith(key.split('_')[0]) && now.difference(v) <= _rateLimitWindow) {
        recentRequests++;
      }
    });
    
    return recentRequests > _maxRequestsPerWindow;
  }

  /// Clean up rate limit map periodically to prevent memory leaks
  static void cleanupRateLimits() {
    final now = DateTime.now();
    _rateLimitMap.removeWhere((key, time) => 
        now.difference(time) > _rateLimitWindow);
  }

  /// Validate phone number format
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // South African phone numbers should be 9-10 digits
    return digits.length >= 9 && digits.length <= 10;
  }

  /// Validate address safely
  static bool isValidAddress(String? address) {
    if (address == null || address.isEmpty) return false;
    if (address.length > 200) return false; // Reasonable limit
    
    // Basic validation - just check length and remove dangerous chars
    String clean = address.replaceAll('<', '').replaceAll('>', '').replaceAll('"', '').replaceAll("'", '');
    return clean.length >= 5; // Minimum 5 characters
  }

  /// Validate user input for search queries
  static String? sanitizeSearchQuery(String? query) {
    if (query == null || query.isEmpty) return null;
    if (query.length > 100) return null; // Limit search length
    
    // Remove dangerous characters but keep search functionality
    String clean = query
        .replaceAll('<', '').replaceAll('>', '').replaceAll('"', '').replaceAll("'", '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .trim();
    
    return clean.isEmpty ? null : clean;
  }

  /// Validate image URL safely
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.length > 500) return false; // Reasonable URL length
    
    // Check for common image extensions
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
    String lowerUrl = url.toLowerCase();
    
    return imageExtensions.any((ext) => lowerUrl.contains(ext)) ||
           lowerUrl.contains('imagekit.io') ||
           lowerUrl.contains('firebasestorage.googleapis.com');
  }

  /// Simple input length validation
  static bool isValidLength(String? input, int minLength, int maxLength) {
    if (input == null) return false;
    return input.length >= minLength && input.length <= maxLength;
  }

  /// Validate numeric input
  static bool isValidNumber(String? input) {
    if (input == null || input.isEmpty) return false;
    
    try {
      double.parse(input);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate integer input
  static bool isValidInteger(String? input) {
    if (input == null || input.isEmpty) return false;
    
    try {
      int.parse(input);
      return true;
    } catch (e) {
      return false;
    }
  }
}