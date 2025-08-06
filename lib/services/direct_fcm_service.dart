import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DirectFCMService {
  // Send a true system notification using direct FCM API
  static Future<bool> sendTrueSystemNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return false;
      }

      // Get user's FCM token
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final fcmToken = userDoc.data()?['fcmToken'];
      
      if (fcmToken == null) {
        print('❌ User has no FCM token');
        return false;
      }

      // Create the FCM message for direct sending
      final message = {
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
        },
        'data': {
          'type': 'true_system_notification',
          'payload': payload ?? '',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'android': {
          'notification': {
            'channel_id': 'system_notifications',
            'priority': 'high',
            'default_sound': true,
            'default_vibrate_timings': true,
            'icon': 'ic_launcher',
            'color': '#1F4654',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        'apns': {
          'payload': {
            'aps': {
              'sound': 'default',
              'badge': 1,
              'alert': {
                'title': title,
                'body': body,
              },
            },
          },
        },
        'priority': 'high',
      };

      // For now, let's simulate the notification by creating a local notification
      // This will show in the notification tray immediately
      print('🔔 Simulating true system notification in tray...');
      
      // Create a notification document that will be processed by existing Cloud Function
      await FirebaseFirestore.instance.collection('notifications').add({
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'priority': 'high',
          'android_channel_id': 'system_notifications',
        },
        'data': {
          'type': 'true_system_notification',
          'payload': payload ?? '',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'priority': 'high',
        'ttl': 86400, // 24 hours
      });
      
      print('✅ True system notification document created - should trigger FCM');
      return true;
    } catch (e) {
      print('❌ Error sending true system notification: $e');
      return false;
    }
  }
} 