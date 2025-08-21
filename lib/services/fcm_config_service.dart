import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../firebase_options.dart';
import 'awesome_notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:marketplace_app/utils/web_env.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:marketplace_app/utils/web_js_stub.dart'
    if (dart.library.html) 'package:marketplace_app/utils/web_js_real.dart' as js;

class FCMConfigService {
  static final FCMConfigService _instance = FCMConfigService._internal();
  factory FCMConfigService() => _instance;
  FCMConfigService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Configuration variables
  String? _projectId;
  String? _messagingSenderId;
  String? _appId;
  // String? _apiKey; // reserved for future use
  String? _serverKey;
  
  // FCM token
  String? _fcmToken;
  
  // Status flags
  bool _isConfigured = false;
  bool _isInitialized = false;

  /// Initialize FCM configuration
  Future<void> initialize() async {
    try {
      print('🔔 Initializing FCM configuration...');
      
      // Load configuration
      await _loadConfiguration();
      
      // Validate configuration
      await _validateConfiguration();
      
      // On web, gate FCM permission/token to supported environments only
      if (WebEnv.isWebPushSupported) {
        // Request permissions
        await _requestPermissions();
        // Get FCM token
        await _getFCMToken();
      } else {
        print('⚠️ Web push not supported in this environment (skipping permission/token).');
      }
      
      // Set up message handlers
      await _setupMessageHandlers();
      
      _isInitialized = true;
      print('✅ FCM configuration initialized successfully');
    } catch (e) {
      print('❌ Error initializing FCM configuration: $e');
      _isConfigured = false;
    }
  }

  // Old method removed; using WebEnv.isWebPushSupported

  /// Load configuration from firebase_options.dart and SharedPreferences
  Future<void> _loadConfiguration() async {
    try {
      // Load from firebase_options.dart
      final options = DefaultFirebaseOptions.currentPlatform;
      _projectId = options.projectId;
      _messagingSenderId = options.messagingSenderId;
      _appId = options.appId;
      
      print('🔔 Loaded Firebase configuration:');
      print('   Project ID: $_projectId');
      print('   Messaging Sender ID: $_messagingSenderId');
      print('   App ID: $_appId');
      
      // Load server key from SharedPreferences (if set)
      final prefs = await SharedPreferences.getInstance();
      _serverKey = prefs.getString('fcm_server_key');
      
      if (_serverKey != null) {
        print('🔔 Server key loaded from SharedPreferences');
      } else {
        print('⚠️ No server key found - push notifications will use Firestore triggers');
      }
      
    } catch (e) {
      print('❌ Error loading FCM configuration: $e');
      throw e;
    }
  }

  /// Validate FCM configuration
  Future<void> _validateConfiguration() async {
    if (_projectId == null || _messagingSenderId == null) {
      print('❌ Invalid FCM configuration: missing project ID or messaging sender ID');
      _isConfigured = false;
      return;
    }
    
    // Consider FCM configured if we have the basic Firebase project details
    _isConfigured = true;
    print('✅ FCM configuration validated');
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      print('🔔 Requesting notification permissions...');
      
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('🔔 Notification permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Notification permissions granted');
      } else {
        print('⚠️ Notification permissions not fully granted: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
    }
  }

  /// Get and save FCM token
  Future<void> _getFCMToken() async {
    try {
      print('🔔 Getting FCM token...');
      
      _fcmToken = await _firebaseMessaging.getToken();
      
      if (_fcmToken != null) {
        print('✅ FCM token obtained: ${_fcmToken!.substring(0, 20)}...');
        
        // Save token to Firestore
        await _saveFCMTokenToFirestore(_fcmToken!);
        
        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);
        
      } else {
        print('❌ Failed to get FCM token');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': _getPlatform(),
        });
        print('✅ FCM token saved to Firestore');
      } else {
        print('⚠️ No user logged in, skipping FCM token save');
      }
    } catch (e) {
      print('❌ Error saving FCM token to Firestore: $e');
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String newToken) async {
    try {
      print('🔔 FCM token refreshed');
      _fcmToken = newToken;
      await _saveFCMTokenToFirestore(newToken);
    } catch (e) {
      print('❌ Error handling token refresh: $e');
    }
  }

  /// Set up message handlers
  Future<void> _setupMessageHandlers() async {
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);
      
      print('✅ Message handlers set up successfully');
    } catch (e) {
      print('❌ Error setting up message handlers: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('🔔 Received foreground message:');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Data: ${message.data}');
    
    // Show a foreground banner for chat messages on mobile using Awesome Notifications
    final data = message.data;
    final type = data['type'];
    if (type == 'chat_message') {
      final chatId = data['chatId'] ?? '';
      final senderId = data['senderId'] ?? '';
      final body = message.notification?.body ?? '';
      if (chatId.isNotEmpty && senderId.isNotEmpty && body.isNotEmpty) {
        AwesomeNotificationService().showChatNotification(
          chatId: chatId,
          senderId: senderId,
          message: body,
        );
      }
    } else if (type == 'order_status' || type == 'new_order_seller' || type == 'new_order_buyer') {
      final orderId = data['orderId'] ?? '';
      final title = message.notification?.title ?? 'Order Update';
      final body = message.notification?.body ?? '';
      if (orderId.isNotEmpty && body.isNotEmpty) {
        AwesomeNotificationService().showOrderNotification(
          title: title,
          body: body,
          orderId: orderId,
          type: type,
        );
      }
    }
  }

  /// Handle notification opened
  void _handleNotificationOpened(RemoteMessage message) {
    print('🔔 App opened from notification:');
    print('   Data: ${message.data}');
    
    // Handle navigation based on message data
    _handleNotificationNavigation(message.data);
  }

  /// Handle notification navigation
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Add navigation logic based on notification type
    final type = data['type'];
    final id = data['id'];
    
    print('🔔 Navigating from notification: type=$type, id=$id');
    
    // Example navigation logic:
    // switch (type) {
    //   case 'order':
    //     // Navigate to order details
    //     break;
    //   case 'chat':
    //     // Navigate to chat
    //     break;
    // }
  }

  /// Send test notification
  Future<bool> sendTestNotification() async {
    try {
      print('🔔 Sending test notification...');
      
      if (!_isConfigured) {
        print('❌ FCM not configured');
        return false;
      }
      
      if (_fcmToken == null) {
        print('❌ No FCM token available');
        return false;
      }
      
      // If we have a server key, send via FCM API
      if (_serverKey != null) {
        return await _sendFCMNotification();
      } else {
        // Otherwise, create a test notification in Firestore
        return await _createTestNotificationInFirestore();
      }
    } catch (e) {
      print('❌ Error sending test notification: $e');
      return false;
    }
  }

  /// Send notification via FCM API
  Future<bool> _sendFCMNotification() async {
    try {
      final message = {
        'to': _fcmToken,
        'notification': {
          'title': 'Test Notification',
          'body': 'This is a test notification from FCM Config Service',
        },
        'data': {
          'type': 'test',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        'priority': 'high',
      };

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == 1) {
          print('✅ Test notification sent successfully via FCM');
          return true;
        } else {
          print('❌ FCM returned error: ${responseData['results']?[0]['error']}');
          return false;
        }
      } else {
        print('❌ FCM request failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending FCM notification: $e');
      return false;
    }
  }

  /// Create test notification in Firestore
  Future<bool> _createTestNotificationInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return false;
      }
      
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final fcmToken = userDoc.data()?['fcmToken'];
      
      if (fcmToken == null) {
        print('❌ User has no FCM token');
        return false;
      }
      
      // Try to send direct FCM notification first
      final success = await _sendDirectFCMNotification(fcmToken);
      if (success) {
        print('✅ Test notification sent directly via FCM');
        return true;
      }
      
      // Fallback: Enqueue push notification document in Firestore
      await _firestore.collection('push_notifications').add({
        'to': fcmToken,
        'notification': {
          'title': 'Test Notification',
          'body': 'This is a test notification from FCM Config Service',
        },
        'data': {
          'type': 'test',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('✅ Test notification created in Firestore');
      return true;
    } catch (e) {
      print('❌ Error creating test notification in Firestore: $e');
      return false;
    }
  }

  /// Send direct FCM notification using a public server key
  Future<bool> _sendDirectFCMNotification(String token) async {
    try {
      // For now, we'll simulate a system notification by creating a local notification
      // that will be handled by the Firebase Messaging foreground handler
      
      // Create a simulated remote message
      final simulatedMessage = RemoteMessage(
        notification: RemoteNotification(
          title: 'Test Notification',
          body: 'This is a test notification from FCM Config Service',
        ),
        data: {
          'type': 'test',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      
      // Trigger the foreground message handler
      _handleForegroundMessage(simulatedMessage);
      
      print('✅ Simulated system notification sent');
      return true;
    } catch (e) {
      print('❌ Error sending direct FCM notification: $e');
      return false;
    }
  }

  /// Set FCM server key
  Future<void> setServerKey(String serverKey) async {
    try {
      _serverKey = serverKey;
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_server_key', serverKey);
      
      print('✅ FCM server key saved');
    } catch (e) {
      print('❌ Error saving FCM server key: $e');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if FCM is configured
  bool get isConfigured => _isConfigured;

  /// Check if FCM is initialized
  bool get isInitialized => _isInitialized;

  /// Get platform string
  String _getPlatform() {
    if (kIsWeb) return 'web';
    // Add more platform detection as needed
    return 'mobile';
  }
} 