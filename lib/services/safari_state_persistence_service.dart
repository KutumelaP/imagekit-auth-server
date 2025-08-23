import 'dart:convert';
import 'dart:html' as html;

/// Service to handle state persistence for Safari reloads
/// Makes reloads invisible to users by saving/restoring critical state
class SafariStatePersistenceService {
  static const String _cartKey = 'cart_state';
  static const String _userKey = 'user_state';
  static const String _navigationKey = 'navigation_state';
  static const String _formDataKey = 'form_data_state';
  static const String _lastReloadKey = 'last_reload_timestamp';
  
  /// Check if this is a Safari reload
  static bool get isSafariReload {
    final lastReload = html.window.localStorage[_lastReloadKey];
    if (lastReload == null) {
      // First visit, set timestamp
      html.window.localStorage[_lastReloadKey] = DateTime.now().millisecondsSinceEpoch.toString();
      return false;
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = int.tryParse(lastReload) ?? 0;
    final timeDiff = now - last;
    
    // If less than 5 seconds, likely a reload
    return timeDiff < 5000;
  }
  
  /// Save cart state
  static void saveCartState(Map<String, dynamic> cart) {
    try {
      html.window.localStorage[_cartKey] = jsonEncode(cart);
      print('🔄 [SAFARI] Cart state saved: ${cart.length} items');
    } catch (e) {
      print('⚠️ [SAFARI] Failed to save cart state: $e');
    }
  }
  
  /// Load cart state
  static Map<String, dynamic>? loadCartState() {
    try {
      final data = html.window.localStorage[_cartKey];
      if (data != null) {
        final cart = jsonDecode(data) as Map<String, dynamic>;
        print('🔄 [SAFARI] Cart state restored: ${cart.length} items');
        return cart;
      }
    } catch (e) {
      print('⚠️ [SAFARI] Failed to load cart state: $e');
    }
    return null;
  }
  
  /// Save user state
  static void saveUserState(Map<String, dynamic> user) {
    try {
      html.window.localStorage[_userKey] = jsonEncode(user);
      print('🔄 [SAFARI] User state saved');
    } catch (e) {
      print('⚠️ [SAFARI] Failed to save user state: $e');
    }
  }
  
  /// Load user state
  static Map<String, dynamic>? loadUserState() {
    try {
      final data = html.window.localStorage[_userKey];
      if (data != null) {
        final user = jsonDecode(data) as Map<String, dynamic>;
        print('🔄 [SAFARI] User state restored');
        return user;
      }
    } catch (e) {
      print('⚠️ [SAFARI] Failed to load user state: $e');
    }
    return null;
  }
  
  /// Save navigation state
  static void saveNavigationState(String route, Map<String, dynamic>? params) {
    try {
      final navigation = {
        'route': route,
        'params': params,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      html.window.localStorage[_navigationKey] = jsonEncode(navigation);
      print('🔄 [SAFARI] Navigation state saved: $route');
    } catch (e) {
      print('⚠️ [SAFARI] Failed to save navigation state: $e');
    }
  }
  
  /// Load navigation state
  static Map<String, dynamic>? loadNavigationState() {
    try {
      final data = html.window.localStorage[_navigationKey];
      if (data != null) {
        final navigation = jsonDecode(data) as Map<String, dynamic>;
        print('🔄 [SAFARI] Navigation state restored: ${navigation['route']}');
        return navigation;
      }
    } catch (e) {
      print('⚠️ [SAFARI] Failed to load navigation state: $e');
    }
    return null;
  }
  
  /// Save form data
  static void saveFormData(String formId, Map<String, dynamic> formData) {
    try {
      final key = '${_formDataKey}_$formId';
      html.window.localStorage[key] = jsonEncode(formData);
      print('🔄 [SAFARI] Form data saved: $formId');
    } catch (e) {
      print('⚠️ [SAFARI] Failed to save form data: $e');
    }
  }
  
  /// Load form data
  static Map<String, dynamic>? loadFormData(String formId) {
    try {
      final key = '${_formDataKey}_$formId';
      final data = html.window.localStorage[key];
      if (data != null) {
        final formData = jsonDecode(data) as Map<String, dynamic>;
        print('🔄 [SAFARI] Form data restored: $formId');
        return formData;
      }
    } catch (e) {
      print('⚠️ [SAFARI] Failed to load form data: $e');
    }
    return null;
  }
  
  /// Clear all saved state
  static void clearAllState() {
    try {
      html.window.localStorage.remove(_cartKey);
      html.window.localStorage.remove(_userKey);
      html.window.localStorage.remove(_navigationKey);
      html.window.localStorage.remove(_lastReloadKey);
      
      // Clear form data keys
      final keys = html.window.localStorage.keys.toList();
      for (final key in keys) {
        if (key.startsWith(_formDataKey)) {
          html.window.localStorage.remove(key);
        }
      }
      
      print('🔄 [SAFARI] All state cleared');
    } catch (e) {
      print('⚠️ [SAFARI] Failed to clear state: $e');
    }
  }
  
  /// Update reload timestamp
  static void updateReloadTimestamp() {
    html.window.localStorage[_lastReloadKey] = DateTime.now().millisecondsSinceEpoch.toString();
  }
}
