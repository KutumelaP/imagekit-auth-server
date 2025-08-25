import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// AI-powered chatbot service for customer support automation
class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stream controllers for real-time updates
  final StreamController<List<ChatMessage>> _messagesController = StreamController<List<ChatMessage>>.broadcast();
  final StreamController<bool> _typingController = StreamController<bool>.broadcast();
  
  String? _currentConversationId;
  List<ChatMessage> _messages = [];
  bool _isInitialized = false;

  // Getters for streams
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  Stream<bool> get typingStream => _typingController.stream;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get hasActiveConversation => _currentConversationId != null;

  /// Initialize chatbot service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load or create conversation for current user
      await _loadOrCreateConversation();
      
      // Initialize knowledge base if empty
      await _initializeKnowledgeBase();
      
      _isInitialized = true;
      print('🤖 Chatbot service initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize chatbot service: $e');
    }
  }

  /// Load existing conversation or create new one
  Future<void> _loadOrCreateConversation() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Try to find existing conversation
      final conversationsQuery = await _firestore
          .collection('chatbot_conversations')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('lastMessageAt', descending: true)
          .limit(1)
          .get();

      if (conversationsQuery.docs.isNotEmpty) {
        // Load existing conversation
        _currentConversationId = conversationsQuery.docs.first.id;
        await _loadMessages();
      } else {
        // Create new conversation
        await _createNewConversation();
      }
    } catch (e) {
      print('❌ Error loading conversation: $e');
      await _createNewConversation();
    }
  }

  /// Create new conversation
  Future<void> _createNewConversation() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final conversationDoc = await _firestore.collection('chatbot_conversations').add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'userName': user.displayName ?? 'Guest',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'messageCount': 0,
        'tags': <String>[],
        'priority': 'normal',
        'status': 'active',
      });

      _currentConversationId = conversationDoc.id;
      _messages.clear();

      // Send welcome message
      await _addWelcomeMessage();
      
      print('🤖 New conversation created: $_currentConversationId');
    } catch (e) {
      print('❌ Error creating conversation: $e');
    }
  }

  /// Load messages from Firestore
  Future<void> _loadMessages() async {
    if (_currentConversationId == null) return;

    try {
      final messagesQuery = await _firestore
          .collection('chatbot_conversations')
          .doc(_currentConversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      _messages = messagesQuery.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList();

      _messagesController.add(_messages);
    } catch (e) {
      print('❌ Error loading messages: $e');
    }
  }

  /// Add welcome message
  Future<void> _addWelcomeMessage() async {
    final welcomeMessage = ChatMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      text: '''👋 Hi there! I'm your AI assistant for Food Marketplace.

I can help you with:
🛒 Order tracking and status updates
📦 Delivery information and pickup points
💳 Payment and billing questions
🏪 Store information and hours
🔄 Returns and refunds
❓ General marketplace questions

What can I help you with today?''',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'welcome',
    );

    await _addMessage(welcomeMessage);
  }

  /// Send user message
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to send messages');
    }

    // Add user message
    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      type: 'text',
    );

    await _addMessage(userMessage);

    // Show typing indicator
    _typingController.add(true);

    try {
      // Generate AI response
      final response = await _generateResponse(text);
      
      // Add delay for more natural feel
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Add bot response
      final botMessage = ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
        type: 'text',
      );

      await _addMessage(botMessage);
    } catch (e) {
      print('❌ Error generating response: $e');
      
      // Add error message
      final errorMessage = ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        text: '''I apologize, but I'm having trouble processing your request right now. 

You can:
📞 Contact our support team directly
📧 Send us an email with your question
🔄 Try asking your question differently

Is there anything else I can help you with?''',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'error',
      );

      await _addMessage(errorMessage);
    } finally {
      // Hide typing indicator
      _typingController.add(false);
    }
  }

  /// Add message to conversation
  Future<void> _addMessage(ChatMessage message) async {
    if (_currentConversationId == null) return;

    try {
      // Add to local list
      _messages.add(message);
      _messagesController.add(_messages);

      // Save to Firestore
      await _firestore
          .collection('chatbot_conversations')
          .doc(_currentConversationId)
          .collection('messages')
          .doc(message.id)
          .set(message.toFirestore());

      // Update conversation metadata
      await _firestore
          .collection('chatbot_conversations')
          .doc(_currentConversationId)
          .update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('❌ Error adding message: $e');
    }
  }

  /// Generate AI response based on user input
  Future<String> _generateResponse(String userInput) async {
    try {
      // Analyze user intent
      final intent = _analyzeIntent(userInput.toLowerCase());
      
      // Get context-aware response
      return await _getContextualResponse(intent, userInput);
    } catch (e) {
      print('❌ Error in response generation: $e');
      return _getFallbackResponse();
    }
  }

  /// Analyze user intent from message
  String _analyzeIntent(String input) {
    // Order-related keywords
    if (input.contains(RegExp(r'\b(order|track|status|delivery|shipped|delivered)\b'))) {
      return 'order_tracking';
    }
    
    // Payment-related keywords
    if (input.contains(RegExp(r'\b(payment|pay|card|payfast|billing|charge|refund)\b'))) {
      return 'payment';
    }
    
    // Store/seller-related keywords
    if (input.contains(RegExp(r'\b(store|shop|seller|hours|open|closed|location)\b'))) {
      return 'store_info';
    }
    
    // Return/refund keywords
    if (input.contains(RegExp(r'\b(return|refund|exchange|cancel|problem|issue)\b'))) {
      return 'returns';
    }
    
    // Account-related keywords
    if (input.contains(RegExp(r'\b(account|profile|login|password|register|signup)\b'))) {
      return 'account';
    }
    
    // Delivery/pickup keywords
    if (input.contains(RegExp(r'\b(pickup|collect|pargo|paxi|delivery|address)\b'))) {
      return 'delivery';
    }
    
    // General help
    if (input.contains(RegExp(r'\b(help|how|what|where|when|support)\b'))) {
      return 'help';
    }
    
    return 'general';
  }

  /// Get contextual response based on intent
  Future<String> _getContextualResponse(String intent, String userInput) async {
    switch (intent) {
      case 'order_tracking':
        return await _getOrderTrackingResponse(userInput);
      case 'payment':
        return await _getPaymentResponse(userInput);
      case 'store_info':
        return await _getStoreInfoResponse(userInput);
      case 'returns':
        return await _getReturnsResponse(userInput);
      case 'account':
        return await _getAccountResponse(userInput);
      case 'delivery':
        return await _getDeliveryResponse(userInput);
      case 'help':
        return await _getHelpResponse(userInput);
      default:
        return await _getGeneralResponse(userInput);
    }
  }

  /// Order tracking responses
  Future<String> _getOrderTrackingResponse(String input) async {
    final user = _auth.currentUser;
    if (user == null) {
      return '''To track your orders, please log in to your account first.

Once logged in, I can help you:
📦 Check order status and tracking
🚚 View delivery information
📍 Track delivery progress
⏰ Get estimated delivery times''';
    }

    try {
      // Get user's recent orders
      final ordersQuery = await _firestore
          .collection('orders')
          .where('buyerId', isEqualTo: user.uid)
          .orderBy('orderDate', descending: true)
          .limit(3)
          .get();

      if (ordersQuery.docs.isEmpty) {
        return '''I don't see any recent orders for your account.

You can:
🛒 Browse products and place your first order
📞 Contact support if you think this is an error
❓ Ask me any other questions about the marketplace''';
      }

      String response = '📦 Here are your recent orders:\n\n';
      
      for (final doc in ordersQuery.docs) {
        final data = doc.data();
        final orderNumber = data['orderNumber'] ?? doc.id;
        final status = data['status'] ?? 'unknown';
        final total = data['totalAmount'] ?? 0;
        
        response += '''🔸 Order #${orderNumber.toString().substring(0, 8)}...
   Status: ${_formatOrderStatus(status)}
   Total: R${total.toStringAsFixed(2)}
   
''';
      }

      response += '''💡 For detailed tracking, visit the "My Orders" section in your profile.

Need help with a specific order? Just tell me the order number!''';

      return response;
    } catch (e) {
      return '''I'm having trouble accessing your order information right now.

You can:
📱 Check the "My Orders" section in your profile
📞 Contact our support team
🔄 Try again in a few moments''';
    }
  }

  /// Payment-related responses
  Future<String> _getPaymentResponse(String input) async {
    return '''💳 I can help with payment questions!

**Accepted Payment Methods:**
🏦 Bank Transfer (EFT)
💳 Credit/Debit Cards (via PayFast)
💰 Cash on Delivery (COD)
🏪 Store Pickup with Cash

**Common Payment Issues:**
• Card declined → Check with your bank
• PayFast errors → Verify card details
• COD unavailable → Check seller KYC status
• Refund delays → Usually 3-5 business days

**Need specific help?**
Tell me what payment issue you're experiencing, and I'll provide detailed assistance!''';
  }

  /// Store information responses
  Future<String> _getStoreInfoResponse(String input) async {
    return '''🏪 Store Information Help

**Finding Store Details:**
📍 Location and contact info on store profile
⏰ Operating hours displayed on each store
📞 Direct contact options available
⭐ Reviews and ratings from other customers

**Store Features:**
🚚 Delivery areas and fees
📦 Pickup options (store or PAXI/Pargo)
💰 Payment methods accepted
🎯 Product categories available

**Looking for a specific store?**
Tell me the store name or what you're looking for, and I'll help you find it!''';
  }

  /// Returns and refunds responses
  Future<String> _getReturnsResponse(String input) async {
    return '''🔄 Returns & Refunds Help

**Return Policy:**
📅 7-14 days return window (varies by seller)
📦 Items must be in original condition
📋 Return reason required
🏪 Some items may require store return

**Refund Process:**
1️⃣ Submit return request in "My Orders"
2️⃣ Seller reviews and approves
3️⃣ Return item as instructed
4️⃣ Refund processed (3-5 business days)

**Need to start a return?**
Go to "My Orders" → Select order → "Request Return"

Having trouble with a specific return? Tell me your order number and I'll help!''';
  }

  /// Account-related responses
  Future<String> _getAccountResponse(String input) async {
    return '''👤 Account Help

**Account Management:**
📧 Update email in Profile settings
🔒 Change password via "Forgot Password"
📱 Verify phone number for COD
🆔 Complete KYC for seller features

**Login Issues:**
🔐 Reset password if forgotten
📧 Check email for verification links
📱 Use correct email/phone number
🤝 Contact support for locked accounts

**Need specific account help?**
Tell me what account issue you're experiencing!''';
  }

  /// Delivery information responses
  Future<String> _getDeliveryResponse(String input) async {
    return '''🚚 Delivery & Pickup Help

**Delivery Options:**
🏠 Home delivery (urban areas)
🏔️ Rural delivery (extended areas)
🏪 Store pickup
📦 PAXI/Pargo pickup points

**Delivery Times:**
⚡ Same-day (food items, urban)
📅 1-3 days (standard items)
🏔️ 3-7 days (rural areas)

**Pickup Points:**
📍 Over 3000 PAXI locations
🏪 Pargo network available
💰 Often cheaper than home delivery

**Track your delivery:**
Check "My Orders" for real-time updates!''';
  }

  /// General help responses
  Future<String> _getHelpResponse(String input) async {
    return '''❓ General Help

**I can assist with:**
🛒 Shopping and placing orders
📦 Order tracking and delivery
💳 Payment methods and billing
🏪 Store information and hours
🔄 Returns and refunds
👤 Account management
📞 Contact information

**Popular Questions:**
• "Track my order [number]"
• "Payment methods available"
• "Store pickup vs delivery"
• "How to return an item"
• "COD not available why"

**What would you like help with?**
Just ask me anything about the marketplace!''';
  }

  /// General conversation responses
  Future<String> _getGeneralResponse(String input) async {
    final responses = [
      '''I understand you're asking about "${input.length > 50 ? input.substring(0, 50) + '...' : input}"

I'm here to help with marketplace questions! Some things I can assist with:
🛒 Orders and shopping
💳 Payment questions
🚚 Delivery information
🏪 Store details

Could you be more specific about what you need help with?''',

      '''Thanks for your question! I want to make sure I give you the best help possible.

Could you tell me more about:
📦 Are you asking about an order?
💳 Is this payment-related?
🏪 Do you need store information?
❓ Something else entirely?

The more details you share, the better I can assist you!''',

      '''I'm not quite sure how to help with that specific question, but I'm here to assist!

I'm great at helping with:
🎯 Order tracking and status
💰 Payment and billing questions
🚚 Delivery and pickup options
🔄 Returns and refunds
👥 Account support

What aspect of the marketplace can I help you with today?''',
    ];

    return responses[Random().nextInt(responses.length)];
  }

  /// Fallback response for errors
  String _getFallbackResponse() {
    return '''I apologize, but I'm having trouble understanding your request right now.

🤖 **What I can help with:**
• Order tracking and delivery updates
• Payment and billing questions
• Store information and hours
• Returns and refund process
• Account and profile issues

📞 **Need immediate help?**
Contact our support team directly through the app menu.

Please try rephrasing your question, and I'll do my best to help!''';
  }

  /// Format order status for display
  String _formatOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '⏳ Pending';
      case 'confirmed':
        return '✅ Confirmed';
      case 'preparing':
        return '👨‍🍳 Preparing';
      case 'ready':
        return '📦 Ready';
      case 'out_for_delivery':
        return '🚚 Out for Delivery';
      case 'delivered':
        return '✅ Delivered';
      case 'cancelled':
        return '❌ Cancelled';
      default:
        return '❓ $status';
    }
  }

  /// Initialize knowledge base with common Q&A
  Future<void> _initializeKnowledgeBase() async {
    try {
      // Check if knowledge base exists
      final knowledgeDoc = await _firestore.collection('chatbot_knowledge').doc('faq').get();
      
      if (!knowledgeDoc.exists) {
        // Create initial knowledge base
        await _firestore.collection('chatbot_knowledge').doc('faq').set({
          'title': 'Frequently Asked Questions',
          'lastUpdated': FieldValue.serverTimestamp(),
          'categories': {
            'orders': {
              'title': 'Orders & Delivery',
              'questions': [
                {
                  'q': 'How do I track my order?',
                  'a': 'Go to "My Orders" in your profile to see real-time tracking information.',
                },
                {
                  'q': 'When will my order be delivered?',
                  'a': 'Delivery times vary: Same-day for food (urban), 1-3 days for standard items, 3-7 days for rural areas.',
                },
                {
                  'q': 'Can I change my delivery address?',
                  'a': 'Contact the seller immediately after ordering. Changes may not be possible once order is confirmed.',
                },
              ],
            },
            'payments': {
              'title': 'Payment & Billing',
              'questions': [
                {
                  'q': 'What payment methods do you accept?',
                  'a': 'We accept bank transfers, credit/debit cards via PayFast, and Cash on Delivery.',
                },
                {
                  'q': 'Why is COD not available?',
                  'a': 'COD requires identity verification and may be disabled for sellers with outstanding fees.',
                },
                {
                  'q': 'How long do refunds take?',
                  'a': 'Refunds are processed within 3-5 business days once the return is approved.',
                },
              ],
            },
          },
        });
        
        print('🤖 Knowledge base initialized');
      }
    } catch (e) {
      print('❌ Error initializing knowledge base: $e');
      // Continue without knowledge base - chatbot will still work with built-in responses
    }
  }

  /// Clear conversation history
  Future<void> clearConversation() async {
    if (_currentConversationId == null) return;

    try {
      // Mark conversation as inactive
      await _firestore
          .collection('chatbot_conversations')
          .doc(_currentConversationId)
          .update({'isActive': false});

      // Create new conversation
      await _createNewConversation();
    } catch (e) {
      print('❌ Error clearing conversation: $e');
    }
  }

  /// Get conversation history for admin
  Future<List<Map<String, dynamic>>> getConversationHistory({int limit = 50}) async {
    try {
      final conversationsQuery = await _firestore
          .collection('chatbot_conversations')
          .orderBy('lastMessageAt', descending: true)
          .limit(limit)
          .get();

      return conversationsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Error fetching conversation history: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _messagesController.close();
    _typingController.close();
  }
}

/// Chat message model
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String type;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.type = 'text',
    this.metadata,
  });

  /// Create from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      text: data['text'] ?? '',
      isUser: data['isUser'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'text',
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
