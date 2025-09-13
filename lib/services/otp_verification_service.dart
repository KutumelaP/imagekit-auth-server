import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OTPVerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Generate OTP for delivery verification
  static Future<String> generateDeliveryOTP({
    required String orderId,
    required String buyerId,
    required String sellerId,
    int? customOTP,
  }) async {
    try {
      // Generate 6-digit OTP
      final otp = customOTP?.toString().padLeft(6, '0') ?? 
                  (100000 + Random().nextInt(900000)).toString();
      
      // Store OTP in Firestore with expiration
      await _firestore.collection('delivery_otps').doc(orderId).set({
        'otp': otp,
        'orderId': orderId,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'status': 'active', // active, used, expired
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
        'attempts': 0,
        'maxAttempts': 5,
      });
      
      print('🔐 Generated delivery OTP: $otp for order: $orderId');
      return otp;
    } catch (e) {
      print('❌ Error generating OTP: $e');
      throw Exception('Failed to generate delivery OTP');
    }
  }
  
  /// Verify OTP during delivery handover
  static Future<Map<String, dynamic>> verifyDeliveryOTP({
    required String orderId,
    required String enteredOTP,
    required String? delivererId,
    Map<String, dynamic>? location,
  }) async {
    try {
      final otpDoc = await _firestore.collection('delivery_otps').doc(orderId).get();
      
      if (!otpDoc.exists) {
        return {
          'success': false,
          'message': 'Invalid order or OTP not found',
          'code': 'OTP_NOT_FOUND'
        };
      }
      
      final otpData = otpDoc.data()!;
      final storedOTP = otpData['otp'] as String;
      final status = otpData['status'] as String;
      final expiresAt = otpData['expiresAt'] as Timestamp;
      final attempts = (otpData['attempts'] as int?) ?? 0;
      final maxAttempts = (otpData['maxAttempts'] as int?) ?? 5;
      
      // Check if OTP is already used
      if (status != 'active') {
        return {
          'success': false,
          'message': 'OTP has already been used',
          'code': 'OTP_ALREADY_USED'
        };
      }
      
      // Check if OTP is expired
      if (DateTime.now().isAfter(expiresAt.toDate())) {
        await _firestore.collection('delivery_otps').doc(orderId).update({
          'status': 'expired'
        });
        return {
          'success': false,
          'message': 'OTP has expired',
          'code': 'OTP_EXPIRED'
        };
      }
      
      // Check attempts limit
      if (attempts >= maxAttempts) {
        await _firestore.collection('delivery_otps').doc(orderId).update({
          'status': 'blocked'
        });
        return {
          'success': false,
          'message': 'Too many failed attempts. OTP blocked.',
          'code': 'OTP_BLOCKED'
        };
      }
      
      // Verify OTP
      if (enteredOTP != storedOTP) {
        // Increment failed attempts
        await _firestore.collection('delivery_otps').doc(orderId).update({
          'attempts': FieldValue.increment(1),
          'lastAttemptAt': FieldValue.serverTimestamp(),
        });
        
        return {
          'success': false,
          'message': 'Invalid OTP. ${maxAttempts - attempts - 1} attempts remaining.',
          'code': 'INVALID_OTP',
          'attemptsRemaining': maxAttempts - attempts - 1
        };
      }
      
      // OTP is valid - mark as used and update order
      await _firestore.collection('delivery_otps').doc(orderId).update({
        'status': 'used',
        'verifiedAt': FieldValue.serverTimestamp(),
        'delivererId': delivererId,
        'deliveryLocation': location,
      });
      
      // Update order status to delivered
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'deliveryVerification': {
          'otpVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
          'delivererId': delivererId,
          'location': location,
        }
      });
      
      return {
        'success': true,
        'message': 'Delivery verified successfully!',
        'code': 'DELIVERY_VERIFIED',
        'orderId': orderId,
        'verifiedAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      return {
        'success': false,
        'message': 'Verification failed. Please try again.',
        'code': 'VERIFICATION_ERROR'
      };
    }
  }
  
  /// Get OTP status for order
  static Future<Map<String, dynamic>?> getOTPStatus(String orderId) async {
    try {
      final doc = await _firestore.collection('delivery_otps').doc(orderId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return {
        'status': data['status'],
        'attempts': data['attempts'] ?? 0,
        'maxAttempts': data['maxAttempts'] ?? 5,
        'expiresAt': data['expiresAt'],
        'createdAt': data['createdAt'],
      };
    } catch (e) {
      print('❌ Error getting OTP status: $e');
      return null;
    }
  }
  
  /// Resend OTP (for customer support)
  static Future<String> resendOTP({
    required String orderId,
    required String adminId,
  }) async {
    try {
      // Verify admin permission
      final adminDoc = await _firestore.collection('users').doc(adminId).get();
      if (!adminDoc.exists || adminDoc.data()?['userType'] != 'admin') {
        throw Exception('Unauthorized: Admin access required');
      }
      
      // Invalidate old OTP
      await _firestore.collection('delivery_otps').doc(orderId).update({
        'status': 'resent'
      });
      
      // Get order details
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }
      
      final orderData = orderDoc.data()!;
      
      // Generate new OTP
      return await generateDeliveryOTP(
        orderId: orderId,
        buyerId: orderData['buyerId'],
        sellerId: orderData['sellerId'],
      );
    } catch (e) {
      print('❌ Error resending OTP: $e');
      throw Exception('Failed to resend OTP');
    }
  }
}
