import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  /// Fetches the role of a user by their UID
  static Future<String> fetchUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['role'] ?? 'user') as String;
  }

  /// Checks if the current user is an admin
  static Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final role = await fetchUserRole(user.uid);
    return role.toLowerCase() == 'admin';
  }

  /// Returns the current user's Firestore document data
  static Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  /// Fetches another user's data by UID
  static Future<Map<String, dynamic>?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Safely creates or updates a user document
  static Future<void> createOrUpdateUserDocument({
    required String uid,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();

      final baseData = {
        'uid': uid,
        'email': user.email,
        'lastUpdated': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      if (doc.exists) {
        // Update existing document
        await docRef.update(baseData);
        print('✅ User document updated for: $uid');
      } else {
        // Create new document
        await docRef.set({
          ...baseData,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'notificationsEnabled': true,
        });
        print('✅ User document created for: $uid');
      }
    } catch (e) {
      print('❌ Error creating/updating user document: $e');
      throw Exception('Failed to create user document: $e');
    }
  }

  /// Ensures a user document exists before performing operations
  static Future<bool> ensureUserDocumentExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        await createOrUpdateUserDocument(uid: uid);
      }
      return true;
    } catch (e) {
      print('❌ Error ensuring user document exists: $e');
      return false;
    }
  }
}
