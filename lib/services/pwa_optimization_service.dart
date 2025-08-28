import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';

/// Service to optimize PWA performance and reduce iOS Safari refreshes
class PWAOptimizationService {
  static const String _lastActiveKey = 'pwa_last_active';
  static const String _sessionIdKey = 'pwa_session_id';
  
  static bool _isInitialized = false;
  static String? _currentSessionId;
  
  /// Initialize PWA optimizations for iOS Safari
  static Future<void> initialize() async {
    if (!kIsWeb || _isInitialized) return;
    
    try {
      _isInitialized = true;
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      if (kDebugMode) {
        print('📱 PWA Optimization Service initializing...');
      }
      
      // Save current session
      await _saveCurrentSession();
      
      // Set up visibility change handler
      _setupVisibilityHandlers();
      
      // Check if this is a restored session
      await _checkSessionRestoration();
      
      // Start keep-alive for PWA
      _startPWAKeepAlive();
      
      if (kDebugMode) {
        print('✅ PWA Optimization Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ PWA Optimization Service error: $e');
      }
    }
  }
  
  /// Save current session information
  static Future<void> _saveCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionIdKey, _currentSessionId!);
      await prefs.setInt(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
      
      // Also save to sessionStorage for immediate access
      html.window.sessionStorage[_sessionIdKey] = _currentSessionId!;
      html.window.sessionStorage[_lastActiveKey] = DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving PWA session: $e');
      }
    }
  }
  
  /// Check if this is a restored session
  static Future<void> _checkSessionRestoration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActive = prefs.getInt(_lastActiveKey);
      
      if (lastActive != null) {
        final timeDiff = DateTime.now().millisecondsSinceEpoch - lastActive;
        final minutesDiff = timeDiff / (1000 * 60);
        
        if (minutesDiff < 5) {
          if (kDebugMode) {
            print('📱 PWA session restored within 5 minutes');
          }
          // Could trigger state restoration here
        } else {
          if (kDebugMode) {
            print('📱 PWA session restored after ${minutesDiff.toStringAsFixed(1)} minutes');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking session restoration: $e');
      }
    }
  }
  
  /// Setup visibility change handlers
  static void _setupVisibilityHandlers() {
    if (!kIsWeb) return;
    
    try {
      // Listen for page visibility changes
      html.document.onVisibilityChange.listen((event) {
        if (html.document.hidden == true) {
          _onPageHidden();
        } else {
          _onPageVisible();
        }
      });
      
      // Listen for page hide/show events
      html.window.onPageHide.listen((event) {
        _onPageHidden();
      });
      
      html.window.onPageShow.listen((event) {
        _onPageVisible();
      });
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting up visibility handlers: $e');
      }
    }
  }
  
  /// Handle page being hidden
  static void _onPageHidden() {
    if (kDebugMode) {
      print('📱 PWA page hidden - saving state');
    }
    
    try {
      // Save current state before page becomes hidden
      _saveCurrentSession();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving state on page hide: $e');
      }
    }
  }
  
  /// Handle page becoming visible
  static void _onPageVisible() {
    if (kDebugMode) {
      print('📱 PWA page visible - resuming');
    }
    
    try {
      // Update session activity
      _saveCurrentSession();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating state on page show: $e');
      }
    }
  }
  
  /// Start PWA keep-alive mechanism
  static void _startPWAKeepAlive() {
    if (!kIsWeb) return;
    
    try {
      // Create a periodic timer to keep the PWA alive
      Future.delayed(Duration(seconds: 30), () {
        _pwKeepAliveTick();
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting PWA keep-alive: $e');
      }
    }
  }
  
  /// Keep-alive tick for PWA
  static void _pwKeepAliveTick() {
    if (!kIsWeb || html.document.hidden == true) {
      // Don't run keep-alive when page is hidden
      Future.delayed(Duration(seconds: 30), () {
        _pwKeepAliveTick();
      });
      return;
    }
    
    try {
      // Minimal activity to keep PWA alive
      if (kDebugMode) {
        print('📱 PWA keep-alive tick');
      }
      
      // Touch SharedPreferences to maintain storage connection
      _saveCurrentSession();
      
      // Schedule next tick
      Future.delayed(Duration(seconds: 30), () {
        _pwKeepAliveTick();
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in PWA keep-alive tick: $e');
      }
      // Still schedule next tick even if this one failed
      Future.delayed(Duration(seconds: 30), () {
        _pwKeepAliveTick();
      });
    }
  }
  
  /// Force save app state (can be called before critical operations)
  static Future<void> saveAppState() async {
    if (!kIsWeb) return;
    
    try {
      await _saveCurrentSession();
      
      // Trigger platform-specific state saving
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    } catch (e) {
      // Ignore errors - this is best-effort
      if (kDebugMode) {
        print('❌ Error saving app state: $e');
      }
    }
  }
  
  /// Check if running as PWA
  static bool get isPWA {
    if (!kIsWeb) return false;
    
    try {
      return html.window.matchMedia('(display-mode: standalone)').matches;
    } catch (e) {
      return false;
    }
  }
  
  /// Get session uptime in minutes
  static double? getSessionUptime() {
    if (_currentSessionId == null) return null;
    
    try {
      final sessionStart = int.parse(_currentSessionId!);
      final now = DateTime.now().millisecondsSinceEpoch;
      return (now - sessionStart) / (1000 * 60);
    } catch (e) {
      return null;
    }
  }
}
