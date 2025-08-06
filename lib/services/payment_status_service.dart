import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PaymentStatusService {
  static final PaymentStatusService _instance = PaymentStatusService._internal();
  factory PaymentStatusService() => _instance;
  PaymentStatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<DocumentSnapshot>? _orderSubscription;
  StreamSubscription<QuerySnapshot>? _paymentUpdatesSubscription;
  
  final Map<String, StreamController<Map<String, dynamic>>> _paymentControllers = {};
  final Map<String, Timer> _paymentTimeouts = {};

  /// Start monitoring payment status for an order
  Future<void> startPaymentMonitoring(String orderId, String paymentId) async {
    try {
      print('🔍 DEBUG: Starting payment monitoring for order: $orderId, payment: $paymentId');
      
      // Create a stream controller for this payment
      if (!_paymentControllers.containsKey(orderId)) {
        _paymentControllers[orderId] = StreamController<Map<String, dynamic>>.broadcast();
      }

      // Monitor order document for payment status changes
      _orderSubscription = _firestore
          .collection('orders')
          .doc(orderId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data()!;
          final paymentStatus = data['paymentStatus'] ?? 'pending';
          final orderStatus = data['orderStatus'] ?? 'pending';
          
          print('🔍 DEBUG: Payment status update - Order: $orderId, Status: $paymentStatus');
          
          _paymentControllers[orderId]?.add({
            'orderId': orderId,
            'paymentId': paymentId,
            'paymentStatus': paymentStatus,
            'orderStatus': orderStatus,
            'amount': data['paymentAmount'] ?? 0.0,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      });

      // Monitor payment webhooks collection
      _paymentUpdatesSubscription = _firestore
          .collection('payment_webhooks')
          .where('orderId', isEqualTo: orderId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final webhookData = snapshot.docs.first.data();
          print('🔍 DEBUG: Payment webhook received for order: $orderId');
          
          _paymentControllers[orderId]?.add({
            'orderId': orderId,
            'paymentId': webhookData['paymentId'],
            'paymentStatus': webhookData['status'],
            'amount': webhookData['amount'],
            'timestamp': webhookData['timestamp']?.toDate()?.toIso8601String(),
            'source': 'webhook',
          });
        }
      });

      // Set up payment timeout
      _setupPaymentTimeout(orderId);

    } catch (e) {
      print('🔍 DEBUG: Error starting payment monitoring: $e');
    }
  }

  /// Set up payment timeout monitoring
  void _setupPaymentTimeout(String orderId) {
    // Cancel existing timeout
    _paymentTimeouts[orderId]?.cancel();
    
    // Set new timeout (30 minutes)
    _paymentTimeouts[orderId] = Timer(const Duration(minutes: 30), () {
      print('🔍 DEBUG: Payment timeout reached for order: $orderId');
      _paymentControllers[orderId]?.add({
        'orderId': orderId,
        'paymentStatus': 'timeout',
        'message': 'Payment timeout - please try again',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Get payment status stream for an order
  Stream<Map<String, dynamic>> getPaymentStatusStream(String orderId) {
    if (!_paymentControllers.containsKey(orderId)) {
      _paymentControllers[orderId] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _paymentControllers[orderId]!.stream;
  }

  /// Manually check payment status
  Future<Map<String, dynamic>> checkPaymentStatus(String orderId, String paymentId) async {
    try {
      // Check order document
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      
      if (orderDoc.exists) {
        final data = orderDoc.data()!;
        return {
          'success': true,
          'orderId': orderId,
          'paymentId': paymentId,
          'paymentStatus': data['paymentStatus'] ?? 'pending',
          'orderStatus': data['orderStatus'] ?? 'pending',
          'amount': data['paymentAmount'] ?? 0.0,
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'success': false,
          'error': 'Order not found',
          'orderId': orderId,
        };
      }
    } catch (e) {
      print('🔍 DEBUG: Error checking payment status: $e');
      return {
        'success': false,
        'error': 'Failed to check payment status: $e',
        'orderId': orderId,
      };
    }
  }

  /// Update payment status manually
  Future<bool> updatePaymentStatus(String orderId, String paymentId, String status) async {
    try {
      await _firestore.collection('payment_status_updates').add({
        'orderId': orderId,
        'paymentId': paymentId,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('🔍 DEBUG: Payment status update queued for order: $orderId, status: $status');
      return true;
    } catch (e) {
      print('🔍 DEBUG: Error updating payment status: $e');
      return false;
    }
  }

  /// Stop monitoring payment status
  void stopPaymentMonitoring(String orderId) {
    print('🔍 DEBUG: Stopping payment monitoring for order: $orderId');
    
    _orderSubscription?.cancel();
    _paymentUpdatesSubscription?.cancel();
    _paymentTimeouts[orderId]?.cancel();
    _paymentControllers[orderId]?.close();
    
    _paymentControllers.remove(orderId);
    _paymentTimeouts.remove(orderId);
  }

  /// Get payment history for a user
  Future<List<Map<String, dynamic>>> getPaymentHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('paymentStatus', whereIn: ['completed', 'failed', 'pending'])
          .orderBy('paymentStatus')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'orderId': doc.id,
          'paymentId': data['paymentId'],
          'paymentStatus': data['paymentStatus'],
          'orderStatus': data['orderStatus'],
          'amount': data['paymentAmount'] ?? 0.0,
          'timestamp': data['timestamp']?.toDate()?.toIso8601String(),
          'storeName': data['storeName'],
        };
      }).toList();
    } catch (e) {
      print('🔍 DEBUG: Error getting payment history: $e');
      return [];
    }
  }

  /// Get payment analytics
  Future<Map<String, dynamic>> getPaymentAnalytics(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .get();

      int totalPayments = 0;
      int successfulPayments = 0;
      int failedPayments = 0;
      double totalAmount = 0.0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final paymentStatus = data['paymentStatus'];
        final amount = (data['paymentAmount'] ?? 0.0).toDouble();

        if (paymentStatus != null) {
          totalPayments++;
          totalAmount += amount;

          if (paymentStatus == 'completed') {
            successfulPayments++;
          } else if (paymentStatus == 'failed') {
            failedPayments++;
          }
        }
      }

      return {
        'totalPayments': totalPayments,
        'successfulPayments': successfulPayments,
        'failedPayments': failedPayments,
        'successRate': totalPayments > 0 ? (successfulPayments / totalPayments) * 100 : 0.0,
        'totalAmount': totalAmount,
        'averageAmount': totalPayments > 0 ? totalAmount / totalPayments : 0.0,
      };
    } catch (e) {
      print('🔍 DEBUG: Error getting payment analytics: $e');
      return {};
    }
  }

  /// Dispose of all resources
  void dispose() {
    _orderSubscription?.cancel();
    _paymentUpdatesSubscription?.cancel();
    
    for (final timer in _paymentTimeouts.values) {
      timer.cancel();
    }
    _paymentTimeouts.clear();
    
    for (final controller in _paymentControllers.values) {
      controller.close();
    }
    _paymentControllers.clear();
  }
} 