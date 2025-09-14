import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_status.dart';

class PargoTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Update order status and add to tracking timeline
  static Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? description,
    String? location,
    String? updatedBy,
  }) async {
    try {
      final batch = _firestore.batch();
      
      // Update order status
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'status': newStatus.name,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy ?? 'system',
      });

      // Add tracking event to timeline
      final trackingEvent = TrackingEvent(
        status: newStatus,
        timestamp: DateTime.now(),
        description: description,
        location: location,
        updatedBy: updatedBy ?? 'system',
      );

      final timelineRef = orderRef.collection('timeline').doc();
      batch.set(timelineRef, trackingEvent.toMap());

      // If it's a pickup order, update pickup details
      if (newStatus == OrderStatus.shippedToPargo) {
        batch.update(orderRef, {
          'pargoPickupDetails.shippedAt': FieldValue.serverTimestamp(),
        });
      } else if (newStatus == OrderStatus.arrivedAtPargo) {
        batch.update(orderRef, {
          'pargoPickupDetails.arrivedAt': FieldValue.serverTimestamp(),
          'pargoPickupDetails.readyForCollection': FieldValue.serverTimestamp(),
        });
      } else if (newStatus == OrderStatus.collected) {
        batch.update(orderRef, {
          'pargoPickupDetails.collectedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ Pargo: Order status updated to ${newStatus.displayName}');
    } catch (e) {
      print('❌ Pargo: Error updating order status: $e');
      rethrow;
    }
  }

  // Get order tracking timeline
  static Stream<List<TrackingEvent>> getOrderTimeline(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .collection('timeline')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrackingEvent.fromMap(doc.data()))
            .toList());
  }

  // Generate collection QR code data
  static String generateCollectionQRData(String orderId, String orderNumber) {
    final data = {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'type': 'collection',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  // Verify collection with QR code
  static Future<bool> verifyCollection({
    required String orderId,
    required String orderNumber,
    required String verificationCode,
  }) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      
      if (!orderDoc.exists) {
        print('❌ Pargo: Order not found: $orderId');
        return false;
      }

      final orderData = orderDoc.data()!;
      
      // Verify order number matches
      if (orderData['orderNumber'] != orderNumber) {
        print('❌ Pargo: Order number mismatch');
        return false;
      }

      // Check if order is ready for collection
      if (orderData['status'] != OrderStatus.readyForCollection.name) {
        print('❌ Pargo: Order not ready for collection');
        return false;
      }

      // Update status to collected
      await updateOrderStatus(
        orderId: orderId,
        newStatus: OrderStatus.collected,
        description: 'Parcel collected by customer',
        location: orderData['pargoPickupDetails']?['pickupPointName'] ?? 'Pickup Point',
        updatedBy: 'pargo',
      );

      print('✅ Pargo: Collection verified successfully');
      return true;
    } catch (e) {
      print('❌ Pargo: Error verifying collection: $e');
      return false;
    }
  }

  // Send collection notification to buyer
  static Future<void> sendCollectionNotification(String orderId) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final buyerId = orderData['buyerId'];
      final orderNumber = orderData['orderNumber'];
      final pickupDetails = orderData['pargoPickupDetails'];

      if (pickupDetails != null) {
        // Send FCM notification to buyer
        await _firestore.collection('notifications').add({
          'userId': buyerId,
          'title': '🛍️ Ready for Collection!',
          'body': 'Your order #$orderNumber is ready for collection at ${pickupDetails['pickupPointName']}',
          'type': 'collection_ready',
          'orderId': orderId,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        print('✅ Pargo: Collection notification sent to buyer');
      }
    } catch (e) {
      print('❌ Pargo: Error sending collection notification: $e');
    }
  }

  // Generate shipping label data for seller
  static Map<String, dynamic> generateShippingLabel({
    required String orderId,
    required String orderNumber,
    required String buyerName,
    required String buyerPhone,
    required PargoPickupDetails pickupDetails,
    required List<Map<String, dynamic>> items,
  }) {
    return {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
      'pickupPoint': {
        'name': pickupDetails.pickupPointName,
        'address': pickupDetails.pickupPointAddress,
        'id': pickupDetails.pickupPointId,
      },
      'items': items,
      'shippingInstructions': 'Ship to Pargo pickup point - include order number on package',
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  // Get pickup point collection instructions
  static String getCollectionInstructions(PargoPickupDetails pickupDetails) {
    return '''
📦 Collection Instructions:

📍 Pickup Point: ${pickupDetails.pickupPointName}
🏠 Address: ${pickupDetails.pickupPointAddress}
⏰ Operating Hours: Mon-Fri 8AM-6PM, Sat 8AM-5PM

🔑 What to Bring:
• Your Order ID/Number
• Valid ID (Passport/Driver's License)
• This collection code

💡 Tips:
• Collect during operating hours
• Have your order details ready
• Ask for assistance if needed
• Keep your collection receipt

❓ Need Help? Contact: admin@omniasa.co.za
    ''';
  }

  // Calculate estimated arrival time
  static DateTime calculateEstimatedArrival(DateTime shippedAt) {
    // Add 2-3 business days for shipping to Pargo
    return shippedAt.add(const Duration(days: 3));
  }

  // Check if order is overdue for collection
  static bool isOverdueForCollection(PargoPickupDetails pickupDetails) {
    if (pickupDetails.readyForCollection == null) return false;
    
    final readyDate = pickupDetails.readyForCollection!;
    final now = DateTime.now();
    final daysSinceReady = now.difference(readyDate).inDays;
    
    // Consider overdue after 7 days
    return daysSinceReady > 7;
  }

  // Get overdue collection orders
  static Stream<QuerySnapshot> getOverdueCollectionOrders() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.readyForCollection.name)
        .where('pargoPickupDetails.readyForCollection', isLessThan: weekAgo.toIso8601String())
        .snapshots();
  }
}
