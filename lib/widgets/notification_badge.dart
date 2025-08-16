import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/safari_optimizer.dart';
import '../services/awesome_notification_service.dart' as an;

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final String? userId;

  const NotificationBadge({
    super.key,
    required this.child,
    this.userId,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _subscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isInitialized = false;
  Timer? _debounceTimer;
  int _lastCount = 0;
  StreamSubscription<QuerySnapshot>? _notifSubscription;
  final Set<String> _seenNotificationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _initializeBadge();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    _debounceTimer?.cancel();
    _notifSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        if (user == null) {
          // User logged out - reset badge
          setState(() {
            _unreadCount = 0;
            _isInitialized = false;
          });
          _subscription?.cancel();
          print('🔔 Badge reset - user logged out');
        } else {
          // User logged in - reinitialize badge only if not already initialized
          if (!_isInitialized) {
            _initializeBadge();
          }
        }
      }
    });
  }

  void _initializeBadge() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = widget.userId ?? currentUser?.uid;
    
    if (currentUserId == null || currentUser == null) {
      print('🔍 DEBUG: No authenticated user found for notification badge');
      return;
    }

    // Check if user is properly authenticated
    if (!currentUser.emailVerified && currentUser.providerData.isEmpty) {
      print('🔍 DEBUG: User not properly authenticated for notification badge');
      return;
    }

    // Safari optimization: reduce stream frequency
    try {
      // Optional: keep a lightweight chat stream to trigger debounced updates if needed later
      final chatsStream = FirebaseFirestore.instance
          .collection('chats')
          .where(Filter.or(
            Filter('buyerId', isEqualTo: currentUserId),
            Filter('sellerId', isEqualTo: currentUserId),
          ))
          .snapshots(includeMetadataChanges: false);

      _subscription = chatsStream.listen(
        (_) {
          if (mounted) {
            _debouncedUpdateBadgeCount(currentUserId);
          }
        },
        onError: (error) {
          if (error.toString().contains('permission-denied')) {
            print('❌ Permission denied for notification badge chat stream (logged once)');
          } else {
            print('❌ Error in notification badge chat stream: $error');
          }
        },
      );

      // Primary: listen to notifications collection for this user
      _notifSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .snapshots(includeMetadataChanges: false)
          .listen((snapshot) async {
        try {
          int unread = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] as String? ?? '';
            if (type != 'chat_message') unread++;
          }

          // Local fallback system popup for newly added order notifications
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final doc = change.doc;
              if (_seenNotificationIds.add(doc.id)) {
                final data = doc.data() as Map<String, dynamic>;
                final type = data['type'] as String? ?? '';
                if (!kIsWeb && type == 'new_order_seller') {
                  final body = data['body'] as String? ?? 'You have a new order';
                  final orderId = (data['data'] as Map<String, dynamic>?)?['orderId'] as String? ?? '';
                  await an.AwesomeNotificationService().showOrderNotification(
                    title: 'New Order Received',
                    body: body,
                    orderId: orderId,
                    type: 'new_order_seller',
                  );
                }
              }
            }
          }

          if (mounted) {
            setState(() {
              _unreadCount = unread;
              _isInitialized = true;
            });
          }
        } catch (e) {
          print('❌ Error processing notifications stream: $e');
        }
      }, onError: (error) {
        if (error.toString().contains('permission-denied')) {
          print('❌ Permission denied for notifications stream (logged once)');
        } else {
          print('❌ Error in notifications stream: $error');
        }
      });

      _isInitialized = true;
      print('🔔 Notification badge initialized for user: $currentUserId');
    } catch (e) {
      print('❌ Error initializing notification badge: $e');
    }
  }

  void _debouncedUpdateBadgeCount(String userId) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _updateBadgeCount(userId);
      }
    });
  }

  void _updateBadgeCount(String userId) {
    // Safari optimization: check memory pressure
    SafariOptimizer.checkMemoryPressure();
    
    // Only update if count actually changed
    if (_unreadCount != _lastCount) {
      setState(() {
        _lastCount = _unreadCount;
      });
    }
  }

  Future<void> _getUnreadCountOnce(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] as String? ?? '';
        
        // Only count non-chat notifications
        if (type != 'chat_message') {
          unreadCount++;
        }
      }

      if (mounted) {
        setState(() {
          _unreadCount = unreadCount;
          _isInitialized = true;
        });
        print('🔔 Badge fallback updated: $_unreadCount unread notifications');
      }
    } catch (e) {
      print('❌ Error in badge fallback: $e');
    }
  }

  // Public method to refresh badge count
  void refreshBadgeCount() {
    final currentUserId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _updateBadgeCount(currentUserId);
    } else {
      // No user - reset badge
      setState(() {
        _unreadCount = 0;
        _isInitialized = false;
      });
    }
  }

  // Force reset badge count (useful for logout)
  void resetBadgeCount() {
    setState(() {
      _unreadCount = 0;
      _isInitialized = false;
    });
    _subscription?.cancel();
    print('🔔 Badge count manually reset');
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // User not authenticated - reset badge and show child without badge
      if (_unreadCount != 0 || _isInitialized) {
        setState(() {
          _unreadCount = 0;
          _isInitialized = false;
        });
      }
      return widget.child;
    }
    
    // Show child without badge if not initialized or no unread messages
    if (!_isInitialized || _unreadCount == 0) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
            child: Text(
              _unreadCount > 99 ? '99+' : _unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
} 