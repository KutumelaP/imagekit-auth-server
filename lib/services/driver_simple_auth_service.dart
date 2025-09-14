import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverSimpleAuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Simple driver login using name as username and phone as password
  static Future<Map<String, dynamic>> driverLogin({
    required String driverName,
    required String driverPhone,
  }) async {
    try {
      print('🔍 Attempting driver login: $driverName / $driverPhone');

      // Search all sellers for a driver matching name and phone
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (final userDoc in usersSnapshot.docs) {
        final sellerId = userDoc.id;
        
        // Check this seller's drivers
        final driversQuery = await _firestore
            .collection('users')
            .doc(sellerId)
            .collection('drivers')
            .get();

        for (final driverDoc in driversQuery.docs) {
          final driverData = driverDoc.data();
          final storedName = (driverData['name'] as String?)?.toLowerCase().trim();
          final storedPhone = (driverData['phone'] as String?)?.replaceAll(RegExp(r'[^\d]'), '');
          final inputName = driverName.toLowerCase().trim();
          final inputPhone = driverPhone.replaceAll(RegExp(r'[^\d]'), '');
          
          // Match both name and phone
          if (storedName == inputName && storedPhone == inputPhone) {
            print('✅ Driver found: $storedName in seller $sellerId');
            
            // Create or sign in to Firebase Auth with driver email
            final driverEmail = _generateDriverEmail(driverName, sellerId);
            final driverPassword = _generateDriverPassword(driverName, driverPhone);
            final result = await _signInOrCreateDriverAccount(
              email: driverEmail,
              password: driverPassword,
              driverData: driverData,
              sellerId: sellerId,
              driverDocId: driverDoc.id,
            );
            
            return result;
          }
        }
      }

      print('❌ No driver found with name: $driverName and phone: $driverPhone');
      return {
        'success': false,
        'message': 'Driver not found. Please check your name and phone number, or ask your seller to add you as a driver.',
      };
      
    } catch (e) {
      print('❌ Error during driver login: $e');
      return {
        'success': false,
        'message': 'Login error: $e',
      };
    }
  }

  /// Generate consistent email for driver
  static String _generateDriverEmail(String driverName, String sellerId) {
    final cleanName = driverName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final safeName = cleanName.isEmpty ? 'driver' : cleanName;
    final sellerSanitized = sellerId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final idPart = sellerSanitized.isEmpty
        ? '000000'
        : (sellerSanitized.length >= 8 ? sellerSanitized.substring(0, 8) : sellerSanitized.padRight(8, '0'));
    // Use production domain for driver emails
    return '$safeName.driver.$idPart@omniasa.co.za';
  }

  /// Generate a strong password for driver authentication
  static String _generateDriverPassword(String driverName, String driverPhone) {
    // Create a strong password that meets Firebase Auth requirements
    final cleanName = driverName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanPhone = driverPhone.replaceAll(RegExp(r'[^\d]'), '');
    final capitalizedName = cleanName.isNotEmpty 
        ? cleanName[0].toUpperCase() + cleanName.substring(1)
        : 'Driver';
    return 'Driver${capitalizedName}${cleanPhone}!';
  }

  /// Sign in or create Firebase Auth account for driver
  static Future<Map<String, dynamic>> _signInOrCreateDriverAccount({
    required String email,
    required String password,
    required Map<String, dynamic> driverData,
    required String sellerId,
    required String driverDocId,
  }) async {
    try {
      UserCredential? userCredential;
      
      print('🔐 Attempting auth with email: $email');
      print('🔐 Password length: ${password.length}');
      
      // Try to sign in first
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Existing driver account signed in');
      } on FirebaseAuthException catch (e) {
        print('🔍 Auth error: ${e.code} - ${e.message}');
        
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          // Create new account with provided email
          try {
            userCredential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            print('✅ New driver account created');
            if (userCredential.user != null) {
              await userCredential.user!.updateDisplayName(driverData['name']);
            }
          } on FirebaseAuthException catch (createError) {
            print('❌ Account creation failed: ${createError.code} - ${createError.message}');
            
            if (createError.code == 'invalid-email' || createError.code == 'invalid-credential') {
              // Use a more robust fallback with proper domain
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final driverName = driverData['name']?.toString() ?? 'driver';
              final cleanName = driverName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
              final safeName = cleanName.isEmpty ? 'driver' : cleanName;
              final fallbackEmail = '$safeName.driver.$timestamp@omniasa.co.za';
              final fallbackPassword = 'omniaSADriver${timestamp}!';
              
              print('🔄 Trying robust fallback: $fallbackEmail');
              userCredential = await _auth.createUserWithEmailAndPassword(
                email: fallbackEmail,
                password: fallbackPassword,
              );
              print('✅ Robust fallback account created');
              if (userCredential.user != null) {
                await userCredential.user!.updateDisplayName(driverData['name']);
              }
            } else {
              throw createError;
            }
          }
        } else {
          throw e;
        }
      }

      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        // Update user document with driver info
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'name': driverData['name'],
          'phone': driverData['phone'],
          'userType': 'driver',
          'roles': ['driver'],
          'linkedToSeller': sellerId,
          'driverDocId': driverDocId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Link the driver document to the user and set as online
        await _firestore
            .collection('users')
            .doc(sellerId)
            .collection('drivers')
            .doc(driverDocId)
            .update({
          'userId': user.uid,
          'linkedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isOnline': true, // Set driver as online when they log in
          'isAvailable': true, // Also set as available
        });

        return {
          'success': true,
          'message': 'Driver login successful!',
          'userId': user.uid,
          'sellerId': sellerId,
          'driverData': driverData,
        };
      }

      return {
        'success': false,
        'message': 'Failed to authenticate driver',
      };
      
    } catch (e) {
      print('❌ Error creating/signing in driver account: $e');
      return {
        'success': false,
        'message': 'Authentication error: $e',
      };
    }
  }

  /// Check if current user is a driver and get their profile
  static Future<Map<String, dynamic>?> getCurrentDriverProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      if (userData['userType'] != 'driver') return null;

      final sellerId = userData['linkedToSeller'];
      final driverDocId = userData['driverDocId'];

      if (sellerId != null && driverDocId != null) {
        final driverDoc = await _firestore
            .collection('users')
            .doc(sellerId)
            .collection('drivers')
            .doc(driverDocId)
            .get();

        if (driverDoc.exists) {
          return {
            'driverType': 'seller_owned',
            'driverId': user.uid,
            'sellerId': sellerId,
            'driverDocId': driverDocId,
            'driverData': driverDoc.data(),
            'source': 'users/$sellerId/drivers',
          };
        }
      }

      return null;
    } catch (e) {
      print('❌ Error getting driver profile: $e');
      return null;
    }
  }

  /// Logout driver
  static Future<void> driverLogout() async {
    try {
      await _auth.signOut();
      print('✅ Driver logged out');
    } catch (e) {
      print('❌ Error logging out driver: $e');
    }
  }
}
