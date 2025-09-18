import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/voice_service.dart';
import 'onboarding_voice_guide.dart';
import 'nathan_conversation_manager.dart';

/// AI Speech Assistant Service for onboarding and user guidance
class VoiceAssistantService {
  static final VoiceAssistantService _instance = VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  final VoiceService _voiceService = VoiceService();
  final NathanConversationManager _conversationManager = NathanConversationManager();
  
  // Assistant state
  bool _isActive = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String? _currentContext;
  String? _userName;
  bool _isNewUser = false;
  
  // Stream controllers for UI updates
  final StreamController<bool> _listeningController = StreamController<bool>.broadcast();
  final StreamController<bool> _processingController = StreamController<bool>.broadcast();
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  
  // Getters
  bool get isActive => _isActive;
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  String? get currentContext => _currentContext;
  String? get userName => _userName;
  bool get isNewUser => _isNewUser;
  
  // Streams
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<bool> get processingStream => _processingController.stream;
  Stream<String> get responseStream => _responseController.stream;

  /// Initialize the voice assistant
  Future<void> initialize({String? userName, bool isNewUser = false}) async {
    try {
      await _voiceService.initialize();
      _userName = userName;
      _isNewUser = isNewUser;
      _isActive = true;
      
      if (kDebugMode) {
        print('✅ Voice Assistant initialized for ${isNewUser ? 'new' : 'existing'} user: $userName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Voice Assistant: $e');
      }
    }
  }

  /// Start listening for user input
  Future<void> startListening() async {
    if (!_isActive || _isListening || _isProcessing) return;
    
    try {
      _isListening = true;
      _listeningController.add(true);
      
      if (kDebugMode) {
        print('🎤 Voice Assistant started listening');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting voice listening: $e');
      }
    }
  }

  /// Stop listening and process input
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      _isListening = false;
      _isProcessing = true;
      _listeningController.add(false);
      _processingController.add(true);
      
      // Simulate processing time
      await Future.delayed(Duration(milliseconds: 1500));
      
      // Generate response based on context
      final response = await _generateResponse();
      await _speakResponse(response);
      
      _isProcessing = false;
      _processingController.add(false);
      
      if (kDebugMode) {
        print('🎤 Voice Assistant processed input: $response');
      }
    } catch (e) {
      _isProcessing = false;
      _processingController.add(false);
      
      if (kDebugMode) {
        print('❌ Error processing voice input: $e');
      }
    }
  }

  /// Set current context for better responses
  void setContext(String context) {
    _currentContext = context;
    if (kDebugMode) {
      print('🎯 Voice Assistant context set to: $context');
    }
  }

  /// Generate appropriate response based on context and user state
  Future<String> _generateResponse() async {
    final responses = _getContextualResponses();
    final random = Random();
    return responses[random.nextInt(responses.length)];
  }

  /// Get contextual responses based on current state
  List<String> _getContextualResponses() {
    if (_isNewUser) {
      return _getNewUserResponses();
    }
    
    switch (_currentContext?.toLowerCase()) {
      case 'home':
        return _getHomeScreenResponses();
      case 'products':
        return _getProductScreenResponses();
      case 'cart':
        return _getCartScreenResponses();
      case 'checkout':
        return _getCheckoutScreenResponses();
      case 'orders':
        return _getOrdersScreenResponses();
      case 'profile':
        return _getProfileScreenResponses();
      case 'seller':
        return _getSellerScreenResponses();
      default:
        return _getGeneralResponses();
    }
  }

  /// New user onboarding responses
  List<String> _getNewUserResponses() {
    return [
      "Hi! I'm Nathan, your little shopping buddy! I'm super excited to help you find awesome stuff and make shopping really fun and easy!",
      "Hello! I'm Nathan, and I'll be your cute helper in our marketplace. I love helping people find cool things and I make everything simple!",
      "Welcome! I'm Nathan, your adorable shopping friend. I can help you find what you need, show you how things work, or just chat about fun products!",
      "Yay, you're here! I'm Nathan, and I'm so happy to help you with shopping. Ask me anything - I love helping!",
    ];
  }

  /// Home screen responses
  List<String> _getHomeScreenResponses() {
    return [
      "You're on the home screen. Here you can browse featured products, see categories, and find great deals. What would you like to explore?",
      "Welcome to your shopping hub! I'm Nathan, and I'm here to help you find super cool products! You can look at different categories or search for fun stuff!",
      "This is your personal shopping space! I can help you find products, explain features, or guide you through placing an order. What would you like to explore?",
    ];
  }

  /// Product screen responses
  List<String> _getProductScreenResponses() {
    return [
      "You're browsing products. Tap any item to see details, or use the search bar to find specific products. Need help with anything?",
      "Looking at our product catalog. You can filter by category, price, or ratings. What type of products are you interested in?",
      "Here you can explore all our products. Tap the plus button to add items to your cart. Any questions about a specific product?",
    ];
  }

  /// Cart screen responses
  List<String> _getCartScreenResponses() {
    return [
      "You're viewing your cart. You can adjust quantities, remove items, or proceed to checkout. Ready to place your order?",
      "This is your shopping cart. Review your items and quantities before checking out. Need help with the checkout process?",
      "Your selected items are here. You can modify quantities or remove items. When you're ready, tap checkout to continue.",
    ];
  }

  /// Checkout screen responses
  List<String> _getCheckoutScreenResponses() {
    return [
      "You're at checkout. Choose your delivery method, payment option, and review your order details. Need help with any step?",
      "Almost done! Select your delivery address and payment method. I can explain the different options available.",
      "Final step! Review your order, choose delivery, and select payment. Any questions about the checkout process?",
    ];
  }

  /// Orders screen responses
  List<String> _getOrdersScreenResponses() {
    return [
      "Here you can view all your orders. Tap any order to see details or track delivery status. Need help with order tracking?",
      "Your order history is here. You can see order status, track deliveries, and reorder items. What would you like to know?",
      "This shows all your past and current orders. You can track delivery, view receipts, or reorder items. Any questions?",
    ];
  }

  /// Profile screen responses
  List<String> _getProfileScreenResponses() {
    return [
      "You're in your profile. Here you can update your information, view settings, and manage your account. Need help with anything?",
      "This is your account area. You can edit your profile, change settings, or view your order history. What would you like to do?",
      "Your personal dashboard. Update your details, manage preferences, or view your shopping history. Any questions?",
    ];
  }

  /// Seller screen responses
  List<String> _getSellerScreenResponses() {
    return [
      "You're in seller mode. Here you can manage your products, view orders, and track your sales. Need help with selling?",
      "Welcome to your seller dashboard. You can add products, manage inventory, and view analytics. What would you like to know?",
      "This is your selling hub. Manage products, process orders, and track your business performance. Any questions?",
    ];
  }

  /// General responses
  List<String> _getGeneralResponses() {
    return [
      "I'm here to help! You can ask me about shopping, orders, delivery, payments, or how to use any feature.",
      "What would you like to know? I can help with browsing products, placing orders, tracking deliveries, or using the app.",
      "I'm your shopping assistant. Feel free to ask me anything about the marketplace or how to use the features.",
      "How can I help you today? I can guide you through shopping, orders, or explain how different features work.",
    ];
  }

  /// Speak a message directly
  Future<void> speak(String message) async {
    try {
      await _voiceService.speak(message);
      _responseController.add(message);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error speaking message: $e');
      }
    }
  }

  /// Speak the response
  Future<void> _speakResponse(String response) async {
    try {
      await _voiceService.speak(response);
      _responseController.add(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error speaking response: $e');
      }
    }
  }

  /// Provide proactive guidance based on user actions
  Future<void> provideProactiveGuidance(String action) async {
    if (!_isActive) return;
    
    String guidance;
    switch (action.toLowerCase()) {
      case 'first_open':
        guidance = "Welcome! I'm your shopping assistant. I'll help you navigate the app and find great products. Just hold the mic button and ask me anything!";
        break;
      case 'first_cart_add':
        guidance = "Great! You've added an item to your cart. You can continue shopping or tap the cart icon to review your items.";
        break;
      case 'first_checkout':
        guidance = "You're ready to checkout! I can help you with delivery options, payment methods, or any questions about the process.";
        break;
      case 'first_order':
        guidance = "Congratulations on your first order! You can track it in the Orders tab. I'll notify you when it's ready for pickup or delivery.";
        break;
      default:
        return;
    }
    
    await _speakResponse(guidance);
  }

  /// Handle specific user questions with intelligent conversation
  Future<void> handleUserQuestion(String question) async {
    if (!_isActive) return;
    
    // Check if it's a common onboarding question first
    if (_isOnboardingQuestion(question)) {
      await OnboardingVoiceGuide.answerCommonQuestion(question);
      return;
    }
    
    // Use Nathan's intelligent conversation manager for smart responses
    if (_conversationManager.canHandleQuestion(question)) {
      final smartResponse = _conversationManager.processUserInput(question);
      await _speakResponse(smartResponse);
      
      if (kDebugMode) {
        print('🧠 Nathan answered intelligently: ${question.substring(0, min(question.length, 30))}...');
      }
      return;
    }
    
    // Fallback to basic response system
    final response = _getQuestionResponse(question);
    await _speakResponse(response);
  }
  
  /// Check if question is related to onboarding
  bool _isOnboardingQuestion(String question) {
    final q = question.toLowerCase();
    return q.contains('what') && q.contains('app') ||
           q.contains('how') && q.contains('buy') ||
           q.contains('how') && q.contains('sell') ||
           q.contains('delivery') ||
           q.contains('payment') ||
           q.contains('help') ||
           q.contains('support');
  }
  
  /// Start comprehensive onboarding for new users
  Future<void> startOnboarding({
    required String userName,
    required BuildContext context,
  }) async {
    await OnboardingVoiceGuide.startOnboarding(
      userName: userName,
      context: context,
    );
  }
  
  /// Provide contextual help for current screen
  Future<void> provideContextualHelp({
    required String screenName,
    required BuildContext context,
  }) async {
    await OnboardingVoiceGuide.provideContextualHelp(
      screenName: screenName,
      context: context,
    );
  }
  
  /// Check if user needs onboarding
  bool shouldShowOnboarding({
    required DateTime? userRegistrationDate,
    required bool hasPlacedOrder,
    required bool hasBrowsedProducts,
  }) {
    return OnboardingVoiceGuide.shouldShowOnboarding(
      userRegistrationDate: userRegistrationDate,
      hasPlacedOrder: hasPlacedOrder,
      hasBrowsedProducts: hasBrowsedProducts,
    );
  }

  /// Get response for specific questions
  String _getQuestionResponse(String question) {
    final q = question.toLowerCase();
    
    if (q.contains('how') && q.contains('order')) {
      return "To place an order, browse products, add items to your cart, then tap checkout. Choose delivery method and payment, then confirm your order.";
    }
    
    if (q.contains('how') && q.contains('cart')) {
      return "To add items to your cart, tap the plus button next to any product. To view your cart, tap the cart icon at the bottom.";
    }
    
    if (q.contains('how') && q.contains('track')) {
      return "To track your order, go to the Orders tab and tap on your order. You'll see real-time delivery updates there.";
    }
    
    if (q.contains('payment')) {
      return "We accept various payment methods including credit cards, mobile payments, and cash on delivery. Choose your preferred method at checkout.";
    }
    
    if (q.contains('delivery')) {
      return "We offer delivery to your address or pickup from our partner locations. You can choose your preferred option at checkout.";
    }
    
    if (q.contains('help') || q.contains('support')) {
      return "I'm here to help! You can ask me about shopping, orders, delivery, payments, or how to use any feature. What would you like to know?";
    }
    
    return "I understand you're asking about $question. Let me help you with that. Could you be more specific about what you'd like to know?";
  }

  /// Toggle assistant on/off
  void toggleAssistant() {
    _isActive = !_isActive;
    if (!_isActive) {
      _isListening = false;
      _isProcessing = false;
      _listeningController.add(false);
      _processingController.add(false);
    }
  }

  /// Get assistant status
  Map<String, dynamic> getStatus() {
    return {
      'isActive': _isActive,
      'isListening': _isListening,
      'isProcessing': _isProcessing,
      'currentContext': _currentContext,
      'userName': _userName,
      'isNewUser': _isNewUser,
      'voiceServiceAvailable': _voiceService.isGoogleTtsAvailable,
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    _isActive = false;
    _isListening = false;
    _isProcessing = false;
    
    await _listeningController.close();
    await _processingController.close();
    await _responseController.close();
    await _voiceService.dispose();
  }
}
