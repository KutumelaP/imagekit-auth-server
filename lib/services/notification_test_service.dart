import 'package:flutter/foundation.dart';
import 'package:naymarket/utils/web_js_stub.dart'
    if (dart.library.html) 'package:naymarket/utils/web_js_real.dart' as js;

/// 🧪 Service for testing awesome PWA notifications
class NotificationTestService {
  static final NotificationTestService _instance = NotificationTestService._internal();
  factory NotificationTestService() => _instance;
  NotificationTestService._internal();

  /// 🚀 Test basic notification
  Future<void> testBasicNotification() async {
    if (!kIsWeb) return;
    
    try {
      js.context.callMethod('eval', ['''
        if (Notification.permission === 'granted') {
          new Notification('🧪 Test Notification', {
            body: 'This is a basic test notification from OmniaSA!',
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
            tag: 'test_basic',
            vibrate: [200, 100, 200]
          });
          console.log('✅ Basic test notification sent');
        } else {
          console.log('❌ Notification permission not granted');
        }
      ''']);
    } catch (e) {
      print('❌ Error testing basic notification: $e');
    }
  }

  /// 🎯 Test notification with action buttons
  Future<void> testActionNotification() async {
    if (!kIsWeb) return;
    
    try {
      js.context.callMethod('eval', ['''
        if (Notification.permission === 'granted') {
          new Notification('🎯 Action Test', {
            body: 'Test notification with action buttons!',
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
            tag: 'test_actions',
            requireInteraction: true,
            actions: [
              { action: 'like', title: '👍 Like', icon: '/icons/like-icon.png' },
              { action: 'share', title: '📤 Share', icon: '/icons/share-icon.png' },
              { action: 'dismiss', title: '❌ Dismiss', icon: '/icons/dismiss-icon.png' }
            ],
            vibrate: [100, 50, 100, 50, 200]
          });
          console.log('✅ Action test notification sent');
        } else {
          console.log('❌ Notification permission not granted');
        }
      ''']);
    } catch (e) {
      print('❌ Error testing action notification: $e');
    }
  }

  /// 🖼️ Test rich notification with image
  Future<void> testRichNotification() async {
    if (!kIsWeb) return;
    
    try {
      js.context.callMethod('eval', ['''
        if (Notification.permission === 'granted') {
          new Notification('🖼️ Rich Media Test', {
            body: 'This notification includes a rich image and advanced features!',
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
            image: '/icons/notification-hero.png',
            tag: 'test_rich',
            requireInteraction: false,
            actions: [
              { action: 'view', title: '👀 View Image', icon: '/icons/view-icon.png' },
              { action: 'save', title: '💾 Save', icon: '/icons/save-icon.png' }
            ],
            vibrate: [50, 25, 50, 25, 50, 25, 200],
            silent: false,
            timestamp: Date.now()
          });
          console.log('✅ Rich test notification sent');
        } else {
          console.log('❌ Notification permission not granted');
        }
      ''']);
    } catch (e) {
      print('❌ Error testing rich notification: $e');
    }
  }

  /// 💬 Test chat notification simulation
  Future<void> testChatNotification() async {
    if (!kIsWeb) return;
    
    try {
      js.context.callMethod('eval', ['''
        if (Notification.permission === 'granted') {
          new Notification('💬 New Message', {
            body: 'Sarah: "Hi! Is your fresh bread still available for pickup today?"',
            icon: '/icons/chat-icon.png',
            badge: '/icons/Icon-192.png',
            tag: 'test_chat',
            requireInteraction: false,
            actions: [
              { action: 'reply', title: '💬 Quick Reply', icon: '/icons/reply-icon.png' },
              { action: 'view', title: '👀 View Chat', icon: '/icons/view-icon.png' }
            ],
            vibrate: [100, 50, 100],
            data: {
              type: 'chat_message',
              chatId: 'test_chat_123',
              senderId: 'test_user'
            }
          });
          console.log('✅ Chat test notification sent');
        } else {
          console.log('❌ Notification permission not granted');
        }
      ''']);
    } catch (e) {
      print('❌ Error testing chat notification: $e');
    }
  }

  /// 🛒 Test order notification simulation
  Future<void> testOrderNotification() async {
    if (!kIsWeb) return;
    
    try {
      js.context.callMethod('eval', ['''
        if (Notification.permission === 'granted') {
          new Notification('🛒 New Order Received!', {
            body: 'Order #12345: 2x Fresh Bread, 1x Milk - Total: R45.00',
            icon: '/icons/order-icon.png',
            badge: '/icons/Icon-192.png',
            tag: 'test_order',
            requireInteraction: true,
            actions: [
              { action: 'accept', title: '✅ Accept Order', icon: '/icons/accept-icon.png' },
              { action: 'view', title: '📋 View Details', icon: '/icons/view-icon.png' }
            ],
            vibrate: [200, 100, 200, 100, 200],
            data: {
              type: 'new_order_seller',
              orderId: 'test_order_123',
              amount: '45.00'
            }
          });
          console.log('✅ Order test notification sent');
        } else {
          console.log('❌ Notification permission not granted');
        }
      ''']);
    } catch (e) {
      print('❌ Error testing order notification: $e');
    }
  }

  /// 🎉 Test success notification
  Future<void> testSuccessNotification() async {
    if (!kIsWeb) return;
    
    try {
      js.context.callMethod('eval', ['''
        if (Notification.permission === 'granted') {
          new Notification('🎉 Payment Successful!', {
            body: 'Your order has been paid successfully. Order #12345 - R45.00',
            icon: '/icons/success-icon.png',
            badge: '/icons/Icon-192.png',
            tag: 'test_success',
            requireInteraction: false,
            actions: [
              { action: 'receipt', title: '🧾 View Receipt', icon: '/icons/receipt-icon.png' },
              { action: 'track', title: '📍 Track Order', icon: '/icons/track-icon.png' }
            ],
            vibrate: [50, 25, 50, 25, 50, 25, 200],
            data: {
              type: 'payment_success',
              orderId: 'test_order_123'
            }
          });
          console.log('✅ Success test notification sent');
        } else {
          console.log('❌ Notification permission not granted');
        }
      ''']);
    } catch (e) {
      print('❌ Error testing success notification: $e');
    }
  }

  /// 🔥 Test all notification types in sequence
  Future<void> testAllNotifications() async {
    if (!kIsWeb) return;
    
    print('🧪 Testing all notification types...');
    
    await testBasicNotification();
    await Future.delayed(Duration(seconds: 2));
    
    await testChatNotification();
    await Future.delayed(Duration(seconds: 2));
    
    await testOrderNotification();
    await Future.delayed(Duration(seconds: 2));
    
    await testSuccessNotification();
    await Future.delayed(Duration(seconds: 2));
    
    await testActionNotification();
    await Future.delayed(Duration(seconds: 2));
    
    await testRichNotification();
    
    print('🎉 All notification tests completed!');
  }

  /// 📊 Check notification support and permissions
  Future<Map<String, dynamic>> getNotificationStatus() async {
    if (!kIsWeb) {
      return {
        'supported': false,
        'permission': 'not_web',
        'message': 'Notifications only supported on web platform'
      };
    }
    
    try {
      final supported = js.context.callMethod('eval', ['typeof Notification !== "undefined"']);
      final permission = js.context.callMethod('eval', ['Notification.permission']);
      
      return {
        'supported': supported == true,
        'permission': permission?.toString() ?? 'unknown',
        'message': _getPermissionMessage(permission?.toString() ?? 'unknown')
      };
    } catch (e) {
      return {
        'supported': false,
        'permission': 'error',
        'message': 'Error checking notification support: $e'
      };
    }
  }

  String _getPermissionMessage(String permission) {
    switch (permission) {
      case 'granted':
        return '✅ Notifications are enabled and working perfectly!';
      case 'denied':
        return '❌ Notifications are blocked. Please enable them in your browser settings.';
      case 'default':
        return '⏳ Notification permission not yet requested.';
      default:
        return '❓ Unknown notification permission status.';
    }
  }
}
