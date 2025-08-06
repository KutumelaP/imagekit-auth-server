import 'package:flutter/material.dart';

/// Comprehensive input validation service for security and data integrity
class InputValidator {
  // Email validation
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );
    return emailRegex.hasMatch(email);
  }

  // Phone number validation (international format)
  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's between 10-15 digits (international standard)
    return digitsOnly.length >= 10 && digitsOnly.length <= 15;
  }

  // Password validation
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;
    
    // Check for at least one uppercase letter
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    
    // Check for at least one lowercase letter
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    
    // Check for at least one digit
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    
    // Check for at least one special character
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    return hasUppercase && hasLowercase && hasDigit && hasSpecial;
  }

  // Name validation
  static bool isValidName(String name) {
    if (name.isEmpty) return false;
    
    // Check for minimum length
    if (name.length < 2) return false;
    
    // Check for maximum length
    if (name.length > 50) return false;
    
    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    final nameRegex = RegExp(r'^[a-zA-Z\s\-]+$');
    return nameRegex.hasMatch(name);
  }

  // Product name validation
  static bool isValidProductName(String name) {
    if (name.isEmpty) return false;
    
    // Check for minimum length
    if (name.length < 3) return false;
    
    // Check for maximum length
    if (name.length > 100) return false;
    
    // Check for valid characters (letters, numbers, spaces, hyphens, apostrophes)
    final productNameRegex = RegExp(r'^[a-zA-Z0-9\s\-]+$');
    return productNameRegex.hasMatch(name);
  }

  // Price validation
  static bool isValidPrice(String price) {
    if (price.isEmpty) return false;
    
    // Check for valid price format (numbers with optional decimal)
    final priceRegex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!priceRegex.hasMatch(price)) return false;
    
    // Convert to double and check range
    final priceValue = double.tryParse(price);
    if (priceValue == null) return false;
    
    // Check if price is reasonable (between 0.01 and 999999.99)
    return priceValue >= 0.01 && priceValue <= 999999.99;
  }

  // Description validation
  static bool isValidDescription(String description) {
    if (description.isEmpty) return false;
    
    // Check for minimum length
    if (description.length < 10) return false;
    
    // Check for maximum length
    if (description.length > 1000) return false;
    
    return true;
  }

  // Address validation
  static bool isValidAddress(String address) {
    if (address.isEmpty) return false;
    
    // Check for minimum length
    if (address.length < 10) return false;
    
    // Check for maximum length
    if (address.length > 200) return false;
    
    return true;
  }

  // Message validation (for chat)
  static bool isValidMessage(String message) {
    if (message.trim().isEmpty) return false;
    
    // Check for maximum length
    if (message.length > 1000) return false;
    
    return true;
  }

  // URL validation
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  // File size validation (in bytes)
  static bool isValidFileSize(int fileSizeBytes, {int maxSizeMB = 10}) {
    final maxSizeBytes = maxSizeMB * 1024 * 1024;
    return fileSizeBytes > 0 && fileSizeBytes <= maxSizeBytes;
  }

  // File extension validation
  static bool isValidImageExtension(String fileName) {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
    final extension = fileName.toLowerCase().substring(fileName.lastIndexOf('.'));
    return validExtensions.contains(extension);
  }

  // Get validation error message
  static String getErrorMessage(String fieldName, String value, String validationType) {
    switch (validationType) {
      case 'email':
        return 'Please enter a valid email address';
      case 'phone':
        return 'Please enter a valid phone number';
      case 'password':
        return 'Password must be at least 8 characters with uppercase, lowercase, number, and special character';
      case 'name':
        return 'Please enter a valid name (2-50 characters)';
      case 'productName':
        return 'Please enter a valid product name (3-100 characters)';
      case 'price':
        return 'Please enter a valid price (0.01 - 999999.99)';
      case 'description':
        return 'Description must be between 10 and 1000 characters';
      case 'address':
        return 'Please enter a valid address (10-200 characters)';
      case 'message':
        return 'Message cannot be empty and must be less than 1000 characters';
      case 'url':
        return 'Please enter a valid URL';
      case 'fileSize':
        return 'File size must be less than 10MB';
      case 'fileExtension':
        return 'Please select a valid image file (JPG, PNG, WebP, GIF)';
      default:
        return 'Please enter a valid $fieldName';
    }
  }

  // Sanitize input (remove potentially dangerous characters)
  static String sanitizeInput(String input) {
    // Remove HTML tags
    final noHtml = input.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Remove script tags
    final noScript = noHtml.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '');
    
    // Remove other potentially dangerous patterns
    final sanitized = noScript
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .trim();
    
    return sanitized;
  }

  // Validate and sanitize input
  static String? validateAndSanitize({
    required String value,
    required String fieldName,
    required String validationType,
  }) {
    final sanitized = sanitizeInput(value);
    
    bool isValid = false;
    switch (validationType) {
      case 'email':
        isValid = isValidEmail(sanitized);
        break;
      case 'phone':
        isValid = isValidPhone(sanitized);
        break;
      case 'password':
        isValid = isValidPassword(sanitized);
        break;
      case 'name':
        isValid = isValidName(sanitized);
        break;
      case 'productName':
        isValid = isValidProductName(sanitized);
        break;
      case 'price':
        isValid = isValidPrice(sanitized);
        break;
      case 'description':
        isValid = isValidDescription(sanitized);
        break;
      case 'address':
        isValid = isValidAddress(sanitized);
        break;
      case 'message':
        isValid = isValidMessage(sanitized);
        break;
      case 'url':
        isValid = isValidUrl(sanitized);
        break;
      default:
        isValid = sanitized.isNotEmpty;
    }
    
    if (!isValid) {
      return getErrorMessage(fieldName, sanitized, validationType);
    }
    
    return null; // No error
  }
} 