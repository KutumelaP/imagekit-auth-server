import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Conditional import for web-only features
import 'pwa_optimization_service_web.dart' if (dart.library.io) 'pwa_optimization_service_stub.dart';

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
      
      // Also save to sessionStorage for immediate access (web only)
      if (kIsWeb) {
        PWAOptimizationServiceWeb.saveToSessionStorage(_sessionIdKey, _currentSessionId!);
        PWAOptimizationServiceWeb.saveToSessionStorage(_lastActiveKey, DateTime.now().millisecondsSinceEpoch.toString());
      }
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
      // Use web-specific implementation
      PWAOptimizationServiceWeb.setupVisibilityHandlers(
        onPageHidden: _onPageHidden,
        onPageVisible: _onPageVisible,
      );
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
    if (!kIsWeb) return;
    
    try {
      // Check if page is hidden (web only)
      if (PWAOptimizationServiceWeb.isPageHidden()) {
        // Don't run keep-alive when page is hidden
        Future.delayed(Duration(seconds: 30), () {
          _pwKeepAliveTick();
        });
        return;
      }
      
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
      
      // Save critical app state to localStorage for recovery (web only)
      if (kIsWeb) {
        PWAOptimizationServiceWeb.saveToLocalStorage('pwa_state_backup', DateTime.now().millisecondsSinceEpoch.toString());
        PWAOptimizationServiceWeb.saveToLocalStorage('pwa_last_save', DateTime.now().millisecondsSinceEpoch.toString());
      }
      
      if (kDebugMode) {
        print('📱 PWA state saved successfully');
      }
    } catch (e) {
      // Ignore errors - this is best-effort
      if (kDebugMode) {
        print('❌ Error saving app state: $e');
      }
    }
  }
  
  /// Get PWA installation status
  static bool get isInstalled {
    if (!kIsWeb) return false;
    
    try {
      // Check if running as PWA
      if (isPWA) return true;
      
      // Check if user has completed installation flow (web only)
      if (kIsWeb) {
        final installCompleted = PWAOptimizationServiceWeb.getFromLocalStorage('pwa_install_completed');
        return installCompleted != null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Get PWA performance metrics
  static Map<String, dynamic> getPerformanceMetrics() {
    if (!kIsWeb) return {};
    
    try {
      final uptime = getSessionUptime();
      final isInstalled = PWAOptimizationService.isInstalled;
      final isPWAMode = isPWA;
      
      return {
        'session_uptime_minutes': uptime,
        'is_installed': isInstalled,
        'is_pwa_mode': isPWAMode,
        'current_session_id': _currentSessionId,
        'initialization_time': _isInitialized ? 'initialized' : 'not_initialized',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  /// Check if running as PWA
  static bool get isPWA {
    if (!kIsWeb) return false;
    
    try {
      return PWAOptimizationServiceWeb.isPWAMode();
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
