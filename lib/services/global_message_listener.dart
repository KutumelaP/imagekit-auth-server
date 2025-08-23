// ignore_for_file: duplicate_import
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'awesome_notification_service.dart' as an;
import 'notification_service.dart';

class GlobalMessageListener {
  static final GlobalMessageListener _instance = GlobalMessageListener._internal();
  factory GlobalMessageListener() => _instance;
  GlobalMessageListener._internal();

  final Map<String, StreamSubscription> _chatListeners = {};
  final Map<String, String> _lastMessageIds = {};
  final Map<String, bool> _chatInitialized = {};

  // Start listening to all chats for the current user
  Future<void> startListening() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Listen to all chats where the current user is either buyer or seller
      final chatsQuery = FirebaseFirestore.instance
          .collection('chats')
          .where('buyerId', isEqualTo: currentUser.uid)
          .snapshots();

      final sellerChatsQuery = FirebaseFirestore.instance
          .collection('chats')
          .where('sellerId', isEqualTo: currentUser.uid)
          .snapshots();

      // Listen to buyer chats
      chatsQuery.listen((snapshot) {
        for (final doc in snapshot.docs) {
          _listenToChatMessages(doc.id, currentUser.uid);
        }
      });

      // Listen to seller chats
      sellerChatsQuery.listen((snapshot) {
        for (final doc in snapshot.docs) {
          _listenToChatMessages(doc.id, currentUser.uid);
        }
      });

      print('🔔 Global message listener started');
    } catch (e) {
      print('❌ Error starting global message listener: $e');
    }
  }

  // Listen to messages in a specific chat
  void _listenToChatMessages(String chatId, String currentUserId) {
    // Don't create duplicate listeners
    if (_chatListeners.containsKey(chatId)) return;

    try {
      final messagesQuery = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots();

             final subscription = messagesQuery.listen((snapshot) async {
         if (snapshot.docs.isNotEmpty) {
           final latestMessage = snapshot.docs.first;
           final messageData = latestMessage.data();
           final senderId = messageData['senderId'] as String?;
           
            // On initial load decide whether to notify based on lastViewed vs latest message time
            if (_chatInitialized[chatId] != true) {
              _chatInitialized[chatId] = true;
              bool handledInitial = false;
              try {
                if (senderId != null && senderId != currentUserId) {
                  final chatDoc = await FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .get();
                  final chatData = chatDoc.data();
                  final lastViewed = chatData != null
                      ? chatData['lastViewed_$currentUserId'] as Timestamp?
                      : null;
                  final msgTs = messageData['timestamp'] as Timestamp?;
                  final isUnseen = msgTs == null || lastViewed == null || msgTs.toDate().isAfter(lastViewed.toDate());
                  if (isUnseen) {
                    // Treat as new unseen message on startup: increment unread and notify
                    _lastMessageIds[chatId] = latestMessage.id;
                    print('🔔 Initial load: unseen message detected for chat $chatId; notifying.');

                    await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .update({
                      'unreadCount': FieldValue.increment(1),
                      'lastMessage': messageData['text'] ?? '',
                      'lastMessageBy': senderId,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .doc(latestMessage.id)
                        .update({'status': 'delivered'});

                    await _showNotificationForMessage(chatId, messageData);
                    handledInitial = true;
                  }
                }
              } catch (e) {
                print('❌ Error handling initial snapshot for chat $chatId: $e');
              }

              if (!handledInitial) {
                _lastMessageIds[chatId] = latestMessage.id;
                print('🔔 Seeded last message for chat $chatId on initial load; skipping notification.');
              }
              return;
            }

                       // Only show notification if:
            // 1. Message is from someone else
            // 2. It's a new message (not the same as last seen)
            // 3. The app is not currently in the foreground for this chat
              if (senderId != null && 
                senderId != currentUserId && 
                latestMessage.id != _lastMessageIds[chatId]) {
              
              _lastMessageIds[chatId] = latestMessage.id;
              
              // Update unread count in chat document only for the receiver
              // Don't update if the current user is the sender
              if (senderId != currentUserId) {
                print('🔔 Updating unread count for chat: $chatId');
                 await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .update({
                  'unreadCount': FieldValue.increment(1),
                  'lastMessage': messageData['text'] ?? '',
                  'lastMessageBy': senderId,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                
                // Mark message as delivered for the receiver
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .doc(latestMessage.id)
                    .update({
                  'status': 'delivered',
                });
                
                print('🔔 Unread count updated for chat: $chatId');
              } else {
                print('🔔 Skipping unread count update - message from current user');
                // For sender's own messages, mark as delivered immediately
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .doc(latestMessage.id)
                    .update({
                  'status': 'delivered',
                });
                print('🔔 Marked own message as delivered');
              }
              
              await _showNotificationForMessage(chatId, messageData);
            }
         }
       });

      _chatListeners[chatId] = subscription;
      print('🔔 Started listening to chat: $chatId');
    } catch (e) {
      print('❌ Error listening to chat $chatId: $e');
    }
  }

  // Show notification for incoming message
  Future<void> _showNotificationForMessage(String chatId, Map<String, dynamic> messageData) async {
    final messageText = messageData['text'] ?? '';
    final senderId = messageData['senderId'] as String?;
    
    print('🔔 Processing message for notification: chatId=$chatId, senderId=$senderId, text="$messageText"');
    
    if (senderId == null) {
      print('❌ No senderId found in message data');
      return;
    }

    // Get current user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No current user found');
      return;
    }

    // Don't show notification for messages sent by the current user
    if (senderId == currentUser.uid) {
      print('🔔 Skipping notification - message sent by current user');
      return;
    }

    // Get chat information to determine the recipient
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      
      final chatData = chatDoc.data();
      if (chatData == null) {
        print('❌ No chat data found for chatId: $chatId');
        return;
      }

      final buyerId = chatData['buyerId'] as String?;
      final sellerId = chatData['sellerId'] as String?;

      print('🔔 Chat participants: buyerId=$buyerId, sellerId=$sellerId, currentUser=${currentUser.uid}');

      // Verify that the current user is part of this chat
      if (currentUser.uid != buyerId && currentUser.uid != sellerId) {
        print('❌ ERROR: Current user ${currentUser.uid} is not part of chat $chatId (buyerId: $buyerId, sellerId: $sellerId)');
        return;
      }

      // Verify that the sender is actually a participant in this chat
      if (senderId != buyerId && senderId != sellerId) {
        print('❌ ERROR: Sender $senderId is not part of chat $chatId (buyerId: $buyerId, sellerId: $sellerId)');
        return;
      }

      // Get sender's name
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      
      final senderName = senderDoc.data()?['displayName'] ?? 
                        senderDoc.data()?['email']?.split('@')[0] ?? 
                        'Someone';

      print('🔔 Sending notification to ${currentUser.uid} from $senderName');

      // Local system notification
      await an.AwesomeNotificationService().showChatNotification(
        chatId: chatId,
        senderId: senderId,
        message: messageText,
      );

      // Immediate TTS announce if enabled
      try {
        await NotificationService().speakPreview('New message from $senderName. $messageText');
      } catch (_) {}

      print('🔔 Local system notification sent to ${currentUser.uid} for chat $chatId from $senderName');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }



  // Stop listening to a specific chat
  void stopListeningToChat(String chatId) {
    final subscription = _chatListeners[chatId];
    if (subscription != null) {
      subscription.cancel();
      _chatListeners.remove(chatId);
      _lastMessageIds.remove(chatId);
        _chatInitialized.remove(chatId);
      print('🔔 Stopped listening to chat: $chatId');
    }
  }

  // Stop all listeners
  void stopAllListeners() {
    for (final subscription in _chatListeners.values) {
      subscription.cancel();
    }
    _chatListeners.clear();
    _lastMessageIds.clear();
      _chatInitialized.clear();
    print('🔔 Stopped all global message listeners');
  }

  // Dispose
  void dispose() {
    stopAllListeners();
  }
} 