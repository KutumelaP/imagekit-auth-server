import 'package:flutter/material.dart';
import 'web_navigation_state_manager.dart';

class NavigationRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final WebNavigationStateManager _navigationManager = WebNavigationStateManager();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    
    if (route.settings.name != null) {
      final routeName = route.settings.name!;
      final arguments = route.settings.arguments as Map<String, dynamic>?;
      
      _navigationManager.updateRouteHistory(routeName);
      _navigationManager.saveNavigationState(routeName, arguments: arguments);
      
      print('🔍 DEBUG: Route pushed - $routeName, Args: $arguments');
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    
    if (previousRoute?.settings.name != null) {
      final routeName = previousRoute!.settings.name!;
      final arguments = previousRoute.settings.arguments as Map<String, dynamic>?;
      
      _navigationManager.updateRouteHistory(routeName);
      _navigationManager.saveNavigationState(routeName, arguments: arguments);
      
      print('🔍 DEBUG: Route popped back to - $routeName, Args: $arguments');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    
    if (newRoute?.settings.name != null) {
      final routeName = newRoute!.settings.name!;
      final arguments = newRoute.settings.arguments as Map<String, dynamic>?;
      
      _navigationManager.updateRouteHistory(routeName);
      _navigationManager.saveNavigationState(routeName, arguments: arguments);
      
      print('🔍 DEBUG: Route replaced - $routeName, Args: $arguments');
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    
    if (previousRoute?.settings.name != null) {
      final routeName = previousRoute!.settings.name!;
      final arguments = previousRoute.settings.arguments as Map<String, dynamic>?;
      
      _navigationManager.updateRouteHistory(routeName);
      _navigationManager.saveNavigationState(routeName, arguments: arguments);
      
      print('🔍 DEBUG: Route removed, back to - $routeName, Args: $arguments');
    }
  }
}
