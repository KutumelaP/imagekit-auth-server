import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID safely
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Check if user is authenticated
  static bool isUserAuthenticated() {
    return _auth.currentUser != null;
  }

  // Safe document reference with user check
  static DocumentReference? getUserDocument(String collection, String documentId) {
    final userId = getCurrentUserId();
    if (userId == null) return null;
    
    return _firestore.collection(collection).doc(userId).collection(documentId).doc('items');
  }

  // Safe collection reference with user check
  static CollectionReference? getUserCollection(String collection) {
    final userId = getCurrentUserId();
    if (userId == null) return null;
    
    return _firestore.collection(collection).doc(userId).collection('cart');
  }

  // Handle Firestore errors gracefully
  static String handleFirestoreError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Access denied. Please log in to continue.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        case 'not-found':
          return 'Data not found.';
        case 'already-exists':
          return 'Item already exists.';
        case 'resource-exhausted':
          return 'Service limit exceeded. Please try again later.';
        case 'failed-precondition':
          return 'Operation failed. Please try again.';
        case 'aborted':
          return 'Operation was cancelled.';
        case 'out-of-range':
          return 'Invalid data provided.';
        case 'unimplemented':
          return 'Feature not available.';
        case 'internal':
          return 'Internal error. Please try again.';
        case 'data-loss':
          return 'Data loss occurred. Please try again.';
        case 'unauthenticated':
          return 'Please log in to continue.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    return 'An unexpected error occurred.';
  }

  // Safe write operation with error handling
  static Future<bool> safeWrite({
    required String collection,
    required String document,
    required Map<String, dynamic> data,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw FirebaseException(
          plugin: 'firestore',
          code: 'unauthenticated',
          message: 'User not authenticated',
        );
      }

      await _firestore
          .collection(collection)
          .doc(userId)
          .collection(document)
          .doc('items')
          .set(data);
      
      return true;
    } catch (e) {
      print('Firestore write error: $e');
      return false;
    }
  }

  // Safe read operation with error handling
  static Future<Map<String, dynamic>?> safeRead({
    required String collection,
    required String document,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw FirebaseException(
          plugin: 'firestore',
          code: 'unauthenticated',
          message: 'User not authenticated',
        );
      }

      final doc = await _firestore
          .collection(collection)
          .doc(userId)
          .collection(document)
          .doc('items')
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
      
      return null;
    } catch (e) {
      print('Firestore read error: $e');
      return null;
    }
  }
} 