import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AIChatAssistant {
  static final List<String> _commonSuggestions = [
    "Hi! How can I help you today?",
    "What are you looking for?",
    "Do you have any questions about our products?",
    "Would you like to see our latest offers?",
    "Is there anything specific you'd like to know?",
    "How can I assist you with your order?",
    "Are you satisfied with our service?",
    "Thank you for choosing us!",
    "Have a great day!",
    "Feel free to ask if you need anything else!",
  ];

  static final List<String> _customerSuggestions = [
    "I'd like to place an order",
    "What's your delivery time?",
    "Do you have any special offers?",
    "Can you tell me more about this product?",
    "What are your payment options?",
    "Is this item in stock?",
    "Can I customize my order?",
    "What's your return policy?",
    "Do you offer discounts?",
    "How fresh are your ingredients?",
  ];

  static final List<String> _sellerSuggestions = [
    "Thank you for your order!",
    "Your order is being prepared",
    "Your order is ready for pickup",
    "Your order is out for delivery",
    "We're experiencing high demand",
    "We'll notify you when ready",
    "Is there anything else you need?",
    "We appreciate your business!",
    "Your feedback is important to us",
    "Have a wonderful day!",
  ];

  // Get AI-powered suggestions based on context
  static Future<List<String>> getSuggestions({
    required String userRole,
    required String chatContext,
    String? lastMessage,
  }) async {
    List<String> suggestions = [];

    // Add role-specific suggestions
    if (userRole == 'seller') {
      suggestions.addAll(_sellerSuggestions);
    } else {
      suggestions.addAll(_customerSuggestions);
    }

    // Add context-aware suggestions
    if (lastMessage != null) {
      final lowerMessage = lastMessage.toLowerCase();
      
      if (lowerMessage.contains('order') || lowerMessage.contains('buy')) {
        suggestions.addAll([
          "Great choice! When would you like it delivered?",
          "Perfect! Any special instructions?",
          "Excellent! Would you like to add anything else?",
        ]);
      }
      
      if (lowerMessage.contains('delivery') || lowerMessage.contains('time')) {
        suggestions.addAll([
          "We deliver within 30-45 minutes",
          "Delivery is free for orders over R20",
          "You can track your order in real-time",
        ]);
      }
      
      if (lowerMessage.contains('price') || lowerMessage.contains('cost')) {
        suggestions.addAll([
          "Our prices are competitive and fair",
          "We offer bulk discounts",
          "Check out our daily specials!",
        ]);
      }
    }

    // Add general suggestions
    suggestions.addAll(_commonSuggestions);

    // Shuffle and return top 5 suggestions
    suggestions.shuffle();
    return suggestions.take(5).toList();
  }

  // Analyze message sentiment
  static String analyzeSentiment(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Positive indicators
    final positiveWords = ['good', 'great', 'excellent', 'amazing', 'love', 'perfect', 'wonderful', 'fantastic', 'awesome', 'best'];
    // Negative indicators  
    final negativeWords = ['bad', 'terrible', 'awful', 'hate', 'worst', 'disappointed', 'poor', 'horrible', 'disgusting', 'unacceptable'];
    
    int positiveCount = 0;
    int negativeCount = 0;
    
    for (final word in positiveWords) {
      if (lowerMessage.contains(word)) positiveCount++;
    }
    
    for (final word in negativeWords) {
      if (lowerMessage.contains(word)) negativeCount++;
    }
    
    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
  }

  // Generate smart auto-reply
  static String generateAutoReply({
    required String message,
    required String userRole,
    required String sentiment,
  }) {
    final lowerMessage = message.toLowerCase();
    
    // Handle common queries
    if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return userRole == 'seller' 
          ? "Hello! Welcome to our store. How can I help you today?"
          : "Hi there! Thanks for reaching out. What can I assist you with?";
    }
    
    if (lowerMessage.contains('thank')) {
      return "You're very welcome! 😊";
    }
    
    if (lowerMessage.contains('bye') || lowerMessage.contains('goodbye')) {
      return "Goodbye! Have a wonderful day! 👋";
    }
    
    // Handle sentiment-based replies
    if (sentiment == 'positive') {
      return "That's wonderful to hear! We're so glad you're happy! 😊";
    }
    
    if (sentiment == 'negative') {
      return "I'm sorry to hear that. Please let me know how I can help improve your experience.";
    }
    
    // Default reply
    return "Thanks for your message! I'll get back to you soon.";
  }

  // Track conversation analytics
  static Future<void> trackConversation({
    required String chatId,
    required String message,
    required String senderRole,
    required String sentiment,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('chat_analytics')
          .add({
        'chatId': chatId,
        'message': message,
        'senderRole': senderRole,
        'sentiment': sentiment,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error tracking conversation: $e');
    }
  }
} 