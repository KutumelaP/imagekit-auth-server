import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'voice_service.dart';

/// Escalation detection for chatbot
/// Returns an [EscalationResult] if the input requires escalation,
/// otherwise returns null.

class EscalationResult {
  final String category; // e.g., "agent_request", "frustration"
  final String matchedText;

  EscalationResult({required this.category, required this.matchedText});

  @override
  String toString() =>
      'EscalationResult(category: $category, matchedText: "$matchedText")';
}

class EscalationDetector {
  // Keywords where user explicitly asks for a person/agent
  static final _agentWords = [
    r'agent',
    r'human',
    r'person',
    r'consultant',
    r'representative',
    r'manager',
    r'supervisor',
    r'someone',
    r'somebody',
  ];

  // Action phrases like "talk to" or "connect me to"
  static final _actionPhrases = [
    r'talk\s*to',
    r'speak\s*to',
    r'connect\s*me\s*to',
    r'transfer\s*me\s*to',
    r'i\s*want\s*to\s*(speak|talk)\s*to',
    r'i\s*need\s*to\s*(speak|talk)\s*to',
    r'can\s*i\s*(speak|talk)\s*to',
    r'may\s*i\s*(speak|talk)\s*to',
    r'is\s*there\s*(a\s*)?(person|human|agent)',
  ];

  // Words that show frustration or system not working
  static final _frustrationWords = [
    r"doesn't\s*work",
    r'not\s*working',
    r'not\s*helping',
    r'still\s*not\s*working',
    r'confused',
    r'lost',
    r'stuck',
    r'frustrated',
    r'angry',
    r'upset',
    r'disappointed',
    r'unsatisfied',
    r'not\s*satisfied',
    r'useless',
    r'pointless',
    r'waste\s*of\s*time',
  ];

  /// Escalation patterns grouped by category
  static final Map<String, RegExp> _patterns = {
    'agent_request': RegExp(r'\b(' + _agentWords.join('|') + r')\b',
        caseSensitive: false),
    'action_phrase': RegExp(r'\b(' + _actionPhrases.join('|') + r')\b',
        caseSensitive: false),
    'frustration': RegExp(r'\b(' + _frustrationWords.join('|') + r')\b',
        caseSensitive: false),
  };

  /// Detect escalation in [input].
  /// Returns an [EscalationResult] or null if no escalation detected.
  static EscalationResult? detect(String input) {
    for (final entry in _patterns.entries) {
      final match = entry.value.firstMatch(input);
      if (match != null) {
        return EscalationResult(
          category: entry.key,
          matchedText: match.group(0) ?? '',
        );
      }
    }
    return null;
  }
}

/// AI-powered chatbot service for customer support automation
class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Voice service for chatbot responses
  final VoiceService _voiceService = VoiceService();
  bool _voiceEnabled = true;


  bool isEscalation(String input) {
    return EscalationDetector.detect(input) != null;
  }
  
  // Stream controllers for real-time updates
  final StreamController<List<ChatMessage>> _messagesController = StreamController<List<ChatMessage>>.broadcast();
  final StreamController<bool> _typingController = StreamController<bool>.broadcast();
  
  String? _currentConversationId;
  List<ChatMessage> _messages = [];
  bool _isInitialized = false;
  bool _persistenceEnabled = true; // fallback to local-only when Firestore not permitted

  // Getters for streams
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  Stream<bool> get typingStream => _typingController.stream;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get hasActiveConversation => _currentConversationId != null;
  bool get voiceEnabled => _voiceEnabled;

  /// Initialize chatbot service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize voice service
      await _voiceService.initialize();
      
      // Load or create conversation for current user (lazy loading)
      await _loadOrCreateConversation();
      
      // Initialize knowledge base if empty (only once)
      if (_messages.isEmpty) {
        await _initializeKnowledgeBase();
      }
      
      _isInitialized = true;
    } catch (e) {
      // Silent fail for initialization
    }
  }

  /// Load existing conversation or create new one
  Future<void> _loadOrCreateConversation() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Enable local-only mode when not logged in
      _persistenceEnabled = false;
      _currentConversationId = 'local';
      _messages.clear();
      await _addWelcomeMessage();
      return;
    }

    try {
      // Try to find existing conversation (with timeout)
      final conversationsQuery = await _firestore
          .collection('chatbot_conversations')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('lastMessageAt', descending: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5)); // Add timeout

      if (conversationsQuery.docs.isNotEmpty) {
        // Load existing conversation
        _currentConversationId = conversationsQuery.docs.first.id;
        await _loadMessages();
      } else {
        // Create new conversation
        await _createNewConversation();
      }
    } catch (e) {
      // Fallback to local-only mode
      _persistenceEnabled = false;
      _currentConversationId = 'local';
      _messages.clear();
      await _addWelcomeMessage();
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
      // Fallback to local-only mode
      _persistenceEnabled = false;
      _currentConversationId = 'local';
      _messages.clear();
      await _addWelcomeMessage();
    }
  }

  /// Load messages from Firestore
  Future<void> _loadMessages() async {
    if (_currentConversationId == null) return;

    try {
      if (!_persistenceEnabled) {
        // Local-only mode: keep what we have
        _messagesController.add(_messages);
        return;
      }
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

  /// Add welcome message based on user role
  Future<void> _addWelcomeMessage() async {
    final user = _auth.currentUser;
    final userRole = await _getUserRole(user?.uid);
    
    String welcomeText;
    if (userRole == 'seller') {
      welcomeText = '''👋 Hi there! I'm your AI assistant for sellers on Food Marketplace.

I can help you with:
🏪 Store management and settings
📦 Order management and fulfillment
💰 Earnings, payouts, and COD tracking
📊 Sales analytics and performance
👥 Customer communication
🛠️ Technical support for sellers

What can I help you with today?''';
    } else {
      welcomeText = '''👋 Hi there! I'm your AI assistant for Food Marketplace.

I can help you with:
🛒 Order tracking and status updates
📦 Delivery information and pickup points
💳 Payment and billing questions
🏪 Finding stores and products
🔄 Returns and refunds
❓ General marketplace questions

What can I help you with today?''';
    }

    final welcomeMessage = ChatMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      text: welcomeText,
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
    final bool isLocal = _currentConversationId == 'local' || !_persistenceEnabled;
    if (user == null && !isLocal) {
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
      // Always add to local list
      _messages.add(message);
      _messagesController.add(_messages);

      // Voice announcement for bot messages
      if (!message.isUser && _voiceEnabled && message.text.isNotEmpty) {
        try {
          await _voiceService.speak(message.text);
        } catch (e) {
          print('❌ Error speaking chatbot message: $e');
        }
      }

      if (_persistenceEnabled) {
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
      }
    } catch (e) {
      print('❌ Error adding message: $e');
    }
  }

  /// Get user role from Firestore
  Future<String> _getUserRole(String? userId) async {
    if (userId == null) return 'buyer';
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['role'] ?? 'buyer';
      }
    } catch (e) {
      print('❌ Error getting user role: $e');
    }
    
    return 'buyer'; // Default to buyer
  }

  /// Generate AI response based on user input and role
  Future<String> _generateResponse(String userInput) async {
    try {
      final user = _auth.currentUser;
      final userRole = await _getUserRole(user?.uid);
      
      // Analyze user intent with role context
      final intent = _analyzeIntent(userInput.toLowerCase(), userRole);
      
      // Get role-aware context response
      return await _getContextualResponse(intent, userInput, userRole);
    } catch (e) {
      print('❌ Error in response generation: $e');
      return _getFallbackResponse();
    }
  }

  /// Analyze user intent from message with role context
  String _analyzeIntent(String input, [String userRole = 'buyer']) {
    // Seller-specific keywords
    if (userRole == 'seller') {
      if (input.contains(RegExp(r'\b(earnings|payout|commission|cod|cash.*delivery)\b'))) {
        return 'seller_earnings';
      }
      if (input.contains(RegExp(r'\b(customers|customer.*service|respond|reply)\b'))) {
        return 'seller_customer_service';
      }
      if (input.contains(RegExp(r'\b(sales|analytics|performance|dashboard)\b'))) {
        return 'seller_analytics';
      }
      if (input.contains(RegExp(r'\b(inventory|stock|product.*manage|add.*product)\b'))) {
        return 'seller_inventory';
      }
    }
    
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
    
    // Escalation / talk to a human - Enhanced detection
    if (isEscalation(input)) {
      return 'escalation';
    }
    
    return 'general';
  }

  /// Get contextual response based on intent and user role
  Future<String> _getContextualResponse(String intent, String userInput, String userRole) async {
    switch (intent) {
      // Seller-specific intents
      case 'seller_earnings':
        return await _getSellerEarningsResponse(userInput);
      case 'seller_customer_service':
        return await _getSellerCustomerServiceResponse(userInput);
      case 'seller_analytics':
        return await _getSellerAnalyticsResponse(userInput);
      case 'seller_inventory':
        return await _getSellerInventoryResponse(userInput);
        
      // Common intents (role-aware)
      case 'order_tracking':
        return await _getOrderTrackingResponse(userInput, userRole);
      case 'payment':
        return await _getPaymentResponse(userInput, userRole);
      case 'store_info':
        return await _getStoreInfoResponse(userInput, userRole);
      case 'returns':
        return await _getReturnsResponse(userInput, userRole);
      case 'account':
        return await _getAccountResponse(userInput, userRole);
      case 'delivery':
        return await _getDeliveryResponse(userInput, userRole);
      case 'help':
        return await _getHelpResponse(userInput, userRole);
      case 'escalation':
        return await _getEscalationResponse(userInput, userRole);
      default:
        return await _getGeneralResponse(userInput, userRole);
    }
  }

  /// Order tracking responses (role-aware)
  Future<String> _getOrderTrackingResponse(String input, [String userRole = 'buyer']) async {
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
      // Try to extract a specific order number from the user's input
      final extractedOrderNumber = _extractOrderNumber(input);
      if (extractedOrderNumber != null) {
        // First attempt: exact match on orderNumber
        final exactQuery = await _firestore
            .collection('orders')
            .where(userRole == 'seller' ? 'sellerId' : 'buyerId', isEqualTo: user.uid)
            .where('orderNumber', isEqualTo: extractedOrderNumber)
            .limit(1)
            .get();

        if (exactQuery.docs.isNotEmpty) {
          final doc = exactQuery.docs.first;
          final data = doc.data();
          final orderNumber = data['orderNumber'] ?? doc.id;
          final status = data['status'] ?? 'unknown';
          final paymentStatus = data['paymentStatus'] ?? 'unknown';
          final orderType = data['orderType'] ?? (data['isDelivery'] == true ? 'delivery' : 'pickup');
          final total = (data['totalPrice'] as num?)?.toDouble() ?? (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final ts = (data['timestamp'] as Timestamp?)?.toDate();

          return '''📦 Order ${orderNumber}
Status: ${_formatOrderStatus(status)}
Payment: ${paymentStatus}
Type: ${orderType}
Total: R${total.toStringAsFixed(2)}${ts != null ? '\nPlaced: ${ts.toLocal()}' : ''}

Would you like detailed delivery tracking or help with this order?''';
        }

        // Fallback: search in recent orders by partial contains (client-side filter)
        final recentForSearch = await _firestore
            .collection('orders')
            .where(userRole == 'seller' ? 'sellerId' : 'buyerId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .limit(25)
            .get();
        QueryDocumentSnapshot<Map<String, dynamic>>? matchDoc;
        for (final d in recentForSearch.docs) {
          final on = (d.data()['orderNumber'] ?? d.id).toString().toLowerCase();
          if (on.contains(extractedOrderNumber.toLowerCase())) {
            matchDoc = d;
            break;
          }
        }

        if (matchDoc != null) {
          final data = matchDoc.data();
          final orderNumber = data['orderNumber'] ?? matchDoc.id;
          final status = data['status'] ?? 'unknown';
          final paymentStatus = data['paymentStatus'] ?? 'unknown';
          final orderType = data['orderType'] ?? (data['isDelivery'] == true ? 'delivery' : 'pickup');
          final total = (data['totalPrice'] as num?)?.toDouble() ?? (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final ts = (data['timestamp'] as Timestamp?)?.toDate();

          return '''📦 Order ${orderNumber}
Status: ${_formatOrderStatus(status)}
Payment: ${paymentStatus}
Type: ${orderType}
Total: R${total.toStringAsFixed(2)}${ts != null ? '\nPlaced: ${ts.toLocal()}' : ''}

Would you like detailed delivery tracking or help with this order?''';
        }

        return '''I couldn't find an order matching "${extractedOrderNumber}" on your account.

Please double-check the order number (e.g., ORD-01012025-1205-123) or ask me to list your recent orders.''';
      }

      // No specific order number provided - show recent orders
      final ordersQuery = userRole == 'seller' 
          ? await _firestore
              .collection('orders')
              .where('sellerId', isEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .limit(3)
              .get()
          : await _firestore
              .collection('orders')
              .where('buyerId', isEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .limit(3)
              .get();

      if (ordersQuery.docs.isEmpty) {
        if (userRole == 'seller') {
          return '''I don't see any recent orders for your store.

You can:
🏪 Check if your store is active and open
📦 Add more products to attract customers
📞 Contact support if you think this is an error
❓ Ask me about promoting your store''';
        } else {
          return '''I don't see any recent orders for your account.

You can:
🛒 Browse products and place your first order
📞 Contact support if you think this is an error
❓ Ask me any other questions about the marketplace''';
        }
      }

      String response = userRole == 'seller' 
          ? '📦 Here are your recent customer orders:\n\n'
          : '📦 Here are your recent orders:\n\n';
      
      for (final doc in ordersQuery.docs) {
        final data = doc.data();
        final orderNumber = data['orderNumber'] ?? doc.id;
        final status = data['status'] ?? 'unknown';
        final total = (data['totalPrice'] as num?)?.toDouble() ?? (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        
        response += '''🔸 Order #${orderNumber.toString().substring(0, 8)}...
   Status: ${_formatOrderStatus(status)}
   Total: R${total.toStringAsFixed(2)}
   
''';
      }

      response += '''💡 For detailed tracking, visit the "My Orders" section in your profile.

Need help with a specific order? Share the order number (e.g., ORD-01012025-1205-123).''';

      return response;
    } catch (e) {
      return '''I'm having trouble accessing your order information right now.

You can:
📱 Check the "My Orders" section in your profile
📞 Contact our support team
🔄 Try again in a few moments''';
    }
  }

  /// Try to extract an order number like "ORD-..." or a short token that looks like one
  String? _extractOrderNumber(String input) {
    final lower = input.toLowerCase();
    final match = RegExp(r'(ord-[a-z0-9-]{5,})').firstMatch(lower);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }
    // Fallback: if the user provided a long token with dashes and digits, accept it
    final fallback = RegExp(r'([a-z0-9]{6,}(-[a-z0-9]{2,}){1,})').firstMatch(lower);
    if (fallback != null) {
      return fallback.group(1)!.toUpperCase();
    }
    return null;
  }

  /// Payment-related responses (role-aware)
  Future<String> _getPaymentResponse(String input, [String userRole = 'buyer']) async {
    if (userRole == 'seller') {
      return '''💳 Payment Help for Sellers

**Receiving Payments:**
🏦 Bank Transfer (EFT) - Instant to escrow
💳 Credit/Debit Cards - Via PayFast gateway
💰 Cash on Delivery - You collect directly

**Payment Processing:**
• Online payments → Escrow → Payouts
• COD payments → Your cash drawer
• Commission deducted from all sales
• Minimum R50 for payouts

**Common Issues:**
• COD disabled → Complete KYC verification
• Payout delays → Check bank details
• Commission questions → View earnings breakdown

**Managing COD:**
✅ Verify customer orders before preparing
✅ Collect exact change
✅ Mark orders as "paid" after collection

Need help with specific payment processing?''';
    } else {
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
  }

  /// Store information responses (role-aware)
  Future<String> _getStoreInfoResponse(String input, [String userRole = 'buyer']) async {
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
  Future<String> _getReturnsResponse(String input, [String userRole = 'buyer']) async {
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

  /// Account-related responses (role-aware)
  Future<String> _getAccountResponse(String input, [String userRole = 'buyer']) async {
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
  Future<String> _getDeliveryResponse(String input, [String userRole = 'buyer']) async {
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
  Future<String> _getHelpResponse(String input, [String userRole = 'buyer']) async {
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
  Future<String> _getGeneralResponse(String input, [String userRole = 'buyer']) async {
    // Try knowledge base first
    final kbAnswer = await _maybeGetKnowledgeBaseAnswer(input);
    if (kbAnswer != null) return kbAnswer;

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

  /// Search the Firestore knowledge base for a relevant answer
  Future<String?> _maybeGetKnowledgeBaseAnswer(String input) async {
    try {
      final lower = input.toLowerCase();
      final doc = await _firestore.collection('chatbot_knowledge').doc('faq').get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      final categories = (data['categories'] as Map<String, dynamic>?);
      if (categories == null) return null;

      String? bestAnswer;
      int bestScore = 0;

      for (final entry in categories.entries) {
        final questions = (entry.value['questions'] as List?)?.cast<Map<String, dynamic>>();
        if (questions == null) continue;
        for (final qa in questions) {
          final q = (qa['q'] ?? '').toString().toLowerCase();
          final a = (qa['a'] ?? '').toString();
          int score = 0;
          for (final token in lower.split(RegExp(r'[^a-z0-9]+'))) {
            if (token.length < 3) continue;
            if (q.contains(token)) score++;
          }
          if (score > bestScore && score >= 2) {
            bestScore = score;
            bestAnswer = a;
          }
        }
      }

      return bestAnswer;
    } catch (_) {
      return null;
    }
  }

  /// Create a support ticket and return acknowledgment text
  Future<String> _getEscalationResponse(String input, [String userRole = 'buyer']) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'Please log in so I can hand this over to a human agent.';
      }

      final lower = input.toLowerCase();
      String priority = 'normal';
      if (RegExp(r'(refund|charge|fraud|stolen|not\s*delivered|missing)').hasMatch(lower)) {
        priority = 'high';
      } else if (RegExp(r'(cancel|change|address|late)').hasMatch(lower)) {
        priority = 'normal';
      } else {
        priority = 'low';
      }

      final recent = _messages.take(8).map((m) => {
        'text': m.text,
        'isUser': m.isUser,
        'timestamp': m.timestamp.toIso8601String(),
        'type': m.type,
      }).toList();

      final ref = await _firestore.collection('support_tickets').add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'conversationId': _currentConversationId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
        'priority': priority,
        'lastUserMessage': input,
        'recentMessages': recent,
        'role': userRole,
        'source': 'chatbot',
      });

      final ticketIdShort = ref.id.substring(0, 6).toUpperCase();
      
      // Create a special message with consultant option
      final consultantMessage = ChatMessage(
        id: 'consultant_${DateTime.now().millisecondsSinceEpoch}',
        text: '''I have escalated this to a human agent. Your ticket ID is ${ticketIdShort}.

You can also speak directly to a consultant via WhatsApp for immediate assistance:''',
        isUser: false,
        timestamp: DateTime.now(),
        type: 'consultant_escalation',
        metadata: {
          'ticketId': ticketIdShort,
          'whatsappNumber': '27693617576',
          'whatsappMessage': 'Hi! I need help with my support ticket ${ticketIdShort}. Can you assist me?',
        },
      );
      
      await _addMessage(consultantMessage);
      return ''; // Return empty since we're adding a special message
    } catch (e) {
      return 'I tried to escalate this but ran into a problem. Please use the Help & Support option in the menu.';
    }
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

  /// Seller earnings and payouts responses
  Future<String> _getSellerEarningsResponse(String input) async {
    return '''💰 Seller Earnings & Payouts Help

**COD (Cash on Delivery) Tracking:**
• Cash collected from customers
• Commission owed to platform (10%)
• Your net share after commission
• View in Earnings & Payouts screen

**Payout Process:**
1️⃣ Complete KYC verification
2️⃣ Minimum R50 balance required
3️⃣ Request payout in app
4️⃣ Funds transferred within 2-3 business days

**COD Balance Issues:**
• Outstanding commission affects payouts
• Pay platform fees to unlock full balance
• Contact support for payment arrangements

Need help with specific earnings question?''';
  }

  /// Seller customer service responses
  Future<String> _getSellerCustomerServiceResponse(String input) async {
    return '''👥 Customer Service for Sellers

**Handling Customer Inquiries:**
• Respond to messages within 24 hours
• Use professional, friendly tone
• Provide clear order updates
• Address concerns promptly

**Common Customer Questions:**
🕐 "When will my order be ready?"
📦 "Can I change my delivery address?"
💳 "Payment issues or refunds"
🔄 "Returns and exchanges"

**Best Practices:**
✅ Set clear store hours
✅ Update order status regularly
✅ Provide tracking information
✅ Be proactive with delays

**Escalation:**
For complex issues, direct customers to platform support through the app menu.

Need help with a specific customer situation?''';
  }

  /// Seller analytics and performance responses
  Future<String> _getSellerAnalyticsResponse(String input) async {
    return '''📊 Sales Analytics & Performance

**Key Metrics to Track:**
📈 Total revenue and orders
🎯 Conversion rates
⭐ Customer ratings
🔄 Return rates

**Performance Insights:**
• Best-selling products
• Peak order times
• Customer demographics
• Seasonal trends

**Improving Performance:**
✅ Optimize product photos
✅ Competitive pricing
✅ Fast order fulfillment
✅ Excellent customer service
✅ Regular inventory updates

**Available Reports:**
• View in Seller Dashboard
• Revenue trends
• Order patterns
• Product performance

Want help analyzing specific metrics?''';
  }

  /// Seller inventory management responses
  Future<String> _getSellerInventoryResponse(String input) async {
    return '''📦 Inventory Management Help

**Stock Management:**
• Update stock levels regularly
• Set low-stock alerts
• Track inventory turnover
• Manage product variants

**Adding Products:**
📸 High-quality photos (multiple angles)
📝 Detailed descriptions
💰 Competitive pricing
🏷️ Accurate categories
📊 Initial stock quantity

**Inventory Best Practices:**
✅ Regular stock audits
✅ Seasonal inventory planning
✅ Monitor popular items
✅ Remove discontinued products
✅ Update prices competitively

**Out of Stock Management:**
• Mark items as unavailable
• Set restock notifications
• Communicate delays to customers

Need help with specific inventory tasks?''';
  }

  /// Enable or disable voice announcements
  void setVoiceEnabled(bool enabled) {
    _voiceEnabled = enabled;
  }

  /// Toggle voice announcements
  void toggleVoice() {
    _voiceEnabled = !_voiceEnabled;
  }

  /// Speak a custom message
  Future<void> speakMessage(String message) async {
    if (_voiceEnabled && message.isNotEmpty) {
      try {
        await _voiceService.speak(message);
      } catch (e) {
        print('❌ Error speaking custom message: $e');
      }
    }
  }

  /// Stop current voice playback
  Future<void> stopVoice() async {
    try {
      await _voiceService.stop();
    } catch (e) {
      print('❌ Error stopping voice: $e');
    }
  }

  /// Pause current voice playback
  Future<void> pauseVoice() async {
    try {
      await _voiceService.pause();
    } catch (e) {
      print('❌ Error pausing voice: $e');
    }
  }

  /// Resume paused voice playback
  Future<void> resumeVoice() async {
    try {
      await _voiceService.resume();
    } catch (e) {
      print('❌ Error resuming voice: $e');
    }
  }

  /// Get voice service status
  Map<String, dynamic> getVoiceStatus() {
    return {
      'voiceEnabled': _voiceEnabled,
      'isPlaying': _voiceService.isPlaying,
      'isPaused': _voiceService.isPaused,
      'googleTtsAvailable': _voiceService.isGoogleTtsAvailable,
      'currentText': _voiceService.currentText,
    };
  }

  /// Dispose resources
  void dispose() {
    _messagesController.close();
    _typingController.close();
    _voiceService.dispose();
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
