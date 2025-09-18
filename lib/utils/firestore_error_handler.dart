import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class to handle Firebase Firestore errors gracefully
class FirestoreErrorHandler {
  /// Wraps a Firestore operation with error handling for internal assertion failures
  static Future<T?> safeFirestoreOperation<T>(
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 10),
    String? operationName,
  }) async {
    try {
      final result = await operation().timeout(timeout);
      return result;
    } catch (error) {
      print('❌ Firestore operation failed${operationName != null ? ' ($operationName)' : ''}: $error');
      
      // Check for Firebase initialization failures
      if (error.toString().contains('No Firebase App') || 
          error.toString().contains('Firebase.initializeApp') ||
          error.toString().contains('channel-error')) {
        print('🚨 Firebase initialization error detected - returning null');
        return null;
      }
      
      // Check for Firestore internal assertion failures
      if (error.toString().contains('INTERNAL ASSERTION FAILED') || 
          error.toString().contains('Unexpected state') ||
          error.toString().contains('TargetState')) {
        print('🚨 Firestore internal assertion error detected - returning null');
        return null;
      }
      
      // Re-throw other errors
      rethrow;
    }
  }
  
  /// Safe query execution with error handling
  static Future<QuerySnapshot<Map<String, dynamic>>?> safeQuery(
    Query<Map<String, dynamic>> query, {
    Duration timeout = const Duration(seconds: 10),
    String? operationName,
  }) async {
    return await safeFirestoreOperation<QuerySnapshot<Map<String, dynamic>>>(
      () => query.get(),
      timeout: timeout,
      operationName: operationName,
    );
  }
  
  /// Safe document get with error handling
  static Future<DocumentSnapshot<Map<String, dynamic>>?> safeGetDoc(
    DocumentReference<Map<String, dynamic>> docRef, {
    Duration timeout = const Duration(seconds: 10),
    String? operationName,
  }) async {
    return await safeFirestoreOperation<DocumentSnapshot<Map<String, dynamic>>>(
      () => docRef.get(),
      timeout: timeout,
      operationName: operationName,
    );
  }
  
  /// Safe document set with error handling
  static Future<bool> safeSetDoc(
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 10),
    String? operationName,
  }) async {
    try {
      await docRef.set(data).timeout(timeout);
      return true;
    } catch (error) {
      print('❌ Firestore set operation failed${operationName != null ? ' ($operationName)' : ''}: $error');
      
      // Check for Firestore internal assertion failures
      if (error.toString().contains('INTERNAL ASSERTION FAILED') || 
          error.toString().contains('Unexpected state') ||
          error.toString().contains('TargetState')) {
        print('🚨 Firestore internal assertion error detected - operation failed');
        return false;
      }
      
      // Re-throw other errors
      rethrow;
    }
  }
  
  /// Safe document update with error handling
  static Future<bool> safeUpdateDoc(
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 10),
    String? operationName,
  }) async {
    try {
      await docRef.update(data).timeout(timeout);
      return true;
    } catch (error) {
      print('❌ Firestore update operation failed${operationName != null ? ' ($operationName)' : ''}: $error');
      
      // Check for Firestore internal assertion failures
      if (error.toString().contains('INTERNAL ASSERTION FAILED') || 
          error.toString().contains('Unexpected state') ||
          error.toString().contains('TargetState')) {
        print('🚨 Firestore internal assertion error detected - operation failed');
        return false;
      }
      
      // Re-throw other errors
      rethrow;
    }
  }
  
  /// Safe batch operation with error handling
  static Future<bool> safeBatch(
    WriteBatch batch, {
    Duration timeout = const Duration(seconds: 15),
    String? operationName,
  }) async {
    try {
      await batch.commit().timeout(timeout);
      return true;
    } catch (error) {
      print('❌ Firestore batch operation failed${operationName != null ? ' ($operationName)' : ''}: $error');
      
      // Check for Firestore internal assertion failures
      if (error.toString().contains('INTERNAL ASSERTION FAILED') || 
          error.toString().contains('Unexpected state') ||
          error.toString().contains('TargetState')) {
        print('🚨 Firestore internal assertion error detected - operation failed');
        return false;
      }
      
      // Re-throw other errors
      rethrow;
    }
  }
}
