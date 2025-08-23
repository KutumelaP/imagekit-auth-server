import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/ai_chat_assistant.dart';
import '../widgets/advanced_chat_widgets.dart';
import '../services/notification_service.dart';
import '../services/input_validator.dart';
import '../services/rate_limiter.dart';
import '../services/performance_monitor.dart';
import '../widgets/message_status_indicator.dart';
import '../widgets/home_navigation_button.dart';
import '../services/awesome_notification_service.dart';
import 'store_page.dart';
import 'package:flutter/services.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<String> _aiSuggestions = [];
  bool _isLoadingSuggestions = false; // used for AI suggestion loading state
  _ChatLifecycleObserver? _appLifecycleObserver;

  @override
  void initState() {
    super.initState();
    _loadAISuggestions();
    _markChatAsRead();
    _markChatAsViewed();
    // Also listen to app lifecycle to re-mark viewed when returning to foreground
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appLifecycleObserver ??= _ChatLifecycleObserver(onResume: _markChatAsViewed);
      WidgetsBinding.instance.addObserver(_appLifecycleObserver!);
    });
  }

  // Mark chat as viewed by current user
  Future<void> _markChatAsViewed() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      print('🔔 Marking chat as viewed by user: ${currentUser.uid}');
      
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastViewed_${currentUser.uid}': FieldValue.serverTimestamp(),
      });

      // Cancel any chat notifications for this conversation
      try {
        await AwesomeNotificationService().cancelAllNotifications();
        print('🔔 Cancelled chat notifications');
      } catch (e) {
        print('❌ Error cancelling chat notifications: $e');
      }

      print('🔔 Chat marked as viewed: ${widget.chatId}');
    } catch (e) {
      print('❌ Error marking chat as viewed: $e');
    }
  }

  // Mark chat as read when user opens it and keep updating lastViewed while visible
  Future<void> _markChatAsRead() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      print('🔔 Marking chat as read: ${widget.chatId}');

      // Get chat data to determine if current user should reset unread count
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      
      final chatData = chatDoc.data();
      if (chatData == null) return;

      final buyerId = chatData['buyerId'] as String?;
      final sellerId = chatData['sellerId'] as String?;
      final lastMessageBy = chatData['lastMessageBy'] as String?;
      final currentUnreadCount = chatData['unreadCount'] as int? ?? 0;

      print('🔔 Chat data - buyerId: $buyerId, sellerId: $sellerId, lastMessageBy: $lastMessageBy, unreadCount: $currentUnreadCount');

      // Only reset unread count if the last message was from the other user
      if (lastMessageBy != null && lastMessageBy != currentUser.uid && currentUnreadCount > 0) {
        print('🔔 Resetting unread count for chat: ${widget.chatId}');
        
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'unreadCount': 0,
          'lastViewed_${currentUser.uid}': FieldValue.serverTimestamp(),
        });

        // Mark all messages from the other user as read
        await _markMessagesAsRead(currentUser.uid);

        print('🔔 Chat marked as read: ${widget.chatId}');
        
        // Force refresh the notification badge
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // This will trigger a rebuild of the notification badge
          setState(() {});
        });
      } else {
        print('🔔 No need to reset unread count - last message from current user or no unread messages');
      }
    } catch (e) {
      print('❌ Error marking chat as read: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Periodically refresh lastViewed while on this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markChatAsViewed();
    });
  }

  // Format message timestamp
  String _formatMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      final DateTime messageTime = timestamp is Timestamp 
          ? timestamp.toDate() 
          : DateTime.parse(timestamp.toString());
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(messageTime);
      
      if (difference.inDays > 0) {
        return '${messageTime.day}/${messageTime.month}';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }

  // Mark messages as read
  Future<void> _markMessagesAsRead(String currentUserId) async {
    try {
      print('🔔 Marking messages as read for user: $currentUserId');
      
      // Get all messages from the other user that are not read
      final messagesQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        
        for (final doc in messagesQuery.docs) {
          batch.update(doc.reference, {
            'status': 'read',
            'readAt': FieldValue.serverTimestamp(),
          });
        }
        
        await batch.commit();
        print('🔔 Marked ${messagesQuery.docs.length} messages as read');
      }
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  @override
  void dispose() {
    if (_appLifecycleObserver != null) WidgetsBinding.instance.removeObserver(_appLifecycleObserver!);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAISuggestions() async {
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final suggestions = await PerformanceMonitor.monitor(
        'ai_suggestions_load',
        () => AIChatAssistant.getSuggestions(
          userRole: 'customer', // Default role
          chatContext: widget.chatId,
        ),
      );
      if (mounted) {
        setState(() {
          _aiSuggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _sendMessage({String messageType = 'text'}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Validate message input
    final validationError = InputValidator.validateAndSanitize(
      value: text,
      fieldName: 'message',
      validationType: 'message',
    );

    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Check rate limiting for message sending
    if (!RateLimiter.canSendMessage(currentUser.uid, widget.chatId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment before sending another message'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final sanitizedText = InputValidator.sanitizeInput(text);
      
      final message = {
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'text': sanitizedText,
        'status': 'sent', // Initial status - will be updated by GlobalMessageListener
        'readAt': null,
      };

      // Add to Firestore with performance monitoring
      await PerformanceMonitor.monitor('message_send', () async {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add(message);

        // Update the chat document with last message info
        // Don't increment unread count for sender's own messages
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'lastMessage': sanitizedText,
          'lastMessageBy': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
          // Note: unreadCount is handled by GlobalMessageListener for incoming messages
        });

        // Update seller avg response time when appropriate
        try {
          final chatSnap = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
          final chat = chatSnap.data();
          if (chat != null) {
            final sellerId = chat['sellerId'] as String?;
            final buyerId = chat['buyerId'] as String?;
            if (sellerId != null && buyerId != null) {
              final isSellerMsg = currentUser.uid == sellerId;
              print('🧭 ResponseTime: currentUser=${currentUser.uid}, sellerId=$sellerId, buyerId=$buyerId, isSellerMsg=$isSellerMsg');
              if (isSellerMsg) {
                print('🧭 ResponseTime: fetching recent messages for chat ${widget.chatId} to locate last buyer message...');
                // Fetch recent messages and find the last buyer message without requiring a composite index
                final recentMsgs = await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .get();
                print('🧭 ResponseTime: fetched ${recentMsgs.docs.length} recent messages');
                Timestamp? lastBuyerTs;
                for (final doc in recentMsgs.docs) {
                  final data = doc.data();
                  if (data['senderId'] == buyerId && data['timestamp'] is Timestamp) {
                    lastBuyerTs = data['timestamp'] as Timestamp;
                    print('🧭 ResponseTime: found last buyer message ts=${lastBuyerTs.toDate().toIso8601String()}');
                    break;
                  }
                }
                if (lastBuyerTs != null) {
                  final buyerTs = lastBuyerTs.toDate();
                  final sellerTs = DateTime.now();
                  if (buyerTs != null) {
                    final deltaMinutes = sellerTs.difference(buyerTs).inMinutes;
                    final userRef = FirebaseFirestore.instance.collection('users').doc(sellerId);
                    print('🧭 ResponseTime: deltaMinutes=$deltaMinutes — updating rolling average at users/$sellerId');
                    try {
                      await FirebaseFirestore.instance.runTransaction((tx) async {
                        final snap = await tx.get(userRef);
                        final existing = (snap.data()?['avgResponseMinutes'] as num?)?.toDouble();
                        final newAvg = existing == null ? deltaMinutes.toDouble() : ((existing * 4 + deltaMinutes) / 5);
                        tx.update(userRef, {'avgResponseMinutes': newAvg.round()});
                      });
                      print('🧭 ResponseTime: avgResponseMinutes write OK');
                    } catch (e) {
                      print('❌ ResponseTime: failed to write avgResponseMinutes for $sellerId — $e');
                    }
                  }
                } else {
                  print('🧭 ResponseTime: no prior buyer message found in last 50; skipping update');
                }
              } else {
                print('🧭 ResponseTime: current message not from seller; skipping avg update');
              }
            }
          }
        } catch (_) {}
      });

      print('🔔 Message sent with status: sent');

      // Note: Notifications are handled by GlobalMessageListener
      // No need to manually send notifications here

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }



  // Show search dialog for messages
  void _showSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search Messages'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: 'Enter search term...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  _searchMessages(value);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _searchMessages(searchController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  // Search messages in the current chat
  void _searchMessages(String searchTerm) {
    if (searchTerm.trim().isEmpty) return;
    
    // Check rate limiting for search
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && !RateLimiter.canSearch(currentUser.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait before searching again'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    
    // Navigate to search results or show results in a dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Search Results for "$searchTerm"'),
          content: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .collection('messages')
                .where('text', isGreaterThanOrEqualTo: searchTerm)
                .where('text', isLessThan: searchTerm + '\uf8ff')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No messages found.');
              }
              
              return SizedBox(
                height: 300,
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final message = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(message['text'] ?? ''),
                      subtitle: Text(
                        message['timestamp'] != null 
                            ? (message['timestamp'] as Timestamp).toDate().toString()
                            : 'Unknown time',
                      ),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Navigate to store
  void _navigateToStore() {
    // Navigate to the store selection screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StoreSelectionScreen(category: 'all'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool _keyboardOpen = media.viewInsets.bottom > 0;
    final double _messagesBottomPadding = _keyboardOpen ? 8.0 : (90 + media.padding.bottom);
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppTheme.whisper,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.deepTeal.withOpacity(0.1),
                AppTheme.whisper,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardBackgroundGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.complementaryElevation,
                  ),
                  child: Icon(
                    Icons.login,
                    size: 64,
                    color: AppTheme.deepTeal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please log in to access chats',
                  style: TextStyle(
                    color: AppTheme.darkGrey,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.otherUserName),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
            tooltip: 'Search Messages',
          ),
          // Explore store button
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: () {
              _navigateToStore();
            },
            tooltip: 'Explore Store',
          ),
          // Test notification button for debugging
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () async {
              await NotificationService().testNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Test notification sent!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            tooltip: 'Test Notification',
          ),
          // Home navigation button
          HomeNavigationButton(
            backgroundColor: AppTheme.deepTeal,
            iconColor: AppTheme.angel,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // AI Suggestions
          if (_aiSuggestions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              child: AISuggestionChips(
                suggestions: _aiSuggestions,
                onSuggestionTap: (suggestion) {
                  _messageController.text = suggestion;
                  _sendMessage();
                },
              ),
            ),
          
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                return ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: _messagesBottomPadding,
                    top: 4,
                  ),
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == FirebaseAuth.instance.currentUser?.uid;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          // Avatar for other person's messages
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.deepTeal.withOpacity(0.2),
                              child: Text(
                                widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : 'U',
                                style: TextStyle(
                                  color: AppTheme.deepTeal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          
                          // Message bubble
                          Flexible(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? AppTheme.deepTeal : Colors.grey[100],
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['text'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : AppTheme.deepTeal,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      MessageStatusIndicator(
                                        status: message['status'] ?? 'sent',
                                        isMe: isMe,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatMessageTime(message['timestamp']),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe ? Colors.white70 : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Avatar for own messages
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.deepTeal,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Message input with SafeArea and extra bottom padding
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatLifecycleObserver extends WidgetsBindingObserver {
  final Future<void> Function() onResume;
  _ChatLifecycleObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}
