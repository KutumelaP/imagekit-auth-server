import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';
import '../services/fcm_config_service.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  String _role = 'user'; // default role
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  String? _error;
  bool _paused = false;
  bool get paused => _paused;

  User? get user => _user;
  String get role => _role;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Call this method to load current user data from Firestore
  Future<void> loadUserData() async {
    _setLoading(true);
    _clearError();
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _clearUserData();
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _user = currentUser;
        _role = data['role'] ?? 'user';
        _userProfile = data;
        _paused = data['paused'] == true;
        
        // Save FCM token for the user
        await _saveFCMToken(currentUser.uid);
        
        // Refresh notifications when user logs in
        await NotificationService().refreshNotifications();
      } else {
        _user = currentUser;
        _role = 'user';
        _userProfile = {
          'email': currentUser.email,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        };
        _paused = false;
        
        // Create the user document in Firestore since it doesn't exist
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set(_userProfile!);
        
        // Save FCM token for the new user
        await _saveFCMToken(currentUser.uid);
        
        // Refresh notifications when user logs in
        await NotificationService().refreshNotifications();
      }
    } catch (e) {
      _setError('Failed to load user data: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Call this to clear user data on logout
  void clearUser() {
    _clearUserData();
  }

  /// Update user profile data
  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    if (_user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .update(profileData);
      
      _userProfile = {...?_userProfile, ...profileData};
      notifyListeners();
    } catch (e) {
      _setError('Failed to update profile: $e');
    }
  }

  /// Check if user is a seller
  bool get isSeller => _role == 'seller';

  /// Check if user is logged in
  bool get isLoggedIn => _user != null;

  /// Check if user is an admin
  bool get isAdmin => _role == 'admin';

  /// Check if user is verified
  bool get isVerified => _userProfile?['verified'] == true;

  /// Get user display name
  String get displayName {
    if (_userProfile?['username'] != null) {
      return _userProfile!['username'];
    }
    if (_user?.displayName != null) {
      return _user!.displayName!;
    }
    if (_user?.email != null) {
      return _user!.email!.split('@')[0];
    }
    return 'User';
  }

  void setPaused(bool value) {
    _paused = value;
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void _clearUserData() {
    _user = null;
    _role = 'user';
    _userProfile = null;
    _error = null;
    _paused = false;
    notifyListeners();
  }

  /// Save FCM token to Firestore for the user
  Future<void> _saveFCMToken(String userId) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': fcmToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': _getPlatform(),
        });
        print('✅ FCM token saved for user: $userId');
      } else {
        print('⚠️ No FCM token available for user: $userId');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Get platform information
  String _getPlatform() {
    if (kIsWeb) return 'web';
    // Add more platform detection as needed
    return 'mobile';
  }
}
