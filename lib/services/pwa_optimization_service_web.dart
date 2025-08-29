import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web-specific implementation of PWA optimization features
class PWAOptimizationServiceWeb {
  /// Save data to sessionStorage
  static void saveToSessionStorage(String key, String value) {
    try {
      html.window.sessionStorage[key] = value;
    } catch (e) {
      // Ignore errors - sessionStorage might not be available
    }
  }
  
  /// Save data to localStorage
  static void saveToLocalStorage(String key, String value) {
    try {
      html.window.localStorage[key] = value;
    } catch (e) {
      // Ignore errors - localStorage might not be available
    }
  }
  
  /// Get data from localStorage
  static String? getFromLocalStorage(String key) {
    try {
      return html.window.localStorage[key];
    } catch (e) {
      return null;
    }
  }
  
  /// Setup visibility change handlers
  static void setupVisibilityHandlers({
    required VoidCallback onPageHidden,
    required VoidCallback onPageVisible,
  }) {
    try {
      // Listen for page visibility changes
      html.document.onVisibilityChange.listen((event) {
        if (html.document.hidden == true) {
          onPageHidden();
        } else {
          onPageVisible();
        }
      });
      
      // Listen for page hide/show events
      html.window.onPageHide.listen((event) {
        onPageHidden();
      });
      
      html.window.onPageShow.listen((event) {
        onPageVisible();
      });
    } catch (e) {
      // Ignore errors - event listeners might not be available
    }
  }
  
  /// Check if page is currently hidden
  static bool isPageHidden() {
    try {
      return html.document.hidden == true;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if running in PWA mode
  static bool isPWAMode() {
    try {
      return html.window.matchMedia('(display-mode: standalone)').matches;
    } catch (e) {
      return false;
    }
  }
}
