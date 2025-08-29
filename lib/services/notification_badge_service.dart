import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationBadgeService {
  static final NotificationBadgeService _instance = NotificationBadgeService._internal();
  factory NotificationBadgeService() => _instance;
  NotificationBadgeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<QuerySnapshot>? _buyerChatsSub;
  StreamSubscription<QuerySnapshot>? _sellerChatsSub;
  final Map<String, StreamSubscription<QuerySnapshot>> _messageSubs = {};
  
  int _unreadCount = 0;
  bool _isInitialized = false;

  // Getters
  int get unreadCount => _unreadCount;
  bool get isInitialized => _isInitialized;

  /// Initialize notification tracking
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _setupChatListeners(user.uid);
      }
      
      // Listen for auth state changes
      _auth.authStateChanges().listen((user) {
        if (user != null) {
          _setupChatListeners(user.uid);
        } else {
          _cleanupListeners();
          _unreadCount = 0;
        }
      });
      
      _isInitialized = true;
    } catch (e) {
      // Silent fail for notification service
    }
  }

  void _setupChatListeners(String userId) {
    _cleanupListeners();

    // Listen for buyer chats
    _buyerChatsSub = _firestore
        .collection('chats')
        .where('buyerId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final chatDoc in snapshot.docs) {
        _listenForNewMessagesInChat(chatDoc.id, userId);
      }
    });

    // Listen for seller chats
    _sellerChatsSub = _firestore
        .collection('chats')
        .where('sellerId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final chatDoc in snapshot.docs) {
        _listenForNewMessagesInChat(chatDoc.id, userId);
      }
    });
  }

  void _listenForNewMessagesInChat(String chatId, String currentUserId) {
    if (_messageSubs.containsKey(chatId)) return;

    final subscription = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final latestMessage = snapshot.docs.first;
        final messageData = latestMessage.data();
        final senderId = messageData['senderId'] as String?;
        
        // Only count if message is from someone else
        if (senderId != null && senderId != currentUserId) {
          _updateUnreadCount();
        }
      }
    });

    _messageSubs[chatId] = subscription;
  }

  void _updateUnreadCount() {
    // Simple increment - could be made more sophisticated
    _unreadCount++;
    // Could notify listeners here if needed
  }

  void _cleanupListeners() {
    _buyerChatsSub?.cancel();
    _sellerChatsSub?.cancel();
    for (final sub in _messageSubs.values) {
      sub.cancel();
    }
    _messageSubs.clear();
  }

  /// Reset unread count (when user views notifications)
  void resetUnreadCount() {
    _unreadCount = 0;
  }

  /// Cleanup resources
  void dispose() {
    _cleanupListeners();
  }
}
