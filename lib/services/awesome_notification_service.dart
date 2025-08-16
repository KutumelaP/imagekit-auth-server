import 'package:awesome_notifications/awesome_notifications.dart';
import 'navigation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AwesomeNotificationService {
  static final AwesomeNotificationService _instance = AwesomeNotificationService._internal();
  factory AwesomeNotificationService() => _instance;
  AwesomeNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Notification preferences
  bool _systemNotificationsEnabled = true;
  bool _audioNotificationsEnabled = true;
  bool _inAppNotificationsEnabled = true;

  bool get systemNotificationsEnabled => _systemNotificationsEnabled;
  bool get audioNotificationsEnabled => _audioNotificationsEnabled;
  bool get inAppNotificationsEnabled => _inAppNotificationsEnabled;

  /// Initialize Awesome Notifications
  Future<void> initialize() async {
    try {
      // Initialize Awesome Notifications
      await AwesomeNotifications().initialize(
        null, // null for default app icon
        [
          NotificationChannel(
            channelKey: 'basic_channel',
            channelName: 'Basic Notifications',
            channelDescription: 'Basic notification channel',
            defaultColor: Colors.blue,
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            enableVibration: true,
            enableLights: true,
          ),
          NotificationChannel(
            channelKey: 'chat_channel',
            channelName: 'Chat Notifications',
            channelDescription: 'Chat message notifications',
            defaultColor: Colors.green,
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          ),
          NotificationChannel(
            channelKey: 'order_channel',
            channelName: 'Order Notifications',
            channelDescription: 'Order status notifications',
            defaultColor: Colors.orange,
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          ),
        ],
      );

      // Reset badge on init and ensure iOS foreground presentation is allowed
      await AwesomeNotifications().setGlobalBadgeCounter(0);

      // Set up notification action listeners
      _setupNotificationListeners();
      
      // Load notification preferences
      await _loadNotificationPreferences();
      
      print('✅ Awesome Notifications initialized successfully');
    } catch (e) {
      print('❌ Error initializing Awesome Notifications: $e');
    }
  }

  /// Set up notification action listeners
  void _setupNotificationListeners() {
    // Listen to notification action buttons
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: (ReceivedAction receivedAction) async {
      _handleNotificationAction(receivedAction);
      },
      onNotificationCreatedMethod: (ReceivedNotification receivedNotification) async {
        print('🔔 Notification created: ${receivedNotification.title}');
      },
      onNotificationDisplayedMethod: (ReceivedNotification receivedNotification) async {
        print('🔔 Notification displayed: ${receivedNotification.title}');
      },
      onDismissActionReceivedMethod: (ReceivedAction receivedAction) async {
        print('🔔 Notification dismissed: ${receivedAction.title}');
      },
    );
  }

  /// Handle notification actions
  void _handleNotificationAction(ReceivedAction receivedAction) {
    print('🔔 Notification action: ${receivedAction.buttonKeyPressed}');
    
    // Handle different notification types
    switch (receivedAction.payload?['type']) {
      case 'chat':
        _handleChatNotification(receivedAction);
        break;
      case 'chat_message': // backward compatibility
        _handleChatNotification(receivedAction);
        break;
      case 'order':
        _handleOrderNotification(receivedAction);
        break;
      case 'general':
        _handleGeneralNotification(receivedAction);
        break;
      default:
        print('🔔 Unknown notification type: ${receivedAction.payload?['type']}');
    }
  }

  /// Handle chat notification actions
  void _handleChatNotification(ReceivedAction receivedAction) {
    final chatId = receivedAction.payload?['chatId'];
    if (chatId != null) {
      final actionKey = receivedAction.buttonKeyPressed;
      final replyText = receivedAction.buttonKeyInput?.trim();
      if (actionKey == 'REPLY' && (replyText?.isNotEmpty ?? false)) {
        print('🔔 Quick reply from notification to chat $chatId');
        // ignore: unawaited_futures
        _sendQuickReply(chatId, replyText!);
      } else {
        // Navigate to chat screen (VIEW or tap on body)
        print('🔔 Navigating to chat: $chatId');
        try {
          // ignore: unawaited_futures
          NavigationService.navigateTo('/chat', arguments: { 'chatId': chatId });
        } catch (_) {}
      }
    }
  }

  Future<void> _sendQuickReply(String chatId, String text) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ Cannot send quick reply: no authenticated user');
        return;
      }

      final message = {
        'senderId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'text': text,
        'status': 'sent',
      };

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message);

      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({
        'lastMessage': text,
        'lastMessageBy': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Quick reply sent to chat $chatId');
    } catch (e) {
      print('❌ Error sending quick reply: $e');
    }
  }

  /// Handle order notification actions
  void _handleOrderNotification(ReceivedAction receivedAction) {
    final orderId = receivedAction.payload?['orderId'];
    if (orderId != null) {
      // Navigate to order details
      print('🔔 Navigating to order: $orderId');
      try {
        // ignore: unawaited_futures
        NavigationService.navigateTo('/seller-order-detail', arguments: { 'orderId': orderId });
      } catch (_) {}
    }
  }

  /// Handle general notification actions
  void _handleGeneralNotification(ReceivedAction receivedAction) {
    print('🔔 General notification action: ${receivedAction.title}');
  }

  /// Load notification preferences
  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _systemNotificationsEnabled = prefs.getBool('system_notifications') ?? true;
    _audioNotificationsEnabled = prefs.getBool('audio_notifications') ?? true;
    _inAppNotificationsEnabled = prefs.getBool('inapp_notifications') ?? true;
    
    print('🔔 Notification preferences loaded: System: $_systemNotificationsEnabled, Audio: $_audioNotificationsEnabled, In-app: $_inAppNotificationsEnabled');
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences({
    bool? systemNotifications,
    bool? audioNotifications,
    bool? inAppNotifications,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (systemNotifications != null) {
      _systemNotificationsEnabled = systemNotifications;
      await prefs.setBool('system_notifications', systemNotifications);
    }
    
    if (audioNotifications != null) {
      _audioNotificationsEnabled = audioNotifications;
      await prefs.setBool('audio_notifications', audioNotifications);
    }
    
    if (inAppNotifications != null) {
      _inAppNotificationsEnabled = inAppNotifications;
      await prefs.setBool('inapp_notifications', inAppNotifications);
    }
    
    print('🔔 Notification preferences updated');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      final isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
      print('🔔 Notification permission granted: $isAllowed');
      return isAllowed;
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Show chat notification
  Future<void> showChatNotification({
    required String chatId,
    required String senderId,
    required String message,
  }) async {
    try {
      // Get sender's name
      final senderDoc = await _firestore
          .collection('users')
          .doc(senderId)
          .get();
      
      final senderName = senderDoc.data()?['displayName'] ?? 
                        senderDoc.data()?['email']?.split('@')[0] ?? 
                        'Someone';

      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: 'chat_channel',
            title: senderName,
            body: message.isNotEmpty ? message : 'New message',
            notificationLayout: NotificationLayout.Default,
            payload: {
              'type': 'chat',
              'chatId': chatId,
              'senderId': senderId,
            },
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'REPLY',
              label: 'Reply',
            ),
            NotificationActionButton(
              key: 'VIEW',
              label: 'View',
            ),
          ],
        );
      }

      // DO NOT store chat messages in Firestore for in-app display
      // Chat messages should only appear in the chat interface
      // This prevents chat messages from cluttering the notifications list

      print('🔔 Chat notification sent for chat $chatId from $senderName');
    } catch (e) {
      print('❌ Error showing chat notification: $e');
    }
  }

  /// Show order notification
  Future<void> showOrderNotification({
    required String title,
    required String body,
    required String orderId,
    required String type,
  }) async {
    try {
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: 'order_channel',
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            payload: {
              'type': 'order',
              'orderId': orderId,
              'orderType': type,
            },
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'VIEW',
              label: 'View Order',
            ),
          ],
        );
      }

      // Store in Firestore for in-app display
      await _storeNotificationInDatabase(
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        title: title,
        body: body,
        type: 'order',
        data: {
          'orderId': orderId,
          'orderType': type,
        },
      );

      print('🔔 Order notification shown: $title');
    } catch (e) {
      print('❌ Error showing order notification: $e');
    }
  }

  /// Show general notification
  Future<void> showGeneralNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    try {
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: 'basic_channel',
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            payload: payload?.map((key, value) => MapEntry(key, value)),
          ),
        );
      }

      // Store in Firestore for in-app display
      await _storeNotificationInDatabase(
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        title: title,
        body: body,
        type: 'general',
        data: payload?.map((key, value) => MapEntry(key, value)),
      );

      print('🔔 General notification shown: $title');
    } catch (e) {
      print('❌ Error showing general notification: $e');
    }
  }

  /// Test notification
  Future<void> testNotification() async {
    try {
      print('🧪 Testing Awesome Notifications...');
      
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'basic_channel',
          title: 'Test Notification',
          body: 'This is a test notification from Mzansi Marketplace',
          notificationLayout: NotificationLayout.Default,
          payload: {
            'type': 'test',
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'DISMISS',
            label: 'Dismiss',
          ),
        ],
      );
      
      print('✅ Test notification sent successfully');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
    print('🔔 All notifications cancelled');
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
    print('🔔 Notification cancelled: $id');
  }

  /// Show in-app notification (snackbar)
  void showInAppNotification(BuildContext context, String message) {
    if (!_inAppNotificationsEnabled) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Store notification in Firestore database
  Future<void> _storeNotificationInDatabase({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (userId.isEmpty) {
        print('❌ ERROR: Cannot store notification - userId is empty');
        return;
      }

      final notificationData = {
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'userId': userId,
      };

      final docRef = await _firestore
          .collection('notifications')
          .add(notificationData);
      
      print('✅ Notification stored in database for user: $userId with ID: ${docRef.id}');
    } catch (e) {
      print('❌ Error storing notification in database: $e');
    }
  }

  /// Get notifications stream
  Stream<QuerySnapshot> getNotificationsStream() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found');
        return Stream.empty();
      }

      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return Stream.empty();
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
      print('✅ Notification deleted successfully: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
      throw e;
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found');
        return;
      }

      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('✅ All notifications deleted successfully');
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
      throw e;
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      throw e;
    }
  }

  /// Dispose
  void dispose() {
    // Awesome Notifications doesn't need explicit disposal
  }
} 