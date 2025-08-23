import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:html' as html;

class WebNavigationStateManager {
  static const String _lastRouteKey = 'last_route';
  static const String _routeHistoryKey = 'route_history';
  static const String _routeArgumentsKey = 'route_arguments';
  
  static final WebNavigationStateManager _instance = WebNavigationStateManager._internal();
  factory WebNavigationStateManager() => _instance;
  WebNavigationStateManager._internal();

  // Store current route and arguments
  String? _currentRoute;
  Map<String, dynamic>? _currentArguments;
  List<String> _routeHistory = [];
  
  // Get current route
  String? get currentRoute => _currentRoute;
  
  // Get current arguments
  Map<String, dynamic>? get currentArguments => _currentArguments;
  
  // Get route history
  List<String> get routeHistory => List.unmodifiable(_routeHistory);

  /// Save current navigation state to localStorage
  Future<void> saveNavigationState(String route, {Map<String, dynamic>? arguments}) async {
    try {
      _currentRoute = route;
      _currentArguments = arguments;
      
      // Add to history (keep last 10 routes)
      if (!_routeHistory.contains(route)) {
        _routeHistory.add(route);
        if (_routeHistory.length > 10) {
          _routeHistory.removeAt(0);
        }
      }
      
      // Save to localStorage
      html.window.localStorage[_lastRouteKey] = route;
      html.window.localStorage[_routeHistoryKey] = jsonEncode(_routeHistory);
      
      if (arguments != null) {
        html.window.localStorage[_routeArgumentsKey] = jsonEncode(arguments);
      } else {
        html.window.localStorage.remove(_routeArgumentsKey);
      }
      
      print('🔍 DEBUG: Web navigation state saved - Route: $route, Args: $arguments');
    } catch (e) {
      print('❌ Error saving web navigation state: $e');
    }
  }

  /// Restore navigation state from localStorage
  Future<Map<String, dynamic>?> restoreNavigationState() async {
    try {
      final lastRoute = html.window.localStorage[_lastRouteKey];
      final routeHistoryJson = html.window.localStorage[_routeHistoryKey];
      final argumentsJson = html.window.localStorage[_routeArgumentsKey];
      
      if (lastRoute != null) {
        _currentRoute = lastRoute;
        
        if (routeHistoryJson != null) {
          try {
            _routeHistory = List<String>.from(jsonDecode(routeHistoryJson));
          } catch (e) {
            _routeHistory = [lastRoute];
          }
        } else {
          _routeHistory = [lastRoute];
        }
        
        Map<String, dynamic>? arguments;
        if (argumentsJson != null) {
          try {
            arguments = jsonDecode(argumentsJson) as Map<String, dynamic>;
            _currentArguments = arguments;
          } catch (e) {
            print('❌ Error parsing web route arguments: $e');
          }
        }
        
        print('🔍 DEBUG: Web navigation state restored - Route: $lastRoute, Args: $arguments');
        return {
          'route': lastRoute,
          'arguments': arguments,
          'history': _routeHistory,
        };
      }
    } catch (e) {
      print('❌ Error restoring web navigation state: $e');
    }
    return null;
  }

  /// Clear navigation state from localStorage
  Future<void> clearNavigationState() async {
    try {
      _currentRoute = null;
      _currentArguments = null;
      _routeHistory.clear();
      
      html.window.localStorage.remove(_lastRouteKey);
      html.window.localStorage.remove(_routeHistoryKey);
      html.window.localStorage.remove(_routeArgumentsKey);
      
      print('🔍 DEBUG: Web navigation state cleared');
    } catch (e) {
      print('❌ Error clearing web navigation state: $e');
    }
  }

  /// Check if we should restore navigation state
  bool shouldRestoreNavigation() {
    return _currentRoute != null && _currentRoute != '/home';
  }

  /// Get the last valid route (skip home if it's the only route)
  String? getLastValidRoute() {
    if (_routeHistory.isEmpty) return null;
    
    // Find the last non-home route
    for (int i = _routeHistory.length - 1; i >= 0; i--) {
      final route = _routeHistory[i];
      if (route != '/home' && route != '/') {
        return route;
      }
    }
    
    return null;
  }

  /// Update route history when navigating
  void updateRouteHistory(String route) {
    if (route != _currentRoute) {
      _currentRoute = route;
      
      // Add to history if not already there
      if (!_routeHistory.contains(route)) {
        _routeHistory.add(route);
        
        // Keep only last 10 routes
        if (_routeHistory.length > 10) {
          _routeHistory.removeAt(0);
        }
      }
      
      print('🔍 DEBUG: Web route history updated - Current: $route, History: $_routeHistory');
    }
  }

  /// Check if route is in history
  bool isRouteInHistory(String route) {
    return _routeHistory.contains(route);
  }

  /// Get route depth (how many levels deep we are)
  int getRouteDepth() {
    return _routeHistory.length;
  }

  /// Check if we can go back
  bool canGoBack() {
    return _routeHistory.length > 1;
  }

  /// Get previous route
  String? getPreviousRoute() {
    if (_routeHistory.length > 1) {
      return _routeHistory[_routeHistory.length - 2];
    }
    return null;
  }

  /// Test if localStorage is available
  bool isLocalStorageAvailable() {
    try {
      final testKey = '__test__';
      html.window.localStorage[testKey] = 'test';
      html.window.localStorage.remove(testKey);
      return true;
    } catch (e) {
      print('❌ localStorage not available: $e');
      return false;
    }
  }
}

