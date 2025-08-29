import 'package:flutter/foundation.dart';

/// Stub implementation of PWA optimization features for non-web platforms
class PWAOptimizationServiceWeb {
  /// Save data to sessionStorage (stub - no-op on non-web)
  static void saveToSessionStorage(String key, String value) {
    // No-op on non-web platforms
  }
  
  /// Save data to localStorage (stub - no-op on non-web)
  static void saveToLocalStorage(String key, String value) {
    // No-op on non-web platforms
  }
  
  /// Get data from localStorage (stub - returns null on non-web)
  static String? getFromLocalStorage(String key) {
    return null;
  }
  
  /// Setup visibility change handlers (stub - no-op on non-web)
  static void setupVisibilityHandlers({
    required VoidCallback onPageHidden,
    required VoidCallback onPageVisible,
  }) {
    // No-op on non-web platforms
  }
  
  /// Check if page is currently hidden (stub - returns false on non-web)
  static bool isPageHidden() {
    return false;
  }
  
  /// Check if running in PWA mode (stub - returns false on non-web)
  static bool isPWAMode() {
    return false;
  }
}
