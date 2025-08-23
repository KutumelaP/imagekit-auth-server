import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NavigationStateManager {
  static const String _lastRouteKey = 'last_route';
  static const String _routeHistoryKey = 'route_history';
  static const String _routeArgumentsKey = 'route_arguments';
  
  static final NavigationStateManager _instance = NavigationStateManager._internal();
  factory NavigationStateManager() => _instance;
  NavigationStateManager._internal();

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

  /// Save current navigation state
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
      
      // Save to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastRouteKey, route);
      await prefs.setStringList(_routeHistoryKey, _routeHistory);
      
      if (arguments != null) {
        await prefs.setString(_routeArgumentsKey, jsonEncode(arguments));
      } else {
        await prefs.remove(_routeArgumentsKey);
      }
      
      print('🔍 DEBUG: Navigation state saved - Route: $route, Args: $arguments');
    } catch (e) {
      print('❌ Error saving navigation state: $e');
    }
  }

  /// Restore navigation state
  Future<Map<String, dynamic>?> restoreNavigationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRoute = prefs.getString(_lastRouteKey);
      final routeHistory = prefs.getStringList(_routeHistoryKey) ?? [];
      final argumentsJson = prefs.getString(_routeArgumentsKey);
      
      if (lastRoute != null) {
        _currentRoute = lastRoute;
        _routeHistory = routeHistory;
        
        Map<String, dynamic>? arguments;
        if (argumentsJson != null) {
          try {
            arguments = jsonDecode(argumentsJson) as Map<String, dynamic>;
            _currentArguments = arguments;
          } catch (e) {
            print('❌ Error parsing route arguments: $e');
          }
        }
        
        print('🔍 DEBUG: Navigation state restored - Route: $lastRoute, Args: $arguments');
        return {
          'route': lastRoute,
          'arguments': arguments,
          'history': routeHistory,
        };
      }
    } catch (e) {
      print('❌ Error restoring navigation state: $e');
    }
    return null;
  }

  /// Clear navigation state
  Future<void> clearNavigationState() async {
    try {
      _currentRoute = null;
      _currentArguments = null;
      _routeHistory.clear();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastRouteKey);
      await prefs.remove(_routeHistoryKey);
      await prefs.remove(_routeArgumentsKey);
      
      print('🔍 DEBUG: Navigation state cleared');
    } catch (e) {
      print('❌ Error clearing navigation state: $e');
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
      
      print('🔍 DEBUG: Route history updated - Current: $route, History: $_routeHistory');
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
}

