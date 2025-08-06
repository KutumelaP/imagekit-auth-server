import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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

    try {
      // Listen to chats where current user is a participant
      final chatsStream = FirebaseFirestore.instance
          .collection('chats')
          .where(Filter.or(
            Filter('buyerId', isEqualTo: currentUserId),
            Filter('sellerId', isEqualTo: currentUserId),
          ))
          .snapshots();
      
      final notificationsStream = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .snapshots();

      // Listen to both streams separately
      _subscription = chatsStream.listen(
        (snapshot) {
          if (mounted) {
            _updateBadgeCount(currentUserId);
          }
        },
        onError: (error) {
          print('❌ Error in notification badge stream: $error');
          // Fallback: try to get count once
          _getUnreadCountOnce(currentUserId);
        },
      );

      // Also listen to notifications stream
      notificationsStream.listen(
        (snapshot) {
          if (mounted) {
            _updateBadgeCount(currentUserId);
          }
        },
        onError: (error) {
          print('❌ Error in notifications badge stream: $error');
        },
      );
    } catch (e) {
      print('❌ Error initializing notification badge: $e');
      // Fallback: try to get count once
      _getUnreadCountOnce(currentUserId);
    }
  }

  Future<void> _updateBadgeCount(String currentUserId) async {
    try {
      int unreadCount = 0;

      // Only count unread notifications (exclude chat messages)
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();

      // Filter out chat messages from notification count
      for (var doc in notificationsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] as String? ?? '';
        
        // Only count non-chat notifications
        if (type != 'chat_message') {
          unreadCount++;
        }
      }
      
      print('🔍 DEBUG: Badge count breakdown - Notifications: $unreadCount (excluding chat messages)');

      if (mounted) {
        setState(() {
          _unreadCount = unreadCount;
          _isInitialized = true;
        });
        
        print('🔔 Badge updated: $_unreadCount unread notifications');
      }
    } catch (e) {
      print('❌ Error updating badge count: $e');
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