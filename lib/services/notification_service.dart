import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:marketplace_app/utils/web_js_stub.dart'
    if (dart.library.html) 'package:marketplace_app/utils/web_js_real.dart' as js;
import 'sound_service.dart';



class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Stream controller for in-app notifications
  final StreamController<Map<String, dynamic>> _notificationController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  // Notification preferences
  bool _systemNotificationsEnabled = true;
  bool _audioNotificationsEnabled = true;
  bool _inAppNotificationsEnabled = true;

  bool get systemNotificationsEnabled => _systemNotificationsEnabled;
  bool get audioNotificationsEnabled => _audioNotificationsEnabled;
  bool get inAppNotificationsEnabled => _inAppNotificationsEnabled;

  // Firebase services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Sound service for audio notifications
  final SoundService _soundService = SoundService();

  // Initialize the notification service
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        // Web: Use browser notifications
        await _initializeWebNotifications();
      } else {
        // Mobile: For now, just load preferences
        print('📱 Mobile notifications will be implemented later');
      }
      
      // Load notification preferences
      await _loadNotificationPreferences();
      
      print('✅ Notification Service initialized');
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }

  /// Initialize web notifications
  Future<void> _initializeWebNotifications() async {
    try {
      // Check if browser supports notifications
      final hasNotificationSupport = js.context.hasProperty('Notification');
      if (!hasNotificationSupport) {
        print('❌ Browser does not support notifications');
        return;
      }

      // Check current permission status
      final permission = js.context.callMethod('eval', ['Notification.permission']);
      print('🔔 Current notification permission: $permission');

      if (permission == 'default') {
        print('🔔 Requesting notification permissions...');
        // Request permission using proper Promise handling
        js.context.callMethod('eval', ['''
          Notification.requestPermission().then(function(result) {
            console.log('🔔 Notification permission result:', result);
          }).catch(function(error) {
            console.error('❌ Error requesting permission:', error);
          });
        ''']);
      } else if (permission == 'granted') {
        print('✅ Notification permissions already granted');
      } else {
        print('❌ Notification permissions denied');
      }
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
    }
  }



  // Load notification preferences
  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _systemNotificationsEnabled = prefs.getBool('system_notifications') ?? true;
    _audioNotificationsEnabled = prefs.getBool('audio_notifications') ?? true;
    _inAppNotificationsEnabled = prefs.getBool('inapp_notifications') ?? true;
    
    print('🔔 Notification preferences loaded: System: $_systemNotificationsEnabled, Audio: $_audioNotificationsEnabled, In-app: $_inAppNotificationsEnabled');
  }

  // Update notification preferences
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

  // Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) {
        // Web: Check current permission status first
        final currentPermission = js.context.callMethod('eval', ['Notification.permission']);
        
        if (currentPermission == 'granted') {
          return true;
        } else if (currentPermission == 'denied') {
          return false;
        } else {
          // Permission is 'default', request it
          print('🔔 Requesting notification permissions...');
          
          // Use a simpler approach - just trigger the permission request
          // The actual permission result will be handled by the browser
          js.context.callMethod('eval', ['''
            Notification.requestPermission().then(function(result) {
              console.log('🔔 Notification permission result:', result);
            }).catch(function(error) {
              console.error('❌ Error requesting permission:', error);
            });
          ''']);
          
          // For now, return based on current status
          // In a real app, you might want to implement a more sophisticated
          // permission checking mechanism
          return currentPermission == 'granted';
        }
      } else {
        // Mobile: For now, return true (will be implemented later)
        return true;
      }
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  // Show chat notification
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
        if (kIsWeb) {
          _showWebNotification(
            title: senderName,
            body: message.isNotEmpty ? message : 'New message',
            icon: '/icons/Icon-192.png',
            tag: 'chat_$chatId',
            payload: {
              'type': 'chat_message',
              'chatId': chatId,
              'senderId': senderId,
            },
          );
        } else {
          // Mobile: For now, just show in-app notification
          print('📱 Mobile notification will be implemented later');
        }
      }

      // Add to notification stream for in-app display (temporary)
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'chat_message',
          'title': senderName,
          'body': message.isNotEmpty ? message : 'New message',
          'chatId': chatId,
          'senderId': senderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Play sound if enabled
      if (_audioNotificationsEnabled) {
        await _soundService.playNotificationSound();
      }

      // DO NOT store chat messages in notifications database
      // Chat messages should only appear in the chat interface
      // This prevents chat messages from cluttering the notifications list

      print('🔔 Chat notification sent for chat $chatId from $senderName');
    } catch (e) {
      print('❌ Error showing chat notification: $e');
    }
  }

  // Show order notification
  Future<void> showOrderNotification({
    required String title,
    required String body,
    required String orderId,
    required String type,
  }) async {
    try {
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          _showWebNotification(
            title: title,
            body: body,
            icon: '/icons/Icon-192.png',
            tag: 'order_$orderId',
            payload: {
              'type': 'order',
              'orderId': orderId,
              'orderType': type,
            },
          );
        } else {
          // Mobile: For now, just show in-app notification
          print('📱 Mobile notification will be implemented later');
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'order',
          'title': title,
          'body': body,
          'orderId': orderId,
          'orderType': type,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Play sound if enabled
      if (_audioNotificationsEnabled) {
        await _soundService.playNotificationSound();
      }

      // Store in Firestore for persistence
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

  // Show web notification using browser's native notification API
  void _showWebNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
    Map<String, dynamic>? payload,
  }) {
    try {
      // Check if browser supports notifications
      if (!js.context.hasProperty('Notification')) {
        print('❌ Browser does not support notifications');
        return;
      }

      // Check permission
      final permission = js.context.callMethod('eval', ['Notification.permission']);
      if (permission != 'granted') {
        print('❌ Notification permission not granted');
        return;
      }

      // Create notification options
      final options = js.JsObject.jsify({
        'body': body,
        'icon': icon ?? '/icons/Icon-192.png',
        'tag': tag ?? 'marketplace_notification',
        'data': payload ?? {},
        'requireInteraction': false,
        'silent': false,
      });

      // Create notification using proper JavaScript interop
      final notification = js.JsObject.fromBrowserObject(
        js.context.callMethod('Notification', [title, options])
      );

      // Add click event listener
      notification.callMethod('addEventListener', [
        'click',
        js.allowInterop((event) {
          print('🔔 Web notification clicked');
          // Handle notification click
          if (payload != null && payload['orderId'] != null) {
            // Navigate to order details
            print('🔔 Navigating to order: ${payload['orderId']}');
          }
        })
      ]);

      // Auto-close after 5 seconds
      js.context.callMethod('setTimeout', [
        js.allowInterop(() {
          notification.callMethod('close');
        }),
        5000
      ]);

      print('✅ Web notification shown: $title');
    } catch (e) {
      print('❌ Error showing web notification: $e');
    }
  }

  // Show general notification
  Future<void> showGeneralNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    try {
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          _showWebNotification(
            title: title,
            body: body,
            icon: '/icons/Icon-192.png',
            tag: 'general_${DateTime.now().millisecondsSinceEpoch}',
            payload: payload?.map((key, value) => MapEntry(key, value)),
          );
        } else {
          // Mobile: For now, just show in-app notification
          print('📱 Mobile notification will be implemented later');
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'general',
          'title': title,
          'body': body,
          'payload': payload,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Store in Firestore for persistence
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

  // Test notification method for debugging
  Future<void> testNotification() async {
    try {
      print('🧪 Testing notification system...');
      
      if (kIsWeb) {
        _showWebNotification(
          title: 'Test Notification',
          body: 'This is a test notification from Mzansi Marketplace',
          icon: '/icons/Icon-192.png',
          tag: 'test_${DateTime.now().millisecondsSinceEpoch}',
          payload: {
            'type': 'test',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } else {
        // Mobile: For now, just show in-app notification
        print('📱 Mobile test notification will be implemented later');
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'test',
          'title': 'Test Notification',
          'body': 'This is a test notification to verify the system is working',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
      
      print('✅ Test notification sent successfully');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) {
      // Web notifications are auto-dismissed, no need to cancel
      print('🔔 Web notifications auto-dismissed');
    } else {
      // Mobile: For now, just log
      print('📱 Mobile notification cancellation will be implemented later');
    }
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) {
      // Web notifications are auto-dismissed
      print('🔔 Web notification auto-dismissed: $id');
    } else {
      // Mobile: For now, just log
      print('📱 Mobile notification cancellation will be implemented later: $id');
    }
  }

  // Show in-app notification (snackbar)
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

  // Dispose
  void dispose() {
    _notificationController.close();
  }

  // ===== COMPATIBILITY METHODS FOR EXISTING CODE =====

  // Refresh notifications (compatibility method)
  Future<void> refreshNotifications() async {
    print('🔔 Refreshing notifications...');
    // This is a compatibility method - actual refresh logic would be implemented here
  }

  // Send local notification (compatibility method)
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await showGeneralNotification(
      title: title,
      body: body,
      payload: data?.map((key, value) => MapEntry(key.toString(), value.toString())),
    );
  }

  // Delete notification (compatibility method)
  Future<void> deleteNotification(String notificationId) async {
     try {
      print('🔔 Deleting notification: $notificationId');
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

  // Delete all notifications (compatibility method)
  Future<void> deleteAllNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found');
        return;
      }

      print('🔔 Deleting all notifications for user: ${currentUser.uid}');
      
      // Get all notifications for the current user
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .get();
      
      // Delete each notification
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

  // Mark notification as read (compatibility method)
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      print('🔔 Marking notification as read: $notificationId');
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

  // Get notifications with validation (compatibility method)
  Stream<QuerySnapshot> getNotificationsWithValidation() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found');
        return Stream.empty();
      }

      print('🔍 Fetching notifications for user: ${currentUser.uid}');
      
      final stream = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .snapshots();
      
      return stream;
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return Stream.empty();
    }
  }

  // Send new order notification to seller
  Future<void> sendNewOrderNotificationToSeller({
    required String sellerId,
    required String orderId,
    required String buyerName,
    required double orderTotal,
    required String sellerName,
  }) async {
    try {
      print('🔍 DEBUG: sendNewOrderNotificationToSeller called');
      print('🔍 DEBUG: sellerId: $sellerId');
      print('🔍 DEBUG: orderId: $orderId');
      print('🔍 DEBUG: buyerName: $buyerName');
      print('🔍 DEBUG: orderTotal: $orderTotal');
      print('🔍 DEBUG: sellerName: $sellerName');
      
      // Validate seller ID
      if (sellerId.isEmpty) {
        print('❌ ERROR: Cannot send notification - sellerId is empty');
        return;
      }

      // Verify seller exists and is actually a seller
      print('🔍 DEBUG: Verifying seller exists...');
      final sellerDocCheck = await _firestore
          .collection('users')
          .doc(sellerId)
          .get();
      
      if (!sellerDocCheck.exists) {
        print('❌ ERROR: Cannot send notification - seller $sellerId does not exist');
        return;
      }

      final sellerDataCheck = sellerDocCheck.data();
      if (sellerDataCheck?['role'] != 'seller') {
        print('❌ ERROR: Cannot send notification - user $sellerId is not a seller (role: ${sellerDataCheck?['role']})');
        return;
      }

      print('🔔 Sending new order notification to seller: $sellerId');
      print('🔔 Order details: ID=$orderId, Buyer=$buyerName, Total=R$orderTotal');
      
      // Store notification in Firestore database
      print('🔍 DEBUG: Storing notification in database...');
      await _storeNotificationInDatabase(
        userId: sellerId,
        title: 'New Order Received',
        body: 'You have a new order from $buyerName for R${orderTotal.toStringAsFixed(2)}',
        type: 'new_order_seller',
        orderId: orderId,
        data: {
          'buyerName': buyerName,
          'orderTotal': orderTotal.toString(),
          'sellerName': sellerName,
        },
      );
      print('🔍 DEBUG: Notification stored in database');
      
      // Show local notification
      final notificationTitle = 'New Order Received';
      final notificationBody = 'You have a new order from $buyerName for R${orderTotal.toStringAsFixed(2)}';
      
      print('🔔 Showing order notification - Title: $notificationTitle, Body: $notificationBody');
      print('🔔 Notification settings - System: $_systemNotificationsEnabled, In-app: $_inAppNotificationsEnabled');
      
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          print('🔍 DEBUG: Showing web notification...');
          _showWebNotification(
            title: notificationTitle,
            body: notificationBody,
            icon: '/icons/Icon-192.png',
            tag: 'order_$orderId',
            payload: {
              'type': 'new_order_seller',
              'orderId': orderId,
            },
          );
          print('🔍 DEBUG: Web notification shown');
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        print('🔍 DEBUG: Adding to notification stream...');
        _notificationController.add({
          'type': 'new_order_seller',
          'title': notificationTitle,
          'body': notificationBody,
          'orderId': orderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('🔍 DEBUG: Added to notification stream');
      }
      
      // Play notification sound
      if (_audioNotificationsEnabled) {
        print('🔍 DEBUG: Playing notification sound...');
        await _soundService.playNotificationSound();
        print('🔍 DEBUG: Notification sound played');
      }
      
      print('✅ New order notification to seller completed successfully');
      
    } catch (e) {
      print('❌ Error sending new order notification to seller: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
    }
  }

  // Store notification in Firestore database
  Future<void> _storeNotificationInDatabase({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? orderId,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('🔍 DEBUG: _storeNotificationInDatabase called');
      print('🔍 DEBUG: userId: $userId');
      print('🔍 DEBUG: title: $title');
      print('🔍 DEBUG: body: $body');
      print('🔍 DEBUG: type: $type');
      print('🔍 DEBUG: orderId: $orderId');
      print('🔍 DEBUG: data: $data');
      
      // Validate user ID is not empty
      if (userId.isEmpty) {
        print('❌ ERROR: Cannot store notification - userId is empty');
        return;
      }

      // Verify the user exists in the database
      print('🔍 DEBUG: Verifying user exists in database...');
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        print('❌ ERROR: Cannot store notification - user $userId does not exist in database');
        return;
      }
      print('🔍 DEBUG: User exists in database');

      final notificationData = {
        'title': title,
        'body': body,
        'type': type,
        'orderId': orderId,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'userId': userId,
        'route': '/order-tracking',
        'deeplink': 'foodmarketplace://order/$orderId',
        'screen': 'OrderTrackingScreen',
      };

      print('🔍 DEBUG: Notification data prepared: $notificationData');
      print('🔍 DEBUG: Adding to notifications collection...');

      final docRef = await _firestore
          .collection('notifications')
          .add(notificationData);
      
      print('✅ Notification stored in database for user: $userId with ID: ${docRef.id}');
      print('📋 Notification data: $notificationData');
      
    } catch (e) {
      print('❌ Error storing notification in database: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
    }
  }

  // Send order status notification to buyer
  Future<void> sendOrderStatusNotificationToBuyer({
    required String buyerId,
    required String orderId,
    required String status,
    required String sellerName,
  }) async {
    try {
      // Validate buyer ID
      if (buyerId.isEmpty) {
        print('❌ ERROR: Cannot send notification - buyerId is empty');
        return;
      }

      // Verify buyer exists
      final buyerDocCheck = await _firestore
          .collection('users')
          .doc(buyerId)
          .get();
      
      if (!buyerDocCheck.exists) {
        print('❌ ERROR: Cannot send notification - buyer $buyerId does not exist');
        return;
      }

      print('🔔 Sending order status notification to buyer: $buyerId');
      print('🔔 Order ID: $orderId, Status: $status, Seller: $sellerName');
      
      // Store notification in Firestore database
      await _storeNotificationInDatabase(
        userId: buyerId,
        title: 'Order Status Updated',
        body: 'Your order status has been updated to: $status',
        type: 'order_status',
        orderId: orderId,
        data: {
          'status': status,
          'sellerName': sellerName,
        },
      );
      
      print('✅ Notification stored in database for buyer: $buyerId');
      
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          try {
            _showWebNotification(
              title: 'Order Status Updated',
              body: 'Your order status has been updated to: $status',
              icon: '/icons/Icon-192.png',
              tag: 'order_$orderId',
              payload: {
                'type': 'order_status',
                'orderId': orderId,
              },
            );
            print('✅ Web notification sent');
          } catch (e) {
            print('❌ Web notification failed: $e');
          }
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'order_status',
          'title': 'Order Status Updated',
          'body': 'Your order status has been updated to: $status',
          'orderId': orderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ In-app notification added to stream');
      }
      
      // Play notification sound
      if (_audioNotificationsEnabled) {
        try {
          await _soundService.playNotificationSound();
          print('✅ Notification sound played');
        } catch (e) {
          print('❌ Notification sound failed: $e');
        }
      }
      
      print('✅ Order status notification sent successfully to buyer: $buyerId');
      
    } catch (e) {
      print('❌ Error sending order status notification to buyer: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Fallback: Try to send a simple in-app notification
      try {
        _notificationController.add({
          'type': 'order_status',
          'title': 'Order Update',
          'body': 'Your order status has been updated to: $status',
          'orderId': orderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ Fallback in-app notification sent');
      } catch (fallbackError) {
        print('❌ Fallback notification also failed: $fallbackError');
      }
    }
  }

  // Send order status notification (compatibility method)
  Future<void> sendOrderStatusNotification({
    required String userId,
    required String orderId,
    required String status,
    required String orderNumber,
    required double totalPrice,
  }) async {
    try {
      print('🔔 Sending order status notification to user: $userId');
      print('🔔 Order details: ID=$orderId, Number=$orderNumber, Status=$status, Total=R$totalPrice');
      
      // Store notification in database
      await _storeNotificationInDatabase(
        userId: userId,
        title: 'Order Status Updated',
        body: 'Order #$orderNumber status updated to $status',
        type: 'order_status',
        orderId: orderId,
        data: {
          'status': status,
          'orderNumber': orderNumber,
          'totalPrice': totalPrice.toString(),
        },
      );
      
      print('✅ Notification stored in database for user: $userId');
      
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          try {
            _showWebNotification(
              title: 'Order Status: $status',
              body: 'Order #$orderNumber status updated to $status',
              icon: '/icons/Icon-192.png',
              tag: 'order_$orderId',
              payload: {
                'type': 'order_status',
                'orderId': orderId,
                'orderNumber': orderNumber,
              },
            );
            print('✅ Web notification sent');
          } catch (e) {
            print('❌ Web notification failed: $e');
          }
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'order_status',
          'title': 'Order Status: $status',
          'body': 'Order #$orderNumber status updated to $status',
          'orderId': orderId,
          'orderNumber': orderNumber,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ In-app notification added to stream');
      }
      
      // Play notification sound
      if (_audioNotificationsEnabled) {
        try {
          await _soundService.playNotificationSound();
          print('✅ Notification sound played');
        } catch (e) {
          print('❌ Notification sound failed: $e');
        }
      }
      
      print('✅ Order status notification sent successfully to user: $userId');
      
    } catch (e) {
      print('❌ Error sending order status notification to user: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Fallback: Try to send a simple in-app notification
      try {
        _notificationController.add({
          'type': 'order_status',
          'title': 'Order Update',
          'body': 'Order #$orderNumber status updated to $status',
          'orderId': orderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ Fallback in-app notification sent');
      } catch (fallbackError) {
        print('❌ Fallback notification also failed: $fallbackError');
      }
    }
  }

  // Request microphone permission (compatibility method)
  Future<bool> requestMicrophonePermission() async {
    print('🎤 Requesting microphone permission...');
    // This would use permission_handler package in a real implementation
    return true; // Assume granted for now
  }

  // Create notification (compatibility method)
  static Future<void> createNotification({
    required String title,
    required String body,
    required String userId,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final notificationService = NotificationService();
    await notificationService.showGeneralNotification(
      title: title,
      body: body,
      payload: data?.map((key, value) => MapEntry(key.toString(), value.toString())),
    );
  }

  // Show popup notification (compatibility method)
  static void showPopupNotification({
    required String title,
    required String message,
    VoidCallback? onTap,
  }) {
    print('🔔 Showing popup notification: $title');
    // This will be handled by the InAppNotificationWidget
  }

  // Show true system notification (compatibility method)
  static Future<void> showTrueSystemNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    print('🔔 Showing system notification: $title');
    // This will be handled by the InAppNotificationWidget
  }

  // Send driver assignment notification (compatibility method)
  static Future<void> sendDriverAssignmentNotification({
    required String driverId,
    required String orderId,
    required String message,
  }) async {
    print('🔔 Driver assignment notification sent to driver: $driverId');
    // This would send to driver's FCM token in a real implementation
  }

  // Send driver order status notification (compatibility method)
  static Future<void> sendDriverOrderStatusNotification({
    required String driverId,
    required String orderId,
    required String status,
    required String message,
  }) async {
    print('🔔 Driver order status notification sent to driver: $driverId');
    // This would send to driver's FCM token in a real implementation
  }

  // Send driver earnings notification (compatibility method)
  static Future<void> sendDriverEarningsNotification({
    required String driverId,
    required double amount,
    required String period,
  }) async {
    print('🔔 Driver earnings notification sent to driver: $driverId');
    // This would send to driver's FCM token in a real implementation
  }

  // Send push notification (compatibility method)
  static Future<void> sendPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    print('🔔 Push notification sent:');
    print('  Token: $token');
    print('  Title: $title');
    print('  Body: $body');
    print('  Data: $data');
    // TODO: Implement actual FCM sending
  }

  // Send chat notification to recipient
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    try {
      // Validate recipient ID
      if (recipientId.isEmpty) {
        print('❌ ERROR: Cannot send chat notification - recipientId is empty');
        return;
      }

      // Verify recipient exists
      final recipientDocCheck = await _firestore
          .collection('users')
          .doc(recipientId)
          .get();
      
      if (!recipientDocCheck.exists) {
        print('❌ ERROR: Cannot send chat notification - recipient $recipientId does not exist');
        return;
      }

      // Validate sender ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ ERROR: Cannot send chat notification - no authenticated sender');
        return;
      }

      // Verify sender exists
      final senderDocCheck = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!senderDocCheck.exists) {
        print('❌ ERROR: Cannot send chat notification - sender ${currentUser.uid} does not exist');
        return;
      }

      // Ensure sender and recipient are different
      if (currentUser.uid == recipientId) {
        print('❌ ERROR: Cannot send chat notification to self');
        return;
      }

      print('🔔 Sending chat notification to user: $recipientId');
      
      // DO NOT store chat messages in notifications database
      // Chat messages should only appear in the chat interface
      // This prevents chat messages from cluttering the notifications list
      
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          _showWebNotification(
            title: 'New message from $senderName',
            body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
            icon: '/icons/Icon-192.png',
            tag: 'chat_$chatId',
            payload: {
              'type': 'chat_message',
              'chatId': chatId,
              'senderId': currentUser.uid,
              'senderName': senderName,
            },
          );
        }
      }

      // Add to notification stream for in-app display (temporary)
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'chat_message',
          'title': 'New message from $senderName',
          'body': message.length > 50 ? '${message.substring(0, 50)}...' : message,
          'chatId': chatId,
          'senderId': currentUser.uid,
          'senderName': senderName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
      
      // Play notification sound
      if (_audioNotificationsEnabled) {
        await _soundService.playNotificationSound();
      }
      
    } catch (e) {
      print('❌ Error sending chat notification to recipient: $e');
    }
  }

  /// Get total unread count for a user across all chats
  Future<int> _getTotalUnreadCount(String userId) async {
    try {
      final chatsQuery = await _firestore
          .collection('chats')
          .where(Filter.or(
            Filter('buyerId', isEqualTo: userId),
            Filter('sellerId', isEqualTo: userId),
          ))
          .get();
      
      int totalUnread = 0;
      for (var chat in chatsQuery.docs) {
        final data = chat.data();
        final unreadCount = data['unreadCount'] as int? ?? 0;
        totalUnread += unreadCount;
      }
      
      return totalUnread;
    } catch (e) {
      print('❌ Error getting total unread count: $e');
      return 0;
    }
  }
} 