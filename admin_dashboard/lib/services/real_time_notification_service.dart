import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/order_utils.dart';

enum NotificationType {
  newOrder,
  sellerRegistration,
  paymentFailed,
  reviewSubmitted,
  refundRequested,
  systemAlert,
  userReported,
}

enum NotificationPriority {
  low,
  medium,
  high,
  critical,
}

class AdminNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final bool isRead;
  final String? actionUrl;

  AdminNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.timestamp,
    this.data,
    this.isRead = false,
    this.actionUrl,
  });

  factory AdminNotification.fromMap(Map<String, dynamic> map) {
    return AdminNotification(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => NotificationType.systemAlert,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.toString().split('.').last == map['priority'],
        orElse: () => NotificationPriority.medium,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      data: map['data'],
      isRead: map['isRead'] ?? false,
      actionUrl: map['actionUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'data': data,
      'isRead': isRead,
      'actionUrl': actionUrl,
    };
  }

  AdminNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    DateTime? timestamp,
    Map<String, dynamic>? data,
    bool? isRead,
    String? actionUrl,
  }) {
    return AdminNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }
}

class RealTimeNotificationService extends ChangeNotifier {
  static final RealTimeNotificationService _instance = RealTimeNotificationService._internal();
  factory RealTimeNotificationService() => _instance;
  RealTimeNotificationService._internal();

  // WebSocket connection
  WebSocket? _webSocket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  // Notifications
  final List<AdminNotification> _notifications = [];
  final StreamController<AdminNotification> _notificationController = StreamController<AdminNotification>.broadcast();
  
  // Firestore listeners
  final List<StreamSubscription> _firestoreListeners = [];
  
  // Services
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  // Getters
  bool get isConnected => _isConnected;
  List<AdminNotification> get notifications => List.unmodifiable(_notifications);
  Stream<AdminNotification> get notificationStream => _notificationController.stream;
  
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get criticalCount => _notifications.where((n) => n.priority == NotificationPriority.critical && !n.isRead).length;

  /// Initialize the notification service
  Future<void> initialize(FirebaseFirestore firestore, FirebaseAuth auth) async {
    _firestore = firestore;
    _auth = auth;
    
    // Load existing notifications
    await _loadStoredNotifications();
    
    // Setup Firestore listeners for real-time updates
    _setupFirestoreListeners();
    
    // Connect to WebSocket (if available)
    await _connectWebSocket();
    
    debugPrint('🔔 Real-time notification service initialized');
  }

  /// Setup Firestore listeners for different collections
  void _setupFirestoreListeners() {
    // Check if user is authenticated and is admin before setting up listeners
    final user = _auth?.currentUser;
    if (user == null) {
      debugPrint('⚠️ User not authenticated - skipping Firestore listeners setup');
      return;
    }
    
    // Verify admin status before setting up listeners
    user.getIdTokenResult().then((idTokenResult) {
      final isAdmin = idTokenResult.claims?['admin'] == true || 
                     idTokenResult.claims?['role'] == 'admin';
      
      if (!isAdmin) {
        debugPrint('⚠️ User is not admin - skipping Firestore listeners setup');
        return;
      }
      
      // Setup listeners only for admin users
      _setupAdminListeners();
    }).catchError((e) {
      debugPrint('❌ Error verifying admin status: $e');
    });
  }
  
  /// Setup admin-only Firestore listeners
  void _setupAdminListeners() {
    // Listen for new orders
    _firestoreListeners.add(
      _firestore!.collection('orders')
          .where('timestamp', isGreaterThan: Timestamp.now())
          .snapshots()
          .listen(_handleNewOrders, onError: (e) {
            debugPrint('❌ Error listening to orders: $e');
          }),
    );

    // Listen for new seller registrations
    _firestoreListeners.add(
      _firestore!.collection('users')
          .where('role', isEqualTo: 'seller')
          .where('createdAt', isGreaterThan: Timestamp.now())
          .snapshots()
          .listen(_handleNewSellers, onError: (e) {
            debugPrint('❌ Error listening to sellers: $e');
          }),
    );

    // Listen for payment failures
    _firestoreListeners.add(
      _firestore!.collection('orders')
          .where('status', isEqualTo: 'payment_failed')
          .where('lastUpdated', isGreaterThan: Timestamp.now())
          .snapshots()
          .listen(_handlePaymentFailures, onError: (e) {
            debugPrint('❌ Error listening to payment failures: $e');
          }),
    );

    // Listen for new reviews
    _firestoreListeners.add(
      _firestore!.collection('reviews')
          .where('timestamp', isGreaterThan: Timestamp.now())
          .snapshots()
          .listen(_handleNewReviews, onError: (e) {
            debugPrint('❌ Error listening to reviews: $e');
          }),
    );

    debugPrint('📡 Firestore listeners setup complete');
  }

  /// Connect to WebSocket for real-time updates
  Future<void> _connectWebSocket() async {
    if (_isConnecting || _isConnected) return;
    
    _isConnecting = true;
    
    try {
      // In a real implementation, this would connect to your backend WebSocket server
      // For now, we'll simulate with a local connection or skip if not available
      const wsUrl = 'ws://localhost:8080/admin-notifications';
      
      _webSocket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ WebSocket connection timeout - continuing with Firestore only');
          throw TimeoutException('WebSocket connection timeout');
        },
      );
      
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      
      // Setup heartbeat
      _startHeartbeat();
      
      // Listen for messages
      _webSocket!.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDisconnect,
      );
      
      debugPrint('🔗 WebSocket connected successfully');
      
    } catch (e) {
      _isConnecting = false;
      debugPrint('⚠️ WebSocket connection failed: $e - using Firestore only');
      // Continue without WebSocket - Firestore listeners will handle real-time updates
    }
  }

  /// Handle WebSocket messages
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final notification = AdminNotification.fromMap(data);
      _addNotification(notification);
    } catch (e) {
      debugPrint('❌ Error parsing WebSocket message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleWebSocketError(error) {
    debugPrint('❌ WebSocket error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  /// Handle WebSocket disconnect
  void _handleWebSocketDisconnect() {
    debugPrint('🔌 WebSocket disconnected');
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _scheduleReconnect();
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected && _webSocket != null) {
        try {
          _webSocket!.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          debugPrint('❌ Heartbeat failed: $e');
          _handleWebSocketDisconnect();
        }
      }
    });
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () {
        _reconnectAttempts++;
        debugPrint('🔄 Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts');
        _connectWebSocket();
      });
    } else {
      debugPrint('❌ Max reconnection attempts reached - continuing with Firestore only');
    }
  }

  /// Handle new orders from Firestore
  void _handleNewOrders(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final order = change.doc.data() as Map<String, dynamic>;
        final notification = AdminNotification(
          id: _generateId(),
          title: 'New Order Received',
          message: 'Order ${OrderUtils.formatShortOrderNumber(order['orderNumber'] ?? '')} for R${order['total']?.toStringAsFixed(2)}',
          type: NotificationType.newOrder,
          priority: NotificationPriority.medium,
          timestamp: DateTime.now(),
          data: {'orderId': change.doc.id, 'orderNumber': order['orderNumber']},
          actionUrl: '/orders/${change.doc.id}',
        );
        _addNotification(notification);
      }
    }
  }

  /// Handle new seller registrations
  void _handleNewSellers(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final seller = change.doc.data() as Map<String, dynamic>;
        final notification = AdminNotification(
          id: _generateId(),
          title: 'New Seller Registration',
          message: '${seller['businessName'] ?? seller['email']} wants to become a seller',
          type: NotificationType.sellerRegistration,
          priority: NotificationPriority.high,
          timestamp: DateTime.now(),
          data: {'sellerId': change.doc.id, 'businessName': seller['businessName']},
          actionUrl: '/sellers/${change.doc.id}',
        );
        _addNotification(notification);
      }
    }
  }

  /// Handle payment failures
  void _handlePaymentFailures(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.modified) {
        final order = change.doc.data() as Map<String, dynamic>;
        final notification = AdminNotification(
          id: _generateId(),
          title: 'Payment Failed',
          message: 'Payment failed for Order ${OrderUtils.formatShortOrderNumber(order['orderNumber'] ?? '')}',
          type: NotificationType.paymentFailed,
          priority: NotificationPriority.high,
          timestamp: DateTime.now(),
          data: {'orderId': change.doc.id, 'orderNumber': order['orderNumber']},
          actionUrl: '/orders/${change.doc.id}',
        );
        _addNotification(notification);
      }
    }
  }

  /// Handle new reviews
  void _handleNewReviews(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final review = change.doc.data() as Map<String, dynamic>;
        final rating = review['rating'] ?? 0;
        final priority = rating <= 2 ? NotificationPriority.high : NotificationPriority.low;
        
        final notification = AdminNotification(
          id: _generateId(),
          title: 'New Review Submitted',
          message: '${rating}-star review: "${review['comment']?.substring(0, 50) ?? ''}..."',
          type: NotificationType.reviewSubmitted,
          priority: priority,
          timestamp: DateTime.now(),
          data: {'reviewId': change.doc.id, 'rating': rating},
          actionUrl: '/reviews/${change.doc.id}',
        );
        _addNotification(notification);
      }
    }
  }

  /// Add notification to the list and notify listeners
  void _addNotification(AdminNotification notification) {
    _notifications.insert(0, notification); // Add to beginning for chronological order
    
    // Keep only latest 100 notifications
    if (_notifications.length > 100) {
      _notifications.removeRange(100, _notifications.length);
    }
    
    // Store in local storage
    _storeNotifications();
    
    // Notify listeners
    _notificationController.add(notification);
    notifyListeners();
    
    debugPrint('🔔 New notification: ${notification.title}');
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _storeNotifications();
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    await _storeNotifications();
    notifyListeners();
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    await _storeNotifications();
    notifyListeners();
  }

  /// Get notifications by type
  List<AdminNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Get notifications by priority
  List<AdminNotification> getNotificationsByPriority(NotificationPriority priority) {
    return _notifications.where((n) => n.priority == priority).toList();
  }

  /// Load stored notifications from local storage
  Future<void> _loadStoredNotifications() async {
    // In a real app, you'd load from SharedPreferences or Hive
    // For now, we'll skip this implementation
    debugPrint('📂 Loading stored notifications...');
  }

  /// Store notifications to local storage
  Future<void> _storeNotifications() async {
    // In a real app, you'd store to SharedPreferences or Hive
    // For now, we'll skip this implementation
    debugPrint('💾 Storing notifications...');
  }

  /// Generate unique ID for notifications
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_notifications.length}';
  }

  /// Dispose the service
  void dispose() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _webSocket?.close();
    
    for (var listener in _firestoreListeners) {
      listener.cancel();
    }
    _firestoreListeners.clear();
    
    _notificationController.close();
    super.dispose();
    
    debugPrint('🔔 Real-time notification service disposed');
  }


} 