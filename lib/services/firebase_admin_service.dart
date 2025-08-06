import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FirebaseAdminService {
  static final FirebaseAdminService _instance = FirebaseAdminService._internal();
  factory FirebaseAdminService() => _instance;
  FirebaseAdminService._internal();

  // Firebase project configuration
  static const String _projectId = 'marketplace-8d6bd';
  
  // FCM Server Key - You'll need to add this from Firebase Console
  // Go to Project Settings > Cloud Messaging > Server key
  static const String _fcmServerKey = 'YOUR_FCM_SERVER_KEY_HERE'; // Replace with your actual server key

  /// Send push notification using FCM HTTP API
  Future<bool> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      print('🔔 Sending push notification...');
      print('🔔 Token: ${fcmToken.substring(0, 20)}...');
      print('🔔 Title: $title');
      print('🔔 Body: $body');

      // Check if FCM server key is configured
      if (_fcmServerKey == 'YOUR_FCM_SERVER_KEY_HERE') {
        print('⚠️ FCM Server Key not configured. Creating in-app notification only.');
        print('📝 To enable push notifications:');
        print('   1. Go to Firebase Console > Project Settings > Cloud Messaging');
        print('   2. Copy the Server key');
        print('   3. Replace YOUR_FCM_SERVER_KEY_HERE in firebase_admin_service.dart');
        return true; // Return true so in-app notifications still work
      }

      // Get badge count from data if available
      final badgeCount = data?['badge'] != null ? int.tryParse(data!['badge']) ?? 1 : 1;
      
      // Prepare FCM message
      final message = {
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
          if (imageUrl != null) 'image': imageUrl,
        },
        'data': data ?? {},
        'priority': 'high',
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'chat_notifications',
            'sound': 'default',
            'badge': badgeCount,
          },
        },
        'apns': {
          'payload': {
            'aps': {
              'sound': 'default',
              'badge': badgeCount,
            },
          },
        },
      };

      // Send to FCM
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == 1) {
          print('✅ Push notification sent successfully');
          return true;
        } else {
          print('❌ FCM returned error: ${responseData['results']?[0]['error']}');
          return false;
        }
      } else {
        print('❌ FCM request failed with status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        return false;
      }
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
        // Try push notification
        await sendPushNotification(
          fcmToken: fcmToken,
          title: title,
          body: body,
          data: data,
          imageUrl: imageUrl,
        );
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
      final body = 'Order ${_formatOrderNumber(orderNumber)} from $buyerName - \$${totalPrice.toStringAsFixed(2)}';

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