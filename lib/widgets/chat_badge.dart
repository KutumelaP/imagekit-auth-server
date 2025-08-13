import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/safari_optimizer.dart';

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
  Timer? _debounceTimer;
  int _lastCount = 0;

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
          .snapshots(includeMetadataChanges: false); // Reduce metadata changes

      _subscription = chatsStream.listen(
        (snapshot) {
          if (mounted) {
            print('🔍 DEBUG: Chat badge stream update - ${snapshot.docs.length} chats');
            _debouncedUpdateBadgeCount(currentUserId);
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
            // Fallback: try to get count once
            _getUnreadCountOnce(currentUserId);
          }
        },
      );
      
      _isInitialized = true;
      print('💬 Chat badge initialized for user: $currentUserId');
    } catch (e) {
      print('❌ Error initializing chat badge: $e');
      // Fallback: try to get count once
      _getUnreadCountOnce(currentUserId);
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
        final lastMessageTime = data['lastMessageTime'] as Timestamp?;
        final lastViewedTime = data['lastViewed_$userId'] as Timestamp?;
        
        print('🔍 DEBUG: Chat $chatId - unreadCount: $chatUnreadCount, buyerId: $buyerId, sellerId: $sellerId, lastMessageBy: $lastMessageBy (fallback)');
        
        // Only count unread messages if:
        // 1. There are unread messages
        // 2. The last message was from someone else
        // 3. The user hasn't viewed the chat since the last message
        bool hasUnreadMessages = false;
        
        if (chatUnreadCount > 0 && lastMessageBy != null && lastMessageBy != userId) {
          // Check if user has viewed the chat since the last message
          if (lastMessageTime != null) {
            if (lastViewedTime == null) {
              // User has never viewed this chat, so all messages are unread
              hasUnreadMessages = true;
            } else if (lastMessageTime.toDate().isAfter(lastViewedTime.toDate())) {
              // Last message is newer than last viewed time
              hasUnreadMessages = true;
            }
          } else {
            // No last message time, but there are unread messages
            hasUnreadMessages = true;
          }
        }
        
        if (hasUnreadMessages) {
          unreadCount += chatUnreadCount;
          print('🔍 DEBUG: Adding $chatUnreadCount to total (truly unread messages) (fallback)');
        } else if (chatUnreadCount > 0) {
          print('🔍 DEBUG: Skipping $chatUnreadCount (already viewed or last message from current user) (fallback)');
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