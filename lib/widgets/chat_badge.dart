import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ChatBadge extends StatefulWidget {
  final Widget child;
  final String? userId;

  const ChatBadge({
    super.key,
    required this.child,
    this.userId,
  });

  @override
  State<ChatBadge> createState() => _ChatBadgeState();
}

class _ChatBadgeState extends State<ChatBadge> {
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
          print('💬 Chat badge reset - user logged out');
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
      print('🔍 DEBUG: No authenticated user found for chat badge');
      return;
    }

    try {
      print('🔍 DEBUG: Initializing chat badge for user: $currentUserId');
      
      // Listen to chats where current user is a participant
      final chatsStream = FirebaseFirestore.instance
          .collection('chats')
          .where(Filter.or(
            Filter('buyerId', isEqualTo: currentUserId),
            Filter('sellerId', isEqualTo: currentUserId),
          ))
          .snapshots();

      _subscription = chatsStream.listen(
        (snapshot) {
          if (mounted) {
            print('🔍 DEBUG: Chat badge stream update - ${snapshot.docs.length} chats');
            _updateBadgeCount(currentUserId);
          }
        },
        onError: (error) {
          print('❌ Error in chat badge stream: $error');
          // Don't retry on permission errors - just reset badge
          if (error.toString().contains('permission-denied')) {
            print('🔍 DEBUG: Permission denied for chat badge - user may not be authenticated');
            if (mounted) {
              setState(() {
                _unreadCount = 0;
                _isInitialized = true;
              });
            }
          } else {
            // Fallback: try to get count once for other errors
            _getUnreadCountOnce(currentUserId);
          }
        },
      );
      
      // Initial count
      _updateBadgeCount(currentUserId);
    } catch (e) {
      print('❌ Error initializing chat badge: $e');
      // Don't retry on permission errors
      if (e.toString().contains('permission-denied')) {
        print('🔍 DEBUG: Permission denied for chat badge initialization');
        if (mounted) {
          setState(() {
            _unreadCount = 0;
            _isInitialized = true;
          });
        }
      } else {
        // Fallback: try to get count once for other errors
        _getUnreadCountOnce(currentUserId);
      }
    }
  }

  Future<void> _updateBadgeCount(String currentUserId) async {
    try {
      int unreadCount = 0;

      // Count unread chat messages
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where(Filter.or(
            Filter('buyerId', isEqualTo: currentUserId),
            Filter('sellerId', isEqualTo: currentUserId),
          ))
          .get();

      print('🔍 DEBUG: Found ${chatsSnapshot.docs.length} chats for user: $currentUserId');

      for (var chat in chatsSnapshot.docs) {
        final data = chat.data() as Map<String, dynamic>;
        final chatId = chat.id;
        final chatUnreadCount = data['unreadCount'] as int? ?? 0;
        final buyerId = data['buyerId'] as String?;
        final sellerId = data['sellerId'] as String?;
        final lastMessageBy = data['lastMessageBy'] as String?;
        
        print('🔍 DEBUG: Chat $chatId - unreadCount: $chatUnreadCount, buyerId: $buyerId, sellerId: $sellerId, lastMessageBy: $lastMessageBy');
        
        // Only count unread messages if the last message was from someone else
        if (chatUnreadCount > 0 && lastMessageBy != null && lastMessageBy != currentUserId) {
          unreadCount += chatUnreadCount;
          print('🔍 DEBUG: Adding $chatUnreadCount to total (last message from other user)');
        } else if (chatUnreadCount > 0) {
          print('🔍 DEBUG: Skipping $chatUnreadCount (last message from current user or no last message)');
        }
      }
      
      print('🔍 DEBUG: Chat badge count - Total unread messages: $unreadCount');

      if (mounted) {
        setState(() {
          _unreadCount = unreadCount;
          _isInitialized = true;
        });
        
        print('💬 Chat badge updated: $_unreadCount unread messages');
      }
    } catch (e) {
      print('❌ Error updating chat badge count: $e');
      // Handle permission errors gracefully
      if (e.toString().contains('permission-denied')) {
        print('🔍 DEBUG: Permission denied for chat badge count update');
        if (mounted) {
          setState(() {
            _unreadCount = 0;
            _isInitialized = true;
          });
        }
      }
    }
  }

  Future<void> _getUnreadCountOnce(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where(Filter.or(
            Filter('buyerId', isEqualTo: userId),
            Filter('sellerId', isEqualTo: userId),
          ))
          .get();

      int unreadCount = 0;
      print('🔍 DEBUG: Found ${snapshot.docs.length} chats for user: $userId (fallback)');

      for (var chat in snapshot.docs) {
        final data = chat.data() as Map<String, dynamic>;
        final chatId = chat.id;
        final chatUnreadCount = data['unreadCount'] as int? ?? 0;
        final buyerId = data['buyerId'] as String?;
        final sellerId = data['sellerId'] as String?;
        final lastMessageBy = data['lastMessageBy'] as String?;
        
        print('🔍 DEBUG: Chat $chatId - unreadCount: $chatUnreadCount, buyerId: $buyerId, sellerId: $sellerId, lastMessageBy: $lastMessageBy (fallback)');
        
        // Only count unread messages if the last message was from someone else
        if (chatUnreadCount > 0 && lastMessageBy != null && lastMessageBy != userId) {
          unreadCount += chatUnreadCount;
          print('🔍 DEBUG: Adding $chatUnreadCount to total (last message from other user) (fallback)');
        } else if (chatUnreadCount > 0) {
          print('🔍 DEBUG: Skipping $chatUnreadCount (last message from current user or no last message) (fallback)');
        }
      }

      if (mounted) {
        setState(() {
          _unreadCount = unreadCount;
          _isInitialized = true;
        });
        print('💬 Chat badge fallback updated: $_unreadCount unread messages');
      }
    } catch (e) {
      print('❌ Error in chat badge fallback: $e');
      // Handle permission errors gracefully
      if (e.toString().contains('permission-denied')) {
        print('🔍 DEBUG: Permission denied for chat badge fallback');
        if (mounted) {
          setState(() {
            _unreadCount = 0;
            _isInitialized = true;
          });
        }
      }
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
    print('💬 Chat badge count manually reset');
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