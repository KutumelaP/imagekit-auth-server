import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

/// Complete authentication bypass system - no Firebase Auth dependency
class CompleteAuthBypass {
  static const String _sessionKey = 'auth_session';
  static const String _userDataKey = 'user_data';
  static const String _authTokenKey = 'auth_token';
  
  /// Generate a simple session token
  static String _generateSessionToken() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return 'session_${timestamp}_$randomPart';
  }
  
  /// Create a mock user session
  static Future<Map<String, dynamic>> createMockSession({
    required String email,
    String role = 'user',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final sessionToken = _generateSessionToken();
      final userId = 'mock_${DateTime.now().millisecondsSinceEpoch}';
      
      final userData = {
        'uid': userId,
        'email': email,
        'role': role,
        'sessionToken': sessionToken,
        'createdAt': DateTime.now().toIso8601String(),
        'lastLogin': DateTime.now().toIso8601String(),
        ...?additionalData,
      };
      
      // Store session data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, sessionToken);
      await prefs.setString(_userDataKey, jsonEncode(userData));
      await prefs.setString(_authTokenKey, sessionToken);
      
      print('✅ Mock session created for: $email');
      return userData;
    } catch (e) {
      print('❌ Error creating mock session: $e');
      rethrow;
    }
  }
  
  /// Get current session
  static Future<Map<String, dynamic>?> getCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString(_sessionKey);
      final userDataString = prefs.getString(_userDataKey);
      
      if (sessionToken == null || userDataString == null) {
        return null;
      }
      
      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      return userData;
    } catch (e) {
      print('❌ Error getting current session: $e');
      return null;
    }
  }
  
  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final session = await getCurrentSession();
    return session != null;
  }
  
  /// Get current user ID
  static Future<String?> getCurrentUserId() async {
    final session = await getCurrentSession();
    return session?['uid'];
  }
  
  /// Get current user email
  static Future<String?> getCurrentUserEmail() async {
    final session = await getCurrentSession();
    return session?['email'];
  }
  
  /// Get current user role
  static Future<String> getCurrentUserRole() async {
    final session = await getCurrentSession();
    return session?['role'] ?? 'user';
  }
  
  /// Check if user is admin
  static Future<bool> isAdmin() async {
    final role = await getCurrentUserRole();
    return role.toLowerCase() == 'admin';
  }
  
  /// Check if user is seller
  static Future<bool> isSeller() async {
    final role = await getCurrentUserRole();
    return role.toLowerCase() == 'seller';
  }
  
  /// Sign out user
  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_userDataKey);
      await prefs.remove(_authTokenKey);
      print('✅ User signed out successfully');
    } catch (e) {
      print('❌ Error signing out: $e');
    }
  }
  
  /// Update user data
  static Future<bool> updateUserData(Map<String, dynamic> data) async {
    try {
      final session = await getCurrentSession();
      if (session == null) return false;
      
      final updatedData = {...session, ...data};
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userDataKey, jsonEncode(updatedData));
      
      print('✅ User data updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating user data: $e');
      return false;
    }
  }
  
  /// Get user document from Firestore (if available)
  static Future<Map<String, dynamic>?> getUserDocument() async {
    try {
      final session = await getCurrentSession();
      if (session == null) return null;
      
      final userId = session['uid'];
      if (userId == null) return null;
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      return doc.data();
    } catch (e) {
      print('❌ Error getting user document: $e');
      return null;
    }
  }
  
  /// Create or update user document in Firestore
  static Future<bool> createOrUpdateUserDocument(Map<String, dynamic> data) async {
    try {
      final session = await getCurrentSession();
      if (session == null) return false;
      
      final userId = session['uid'];
      if (userId == null) return false;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(data, SetOptions(merge: true));
      
      print('✅ User document created/updated successfully');
      return true;
    } catch (e) {
      print('❌ Error creating/updating user document: $e');
      return false;
    }
  }
} 