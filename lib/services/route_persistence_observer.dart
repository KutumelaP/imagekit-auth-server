import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoutePersistenceObserver extends NavigatorObserver {
  static const String _lastRouteKey = 'last_route_v1';
  static const String _lastRouteTimeKey = 'last_route_time_v1';

  final Set<String> _ignoreRoutes = {'', '/', '/splash'};

  Future<void> _save(String? routeName) async {
    try {
      if (routeName == null) return;
      if (_ignoreRoutes.contains(routeName)) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastRouteKey, routeName);
      await prefs.setInt(_lastRouteTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _save(route.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _save(newRoute?.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _save(previousRoute?.settings.name);
  }

  static Future<String?> getLastRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastRouteKey);
    } catch (_) {
      return null;
    }
  }
}


