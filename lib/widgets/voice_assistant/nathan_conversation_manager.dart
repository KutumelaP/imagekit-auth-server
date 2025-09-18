import 'dart:math';
import 'package:flutter/foundation.dart';
import 'nathan_knowledge_base.dart';

/// Conversation context for maintaining chat flow
class ConversationContext {
  final List<String> recentTopics;
  final String? lastQuestion;
  final String? lastAnswer;
  final DateTime lastInteraction;
  final Map<String, int> topicFrequency;

  ConversationContext({
    required this.recentTopics,
    this.lastQuestion,
    this.lastAnswer,
    required this.lastInteraction,
    required this.topicFrequency,
  });

  ConversationContext copyWith({
    List<String>? recentTopics,
    String? lastQuestion,
    String? lastAnswer,
    DateTime? lastInteraction,
    Map<String, int>? topicFrequency,
  }) {
    return ConversationContext(
      recentTopics: recentTopics ?? this.recentTopics,
      lastQuestion: lastQuestion ?? this.lastQuestion,
      lastAnswer: lastAnswer ?? this.lastAnswer,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      topicFrequency: topicFrequency ?? this.topicFrequency,
    );
  }
}

/// Nathan's Intelligent Conversation Manager
class NathanConversationManager {
  static final NathanConversationManager _instance = NathanConversationManager._internal();
  factory NathanConversationManager() => _instance;
  NathanConversationManager._internal();

  final NathanKnowledgeBase _knowledgeBase = NathanKnowledgeBase();
  
  ConversationContext _context = ConversationContext(
    recentTopics: [],
    lastInteraction: DateTime.now(),
    topicFrequency: {},
  );

  /// Process user input and generate intelligent response
  String processUserInput(String userInput) {
    final normalizedInput = userInput.toLowerCase().trim();
    
    // Handle greetings
    if (_isGreeting(normalizedInput)) {
      return _handleGreeting();
    }
    
    // Handle thanks
    if (_isThanking(normalizedInput)) {
      return _handleThanks();
    }
    
    // Handle complaints
    if (_isComplaint(normalizedInput)) {
      return _handleComplaint();
    }
    
    // Handle follow-up questions
    if (_isFollowUp(normalizedInput)) {
      return _handleFollowUp(normalizedInput);
    }
    
    // Try to get answer from knowledge base
    String response = _knowledgeBase.answerQuestion(userInput);
    
    // Add contextual information if appropriate
    response = _addContextualInfo(response, normalizedInput);
    
    // Update conversation context
    _updateContext(userInput, response);
    
    return response;
  }

  /// Check if input is a greeting
  bool _isGreeting(String input) {
    const greetings = ['hello', 'hi', 'hey', 'good morning', 'good afternoon', 'good evening', 'greetings'];
    return greetings.any((greeting) => input.contains(greeting));
  }

  /// Handle greeting
  String _handleGreeting() {
    final timeBasedGreeting = _getTimeBasedGreeting();
    final personalizedGreeting = _getPersonalizedGreeting();
    
    return "$timeBasedGreeting $personalizedGreeting";
  }

  /// Get time-based greeting
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    
    if (hour < 12) {
      return "Good morning!";
    } else if (hour < 17) {
      return "Good afternoon!";
    } else {
      return "Good evening!";
    }
  }

  /// Get personalized greeting
  String _getPersonalizedGreeting() {
    final greetings = [
      "I'm Sarah, your shopping assistant. How can I help you today?",
      "Welcome to OmniaSA! I'm here to make your shopping experience amazing. What can I do for you?",
      "I'm Sarah, and I'm excited to help you discover great products! What are you looking for?",
      "Hello! I'm your personal shopping companion. Ready to find something wonderful?",
    ];
    
    return greetings[Random().nextInt(greetings.length)];
  }

  /// Check if input is thanking
  bool _isThanking(String input) {
    const thanks = ['thank', 'thanks', 'appreciate', 'grateful', 'awesome', 'great', 'perfect'];
    return thanks.any((thank) => input.contains(thank));
  }

  /// Handle thanks
  String _handleThanks() {
    final responses = [
      "You're so welcome! I'm always happy to help you shop and explore OmniaSA!",
      "My pleasure! That's what I'm here for. Is there anything else you'd like to know?",
      "Glad I could help! I love making shopping easier for you. What else can I assist with?",
      "You're very welcome! I'm always here when you need shopping guidance or have questions!",
    ];
    
    return responses[Random().nextInt(responses.length)];
  }

  /// Check if input is a complaint
  bool _isComplaint(String input) {
    const complaints = ['not working', 'broken', 'error', 'problem', 'issue', 'bug', 'wrong', 'bad', 'terrible', 'horrible'];
    return complaints.any((complaint) => input.contains(complaint));
  }

  /// Handle complaint
  String _handleComplaint() {
    final empathy = [
      "I'm so sorry you're experiencing that!",
      "That's frustrating, and I want to help fix it!",
      "I understand how annoying that must be!",
      "I'm really sorry about that issue!",
    ];
    
    final solutions = [
      "Let me help you resolve this. Can you tell me more about what's happening?",
      "I want to make this right for you. Could you give me more details about the problem?",
      "Let's get this sorted out together. What specific issue are you facing?",
      "I'm here to help fix this. Can you describe exactly what's going wrong?",
    ];
    
    final empathyResponse = empathy[Random().nextInt(empathy.length)];
    final solutionResponse = solutions[Random().nextInt(solutions.length)];
    
    return "$empathyResponse $solutionResponse";
  }

  /// Check if input is a follow-up question
  bool _isFollowUp(String input) {
    const followUps = ['what about', 'how about', 'what if', 'can you also', 'also', 'and', 'but what'];
    return followUps.any((followUp) => input.contains(followUp)) && _context.lastAnswer != null;
  }

  /// Handle follow-up questions
  String _handleFollowUp(String input) {
    if (_context.lastAnswer != null && _context.recentTopics.isNotEmpty) {
      final lastTopic = _context.recentTopics.last;
      final relatedQuestions = _knowledgeBase.getRelatedQuestions(lastTopic);
      
      if (relatedQuestions.isNotEmpty) {
        final response = _knowledgeBase.answerQuestion(input);
        return "$response\n\nYou might also want to know: ${relatedQuestions.take(2).join(' or ')}";
      }
    }
    
    return _knowledgeBase.answerQuestion(input);
  }

  /// Add contextual information to response
  String _addContextualInfo(String response, String input) {
    // Add helpful tips occasionally
    if (Random().nextInt(3) == 0) {
      final tips = _knowledgeBase.getHelpfulTips();
      final randomTip = tips[Random().nextInt(tips.length)];
      response += "\n\n$randomTip";
    }
    
    // Add related suggestions for shopping questions
    if (input.contains('buy') || input.contains('shop') || input.contains('purchase')) {
      response += "\n\nBy the way, you can always ask me to help you find specific products or explain how any feature works!";
    }
    
    return response;
  }

  /// Update conversation context
  void _updateContext(String userInput, String response) {
    final topic = _extractTopic(userInput);
    
    final newTopics = List<String>.from(_context.recentTopics);
    if (topic.isNotEmpty) {
      newTopics.add(topic);
      if (newTopics.length > 5) {
        newTopics.removeAt(0); // Keep only last 5 topics
      }
    }
    
    final newFrequency = Map<String, int>.from(_context.topicFrequency);
    if (topic.isNotEmpty) {
      newFrequency[topic] = (newFrequency[topic] ?? 0) + 1;
    }
    
    _context = _context.copyWith(
      recentTopics: newTopics,
      lastQuestion: userInput,
      lastAnswer: response,
      lastInteraction: DateTime.now(),
      topicFrequency: newFrequency,
    );
    
    if (kDebugMode) {
      print('🧠 Conversation context updated. Recent topics: ${newTopics.join(', ')}');
    }
  }

  /// Extract topic from user input
  String _extractTopic(String input) {
    const topicKeywords = {
      'shopping': ['shop', 'buy', 'purchase', 'cart', 'checkout'],
      'selling': ['sell', 'seller', 'upload', 'product'],
      'delivery': ['delivery', 'shipping', 'deliver', 'arrive'],
      'payment': ['pay', 'payment', 'card', 'cash'],
      'orders': ['order', 'track', 'status', 'cancel'],
      'account': ['profile', 'account', 'login', 'password'],
      'help': ['help', 'how', 'what', 'guide'],
    };
    
    final normalizedInput = input.toLowerCase();
    
    for (final entry in topicKeywords.entries) {
      if (entry.value.any((keyword) => normalizedInput.contains(keyword))) {
        return entry.key;
      }
    }
    
    return 'general';
  }

  /// Get conversation starters based on context
  List<String> getContextualStarters() {
    final frequentTopics = _context.topicFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (frequentTopics.isNotEmpty) {
      final topTopic = frequentTopics.first.key;
      
      switch (topTopic) {
        case 'shopping':
          return [
            "Ready to find some great products?",
            "Looking for anything specific today?",
            "Need help finding the perfect item?",
          ];
        case 'selling':
          return [
            "Want to learn more about selling on OmniaSA?",
            "Ready to start your selling journey?",
            "Need help with your products or seller account?",
          ];
        case 'orders':
          return [
            "Want to check on your orders?",
            "Need help tracking a purchase?",
            "Have questions about your recent orders?",
          ];
      }
    }
    
    return _knowledgeBase.getConversationStarters();
  }

  /// Check if Sarah can handle the question confidently
  bool canHandleQuestion(String question) {
    return _knowledgeBase.canAnswerConfidently(question);
  }

  /// Get conversation summary
  Map<String, dynamic> getConversationSummary() {
    return {
      'recentTopics': _context.recentTopics,
      'topicFrequency': _context.topicFrequency,
      'lastInteraction': _context.lastInteraction.toIso8601String(),
      'conversationLength': _context.recentTopics.length,
    };
  }

  /// Reset conversation context
  void resetContext() {
    _context = ConversationContext(
      recentTopics: [],
      lastInteraction: DateTime.now(),
      topicFrequency: {},
    );
  }

  /// Get smart follow-up questions
  List<String> getSmartFollowUps() {
    if (_context.recentTopics.isEmpty) return [];
    
    final lastTopic = _context.recentTopics.last;
    return _knowledgeBase.getRelatedQuestions(lastTopic);
  }
}
