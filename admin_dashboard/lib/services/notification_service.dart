import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminNotificationService {
  static final AdminNotificationService _instance = AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Global navigator key for navigation from notifications
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // No server key on client; push handled by Cloud Functions

  Future<void> initialize() async {
    try {
      // Request permission for notifications
      await _requestPermission();
      
      // Set up message handlers
      await _setupMessageHandlers();
      
      // Get and save FCM token
      await _saveFCMToken();
    } catch (e) {
      print('Error initializing notification service: $e');
      // Continue without FCM if there are issues
    }
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> _setupMessageHandlers() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);
  }

  Future<void> _saveFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error saving FCM token: $e');
      // Don't throw - FCM is optional
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      // Show a custom dialog or snackbar for foreground messages
      _showForegroundNotification(message.notification!);
    }
  }

  void _handleNotificationOpened(RemoteMessage message) {
    print('App opened from notification: ${message.data}');
    // Navigate to appropriate screen based on message data
    _handleNotificationNavigation(message.data);
  }

  void _showForegroundNotification(RemoteNotification notification) {
    // Show a custom dialog or snackbar
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text('${notification.title}: ${notification.body}'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Handle notification tap
            },
          ),
        ),
      );
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Navigate based on notification type
    if (data['type'] == 'chat_message') {
      // Navigate to chat screen
      final chatId = data['chatId'];
      
      // TODO: Navigate to specific chat
      print('Navigate to chat: $chatId');
    } else if (data['type'] == 'order_update') {
      // Navigate to order details
      final orderId = data['orderId'];
      
      // TODO: Navigate to order details
      print('Navigate to order: $orderId');
    } else if (data['type'] == 'new_review') {
      // Navigate to reviews section
      print('Navigate to reviews');
    }
  }

  // Send notification to a specific user
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get recipient's FCM token
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = recipientDoc.data()?['fcmToken'];
      
      if (fcmToken == null) {
        print('No FCM token found for user: $recipientId');
        return;
      }

      // Create in-app notification document
      final notificationData = {
        'userId': recipientId, // Changed to match existing structure
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final notificationRef = await _firestore.collection('notifications').add(notificationData);

      // Enqueue push notification for Cloud Function
      await _firestore.collection('push_notifications').add({
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'type': type,
          'notificationId': notificationRef.id,
          ...?data,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'priority': 'high',
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Removed direct client FCM send; using Cloud Functions via Firestore queue

  // Send chat notification
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: 'New message from $senderName',
      body: message,
      type: 'chat_message',
      data: {
        'chatId': chatId,
        'senderName': senderName,
      },
    );
  }

  // Send order update notification
  Future<void> sendOrderUpdateNotification({
    required String recipientId,
    required String orderId,
    required String status,
    required String message,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: 'Order Update',
      body: message,
      type: 'order_status', // Changed to match existing structure
      data: {
        'orderId': orderId,
        'status': status,
      },
    );
  }

  // Send new review notification
  Future<void> sendReviewNotification({
    required String recipientId,
    required String reviewerName,
    required int rating,
    required String productName,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: 'New Review',
      body: '$reviewerName gave $rating stars for $productName',
      type: 'review', // Changed to match existing structure
      data: {
        'reviewerName': reviewerName,
        'rating': rating,
        'productName': productName,
      },
    );
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Get unread notification count
  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId) // Changed to match existing structure
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get all notifications for a user
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId) // Changed to match existing structure
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Delete a specific notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
      print('✅ Notification deleted: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
      throw e;
    }
  }

  // Delete all notifications for a user
  Future<void> deleteAllNotificationsForUser(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('✅ All notifications deleted for user: $userId');
    } catch (e) {
      print('❌ Error deleting all notifications for user: $e');
      throw e;
    }
  }

  // Delete old notifications (older than 30 days)
  Future<void> cleanupOldNotifications() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final oldNotifications = await _firestore
          .collection('notifications')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      for (var doc in oldNotifications.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }

  // Validate and clean up stale notifications
  Future<void> validateAndCleanupNotifications() async {
    try {
      // Check if user is authenticated and is admin
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ User not authenticated - skipping notification validation');
        return;
      }
      
      // Get the user's custom claims to verify admin status
      final idTokenResult = await user.getIdTokenResult();
      final isAdmin = idTokenResult.claims?['admin'] == true || 
                     idTokenResult.claims?['role'] == 'admin';
      
      if (!isAdmin) {
        print('⚠️ User is not admin - skipping notification validation');
        return;
      }
      
      final notifications = await _firestore
          .collection('notifications')
          .get();

      final batch = _firestore.batch();
      bool hasChanges = false;

      for (final doc in notifications.docs) {
        final data = doc.data();
        final orderId = data['data']?['orderId'] ?? data['orderId'];
        final chatId = data['data']?['chatId'] ?? data['chatId'];

        // Check if referenced order still exists
        if (orderId != null) {
          final orderDoc = await _firestore
              .collection('orders')
              .doc(orderId)
              .get();
          
          if (!orderDoc.exists) {
            batch.delete(doc.reference);
            hasChanges = true;
            print('🗑️ Deleting stale notification for deleted order: $orderId');
          }
        }

        // Check if referenced chat still exists
        if (chatId != null) {
          final chatDoc = await _firestore
              .collection('chats')
              .doc(chatId)
              .get();
          
          if (!chatDoc.exists) {
            batch.delete(doc.reference);
            hasChanges = true;
            print('🗑️ Deleting stale notification for deleted chat: $chatId');
          }
        }
      }

      if (hasChanges) {
        await batch.commit();
        print('✅ Cleaned up stale notifications');
      }
    } catch (e) {
      print('❌ Error validating notifications: $e');
    }
  }
} 