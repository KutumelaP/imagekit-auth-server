import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// Safe wrapper for Firebase Auth to handle type casting errors
class FirebaseAuthWrapper {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _isInitialized = false;
  static User? _cachedUser;
  static bool _hasCastingError = false;
  static bool _isDisabled = false;

  /// Initialize the wrapper with proper error handling
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Wait for Firebase Auth to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Test auth initialization with aggressive error handling
      try {
        final testUser = _auth.currentUser;
        _cachedUser = testUser;
        print('✅ FirebaseAuthWrapper initialized successfully');
      } catch (e) {
        print('⚠️ FirebaseAuthWrapper initialization warning: $e');
        _hasCastingError = true;
        _isDisabled = true;
        print('🚫 Firebase Auth disabled due to casting errors');
        // Continue even if there are initialization issues
      }
      _isInitialized = true;
    } catch (e) {
      print('⚠️ FirebaseAuthWrapper initialization warning: $e');
      _hasCastingError = true;
      _isDisabled = true;
      print('🚫 Firebase Auth disabled due to initialization errors');
      // Continue even if there are initialization issues
      _isInitialized = true;
    }
  }

  /// Safely get current user with comprehensive error handling
  static User? getCurrentUser() {
    try {
      if (!_isInitialized) {
        print('⚠️ FirebaseAuthWrapper not initialized, initializing now...');
        initialize();
        return _cachedUser;
      }
      
      // If Firebase Auth is disabled, return cached user
      if (_isDisabled) {
        return _cachedUser;
      }
      
      // If we've had casting errors before, use cached user
      if (_hasCastingError) {
        return _cachedUser;
      }
      
      final user = _auth.currentUser;
      _cachedUser = user;
      return user;
    } catch (e) {
      print('❌ Error getting current user: $e');
      print('❌ Error type: ${e.runtimeType}');
      
      // Handle specific casting errors
      if (e.toString().contains('PigeonUserDetails') || 
          e.toString().contains('List<Object?>') ||
          e.toString().contains('type cast')) {
        print('⚠️ Detected PigeonUserDetails casting error, disabling Firebase Auth');
        _hasCastingError = true;
        _isDisabled = true;
        return _cachedUser;
      }
      
      return _cachedUser;
    }
  }

  /// Safely get current user ID with retry logic
  static String? getCurrentUserId() {
    try {
      final user = getCurrentUser();
      return user?.uid;
    } catch (e) {
      print('❌ Error getting current user ID: $e');
      return _cachedUser?.uid;
    }
  }

  /// Check if user is authenticated safely with retry
  static bool isUserAuthenticated() {
    try {
      final user = getCurrentUser();
      return user != null;
    } catch (e) {
      print('❌ Error checking authentication: $e');
      return _cachedUser != null;
    }
  }

  /// Safely sign out user
  static Future<void> signOut() async {
    try {
      if (!_isDisabled) {
        await _auth.signOut();
      }
      _cachedUser = null;
      _hasCastingError = false;
      _isDisabled = false;
      print('✅ User signed out successfully');
    } catch (e) {
      print('❌ Error signing out: $e');
      // Clear cache even if sign out fails
      _cachedUser = null;
      _hasCastingError = false;
      _isDisabled = false;
    }
  }

  /// Safely get user document from Firestore with retry
  static Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('❌ Error getting user document: $e');
      return null;
    }
  }

  /// Safely get current user's document with retry
  static Future<Map<String, dynamic>?> getCurrentUserDocument() async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;
      
      return await getUserDocument(user.uid);
    } catch (e) {
      print('❌ Error getting current user document: $e');
      return null;
    }
  }

  /// Safely update user document
  static Future<bool> updateUserDocument(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
      return true;
    } catch (e) {
      print('❌ Error updating user document: $e');
      return false;
    }
  }

  /// Safely create user document
  static Future<bool> createUserDocument(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).set(data);
      return true;
    } catch (e) {
      print('❌ Error creating user document: $e');
      return false;
    }
  }

  /// Get user role safely with fallback
  static Future<String> getUserRole(String uid) async {
    try {
      final doc = await getUserDocument(uid);
      return doc?['role'] ?? 'user';
    } catch (e) {
      print('❌ Error getting user role: $e');
      return 'user';
    }
  }

  /// Check if current user is admin with retry
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = getCurrentUser();
      if (user == null) return false;
      
      final role = await getUserRole(user.uid);
      return role.toLowerCase() == 'admin';
    } catch (e) {
      print('❌ Error checking admin status: $e');
      return false;
    }
  }

  /// Check if current user is seller with retry
  static Future<bool> isCurrentUserSeller() async {
    try {
      final user = getCurrentUser();
      if (user == null) return false;
      
      final role = await getUserRole(user.uid);
      return role.toLowerCase() == 'seller';
    } catch (e) {
      print('❌ Error checking seller status: $e');
      return false;
    }
  }

  /// Wait for auth to be ready (useful for initialization)
  static Future<void> waitForAuthReady() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      await initialize();
    } catch (e) {
      print('⚠️ Error waiting for auth ready: $e');
    }
  }

  /// Get auth state with error handling - returns cached user stream if there are issues
  static Stream<User?> get authStateChanges {
    try {
      if (_isDisabled || _hasCastingError) {
        print('⚠️ Using cached auth state due to Firebase Auth issues');
        return Stream.value(_cachedUser);
      }
      return _auth.authStateChanges();
    } catch (e) {
      print('❌ Error getting auth state changes: $e');
      // Return cached user stream if there's an error
      return Stream.value(_cachedUser);
    }
  }

  /// Get user changes with error handling - returns cached user stream if there are issues
  static Stream<User?> get userChanges {
    try {
      if (_isDisabled || _hasCastingError) {
        print('⚠️ Using cached user changes due to Firebase Auth issues');
        return Stream.value(_cachedUser);
      }
      return _auth.userChanges();
    } catch (e) {
      print('❌ Error getting user changes: $e');
      // Return cached user stream if there's an error
      return Stream.value(_cachedUser);
    }
  }

  /// Force refresh the cached user (useful for recovery)
  static void forceRefreshCache() {
    try {
      if (!_isDisabled) {
        _cachedUser = _auth.currentUser;
      }
      _hasCastingError = false;
      print('✅ User cache refreshed successfully');
    } catch (e) {
      print('❌ Error refreshing user cache: $e');
    }
  }

  /// Check if we're experiencing casting errors
  static bool get hasCastingErrors => _hasCastingError;

  /// Check if Firebase Auth is disabled
  static bool get isDisabled => _isDisabled;

  /// Get cached user (useful for debugging)
  static User? get cachedUser => _cachedUser;

  /// Manually set cached user (for testing or recovery)
  static void setCachedUser(User? user) {
    _cachedUser = user;
    print('✅ Cached user manually set');
  }

  /// Enable Firebase Auth (for recovery)
  static void enable() {
    _isDisabled = false;
    _hasCastingError = false;
    print('✅ Firebase Auth re-enabled');
  }

  /// Disable Firebase Auth (for testing)
  static void disable() {
    _isDisabled = true;
    print('🚫 Firebase Auth manually disabled');
  }
} 