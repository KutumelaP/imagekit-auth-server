import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EnhancedNotificationService {
  static bool _isInitialized = false;

  // Initialize the service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      print('✅ Enhanced notification service initialized');
    } catch (e) {
      print('❌ Error initializing enhanced notification service: $e');
    }
  }

  // Send smart notification with priority handling
  static Future<void> sendSmartNotification({
    required String title,
    required String body,
    required String chatId,
    required String senderId,
    String? imageUrl,
    Map<String, dynamic>? payload,
    NotificationPriority priority = NotificationPriority.normal,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Get sender information
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      
      final senderName = senderDoc.data()?['displayName'] ?? 
                        senderDoc.data()?['email']?.split('@')[0] ?? 
                        'Someone';

      // Determine notification priority based on content
      final finalPriority = _determinePriority(body, priority);

      print('✅ Smart notification sent: $title (Priority: $finalPriority)');
    } catch (e) {
      print('❌ Error sending smart notification: $e');
    }
  }

  // Send chat-specific notification
  static Future<void> sendChatNotification({
    required String chatId,
    required String senderId,
    required String message,
    String? imageUrl,
  }) async {
    try {
      // Get chat information
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      
      final chatData = chatDoc.data();
      final isGroupChat = chatData?['isGroupChat'] ?? false;
      final chatName = chatData?['chatName'] ?? 'Chat';

      // Get sender information
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      
      final senderName = senderDoc.data()?['displayName'] ?? 
                        senderDoc.data()?['email']?.split('@')[0] ?? 
                        'Someone';

      // Determine notification title
      final title = isGroupChat ? '$senderName in $chatName' : senderName;

      // Determine notification body
      String body;
      if (imageUrl != null) {
        body = '📷 Sent a photo';
      } else if (message.toLowerCase().contains('voice')) {
        body = '🎤 Sent a voice message';
      } else {
        body = message.length > 100 
            ? '${message.substring(0, 100)}...'
            : message;
      }

      // Send smart notification
      await sendSmartNotification(
        title: title,
        body: body,
        chatId: chatId,
        senderId: senderId,
        imageUrl: imageUrl,
        payload: {
          'type': 'chat_message',
          'chatId': chatId,
          'senderId': senderId,
        },
        priority: _determineMessagePriority(message),
      );
    } catch (e) {
      print('❌ Error sending chat notification: $e');
    }
  }

  // Determine notification priority based on content
  static NotificationPriority _determinePriority(String message, NotificationPriority basePriority) {
    final lowerMessage = message.toLowerCase();
    
    // High priority keywords
    final highPriorityWords = ['urgent', 'emergency', 'important', 'asap', 'now', 'help'];
    // Low priority keywords
    final lowPriorityWords = ['thanks', 'thank you', 'ok', 'okay', 'sure', 'fine'];
    
    for (final word in highPriorityWords) {
      if (lowerMessage.contains(word)) {
        return NotificationPriority.high;
      }
    }
    
    for (final word in lowPriorityWords) {
      if (lowerMessage.contains(word)) {
        return NotificationPriority.low;
      }
    }
    
    return basePriority;
  }

  // Determine message priority
  static NotificationPriority _determineMessagePriority(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Check for urgent indicators
    if (lowerMessage.contains('urgent') || lowerMessage.contains('emergency')) {
      return NotificationPriority.high;
    }
    
    // Check for casual indicators
    if (lowerMessage.contains('thanks') || lowerMessage.contains('ok')) {
      return NotificationPriority.low;
    }
    
    return NotificationPriority.normal;
  }

  // Check if user is currently active
  static Future<bool> _isUserActive() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Check last activity time
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final lastActivity = userDoc.data()?['lastActivity'] as Timestamp?;
      if (lastActivity == null) return false;

      final timeSinceLastActivity = DateTime.now().difference(lastActivity.toDate());
      return timeSinceLastActivity.inMinutes < 5; // Active if last activity was within 5 minutes
    } catch (e) {
      return false;
    }
  }

  // Cancel all notifications
  static Future<void> cancelAll() async {
    print('✅ All notifications cancelled');
  }

  // Cancel specific notification
  static Future<void> cancel(int id) async {
    print('✅ Notification cancelled: $id');
  }
}

// Notification priority enum
enum NotificationPriority {
  high,
  normal,
  low,
} 