import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alternative authentication service when Firebase Auth is disabled
class AuthBypassService {
  static const String _userIdKey = 'bypass_user_id';
  static const String _userEmailKey = 'bypass_user_email';
  static const String _userRoleKey = 'bypass_user_role';
  
  /// Check if we have a cached user when Firebase Auth is disabled
  static Future<Map<String, dynamic>?> getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);
      final userEmail = prefs.getString(_userEmailKey);
      final userRole = prefs.getString(_userRoleKey);
      
      if (userId != null && userEmail != null) {
        return {
          'uid': userId,
          'email': userEmail,
          'role': userRole ?? 'user',
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting cached user: $e');
      return null;
    }
  }
  
  /// Cache user data when Firebase Auth is disabled
  static Future<void> cacheUser(String uid, String email, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, uid);
      await prefs.setString(_userEmailKey, email);
      await prefs.setString(_userRoleKey, role);
      print('✅ User cached successfully');
    } catch (e) {
      print('❌ Error caching user: $e');
    }
  }
  
  /// Clear cached user data
  static Future<void> clearCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userRoleKey);
      print('✅ Cached user cleared');
    } catch (e) {
      print('❌ Error clearing cached user: $e');
    }
  }
  
  /// Get user document from Firestore using cached user ID
  static Future<Map<String, dynamic>?> getUserDocument() async {
    try {
      final cachedUser = await getCachedUser();
      if (cachedUser == null) return null;
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cachedUser['uid'])
          .get();
      
      return doc.data();
    } catch (e) {
      print('❌ Error getting user document: $e');
      return null;
    }
  }
  
  /// Update user document in Firestore
  static Future<bool> updateUserDocument(Map<String, dynamic> data) async {
    try {
      final cachedUser = await getCachedUser();
      if (cachedUser == null) return false;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cachedUser['uid'])
          .update(data);
      
      return true;
    } catch (e) {
      print('❌ Error updating user document: $e');
      return false;
    }
  }
  
  /// Check if user is authenticated (using cached data)
  static Future<bool> isUserAuthenticated() async {
    final cachedUser = await getCachedUser();
    return cachedUser != null;
  }
  
  /// Get current user ID (using cached data)
  static Future<String?> getCurrentUserId() async {
    final cachedUser = await getCachedUser();
    return cachedUser?['uid'];
  }
  
  /// Get current user email (using cached data)
  static Future<String?> getCurrentUserEmail() async {
    final cachedUser = await getCachedUser();
    return cachedUser?['email'];
  }
  
  /// Get current user role (using cached data)
  static Future<String> getCurrentUserRole() async {
    final cachedUser = await getCachedUser();
    return cachedUser?['role'] ?? 'user';
  }
  
  /// Check if current user is admin (using cached data)
  static Future<bool> isCurrentUserAdmin() async {
    final role = await getCurrentUserRole();
    return role.toLowerCase() == 'admin';
  }
  
  /// Check if current user is seller (using cached data)
  static Future<bool> isCurrentUserSeller() async {
    final role = await getCurrentUserRole();
    return role.toLowerCase() == 'seller';
  }
} 