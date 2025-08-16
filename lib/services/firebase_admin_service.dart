import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FirebaseAdminService {
  static final FirebaseAdminService _instance = FirebaseAdminService._internal();
  factory FirebaseAdminService() => _instance;
  FirebaseAdminService._internal();

  // Client never holds FCM server keys; push is sent via Cloud Functions by enqueuing to Firestore.

  /// Send push via your Node server (no Functions required)
  Future<bool> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      print('🔔 Sending push notification via server...');
      final serverUrl = const String.fromEnvironment('NOTIFY_SERVER_URL', defaultValue: 'http://localhost:3000');
      final payload = {
        'token': fcmToken,
        'title': title,
        'body': body,
        if (imageUrl != null) 'image': imageUrl,
        'data': data ?? {},
      };

      final uri = Uri.parse('$serverUrl/notify/send');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      print('❌ Server push failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('❌ Error sending push notification: $e');
      return false;
    }
  }

  /// Send notification to a specific user
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      print('🔔 Sending notification to user: $userId');
      
      // Get user's FCM token from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print('❌ User document not found: $userId');
        return false;
      }

      final fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken == null) {
        print('❌ No FCM token found for user: $userId');
        // Still create in-app notification even without FCM token
        print('🔔 Creating in-app notification only');
      } else {
        print('🔔 FCM token found, attempting push notification');
        // Try direct push via server (if configured)
        final pushed = await sendPushNotification(
          fcmToken: fcmToken,
          title: title,
          body: body,
          data: data,
          imageUrl: imageUrl,
        );
        // Fallback: enqueue to Cloud Function trigger to ensure delivery
        if (!pushed) {
          print('⚠️ Direct push failed or server unavailable, enqueuing Firestore push');
          await FirebaseFirestore.instance.collection('push_notifications').add({
            'to': fcmToken,
            'notification': {
              'title': title,
              'body': body,
              if (imageUrl != null) 'image': imageUrl,
            },
            'data': data ?? {},
            'userId': userId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      // Always create in-app notification in Firestore
      await _createInAppNotification(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );

      return true;
    } catch (e) {
      print('❌ Error sending notification to user: $e');
      return false;
    }
  }

  /// Send notification to multiple users
  Future<bool> sendNotificationToMultipleUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      print('🔔 Sending notification to ${userIds.length} users');
      
      bool allSuccess = true;
      
      for (String userId in userIds) {
        final success = await sendNotificationToUser(
          userId: userId,
          title: title,
          body: body,
          data: data,
          imageUrl: imageUrl,
        );
        
        if (!success) {
          allSuccess = false;
        }
      }
      
      return allSuccess;
    } catch (e) {
      print('❌ Error sending notification to multiple users: $e');
      return false;
    }
  }

  /// Send new order notification to seller
  Future<bool> sendNewOrderNotificationToSeller({
    required String sellerId,
    required String orderId,
    required String orderNumber,
    required double totalPrice,
    required String buyerName,
  }) async {
    try {
      final title = 'New Order Received! 🎉';
      final body = 'Order ${_formatOrderNumber(orderNumber)} from $buyerName - R${totalPrice.toStringAsFixed(2)}';

      final data = {
        'type': 'new_order_seller',
        'orderId': orderId,
        'orderNumber': orderNumber,
        'totalPrice': totalPrice.toString(),
        'buyerName': buyerName,
      };

      return await sendNotificationToUser(
        userId: sellerId,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending new order notification to seller: $e');
      return false;
    }
  }

  /// Send order confirmation notification to buyer
  Future<bool> sendOrderConfirmationNotificationToBuyer({
    required String buyerId,
    required String orderId,
    required String orderNumber,
    required double totalPrice,
    required String sellerName,
  }) async {
    try {
      final title = 'Order Confirmed! ✅';
      final body = 'Your order ${_formatOrderNumber(orderNumber)} has been confirmed by $sellerName';

      final data = {
        'type': 'new_order_buyer',
        'orderId': orderId,
        'orderNumber': orderNumber,
        'totalPrice': totalPrice.toString(),
        'sellerName': sellerName,
      };

      return await sendNotificationToUser(
        userId: buyerId,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending order confirmation notification to buyer: $e');
      return false;
    }
  }

  /// Send delivery notification
  Future<bool> sendDeliveryNotification({
    required String userId,
    required String orderId,
    required String orderNumber,
    required String deliveryStatus,
  }) async {
    try {
      final title = 'Delivery Update 📦';
      final body = 'Order ${_formatOrderNumber(orderNumber)}: $deliveryStatus';

      final data = {
        'type': 'delivery_update',
        'orderId': orderId,
        'orderNumber': orderNumber,
        'deliveryStatus': deliveryStatus,
      };

      return await sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending delivery notification: $e');
      return false;
    }
  }

  /// Send promotional notification
  Future<bool> sendPromotionalNotification({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      return await sendNotificationToMultipleUsers(
        userIds: userIds,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending promotional notification: $e');
      return false;
    }
  }

  /// Create in-app notification in Firestore
  Future<void> _createInAppNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': data?['type'] ?? 'general',
        'data': data ?? {},
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ In-app notification created');
    } catch (e) {
      print('❌ Error creating in-app notification: $e');
    }
  }

  /// Send order status notification
  Future<bool> sendOrderStatusNotification({
    required String userId,
    required String orderId,
    required String orderNumber,
    required String status,
    required double totalPrice,
  }) async {
    try {
      final title = 'Order Status Updated 📦';
      final body = 'Order ${_formatOrderNumber(orderNumber)} is now $status';

      final data = {
        'type': 'order_status',
        'orderId': orderId,
        'orderNumber': orderNumber,
        'status': status,
        'totalPrice': totalPrice.toString(),
      };

      return await sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending order status notification: $e');
      return false;
    }
  }

  /// Send chat notification
  Future<bool> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    try {
      final title = 'New message from $senderName';
      final body = message.length > 50 ? '${message.substring(0, 50)}...' : message;

      final data = {
        'type': 'chat_message',
        'chatId': chatId,
        'senderId': FirebaseAuth.instance.currentUser?.uid,
      };

      return await sendNotificationToUser(
        userId: recipientId,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending chat notification: $e');
      return false;
    }
  }

  /// Format order number for display
  String _formatOrderNumber(String orderNumber) {
    if (orderNumber.length > 8) {
      return '#${orderNumber.substring(0, 8)}...';
    }
    return '#$orderNumber';
  }


} 