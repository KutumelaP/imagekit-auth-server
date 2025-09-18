import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/voice_service.dart';

/// Voice Command Processor for handling voice commands and navigation
class VoiceCommandProcessor {
  static final VoiceCommandProcessor _instance = VoiceCommandProcessor._internal();
  factory VoiceCommandProcessor() => _instance;
  VoiceCommandProcessor._internal();

  final VoiceService _voiceService = VoiceService();
  final StreamController<String> _commandController = StreamController<String>.broadcast();
  
  // Command patterns and their handlers
  final Map<String, List<String>> _commandPatterns = {
    'search': ['search for', 'find', 'look for', 'show me', 'i want'],
    'add_to_cart': ['add to cart', 'add this', 'put in cart', 'buy this'],
    'go_to_cart': ['go to cart', 'show cart', 'view cart', 'my cart'],
    'go_to_home': ['go home', 'home page', 'main page', 'back to home'],
    'go_to_orders': ['my orders', 'show orders', 'order history', 'track orders'],
    'go_to_profile': ['my profile', 'profile', 'account', 'settings'],
    'help': ['help me', 'what can you do', 'commands', 'assistance'],
    'categories': ['show categories', 'browse categories', 'what categories'],
    'electronics': ['electronics', 'phones', 'laptops', 'gadgets'],
    'food': ['food', 'groceries', 'restaurant', 'meals'],
    'clothing': ['clothing', 'clothes', 'fashion', 'shirts'],
    'other': ['other items', 'miscellaneous', 'everything else'],
  };

  /// Stream of voice commands
  Stream<String> get commandStream => _commandController.stream;

  /// Process voice input and execute appropriate command
  Future<void> processVoiceInput(String input, BuildContext context) async {
    final command = _identifyCommand(input.toLowerCase());
    
    if (command != null) {
      _commandController.add(command);
      await _executeCommand(command, input, context);
    } else {
      // Fallback to general voice assistant
      await _voiceService.speak("I didn't quite catch that. Try saying 'help' to see what I can do for you.");
    }
  }

  /// Identify the command from voice input
  String? _identifyCommand(String input) {
    for (final entry in _commandPatterns.entries) {
      for (final pattern in entry.value) {
        if (input.contains(pattern)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Execute the identified command
  Future<void> _executeCommand(String command, String originalInput, BuildContext context) async {
    switch (command) {
      case 'search':
        await _handleSearch(originalInput, context);
        break;
      case 'add_to_cart':
        await _handleAddToCart(context);
        break;
      case 'go_to_cart':
        await _handleGoToCart(context);
        break;
      case 'go_to_home':
        await _handleGoToHome(context);
        break;
      case 'go_to_orders':
        await _handleGoToOrders(context);
        break;
      case 'go_to_profile':
        await _handleGoToProfile(context);
        break;
      case 'help':
        await _handleHelp();
        break;
      case 'categories':
        await _handleShowCategories();
        break;
      case 'electronics':
        await _handleCategory('Electronics', context);
        break;
      case 'food':
        await _handleCategory('Food', context);
        break;
      case 'clothing':
        await _handleCategory('Clothing', context);
        break;
      case 'other':
        await _handleCategory('Other', context);
        break;
    }
  }

  /// Handle search commands
  Future<void> _handleSearch(String input, BuildContext context) async {
    // Extract search term
    String searchTerm = input;
    for (final pattern in _commandPatterns['search']!) {
      searchTerm = searchTerm.replaceAll(pattern, '').trim();
    }
    
    if (searchTerm.isNotEmpty) {
      await _voiceService.speak("Searching for $searchTerm...");
      // Navigate to search results
      // Navigator.pushNamed(context, '/search', arguments: searchTerm);
      if (kDebugMode) {
        print('🔍 Voice Search: $searchTerm');
      }
    } else {
      await _voiceService.speak("What would you like me to search for?");
    }
  }

  /// Handle add to cart command
  Future<void> _handleAddToCart(BuildContext context) async {
    await _voiceService.speak("I'll add this item to your cart. Just tap the plus button on any product you like!");
    // Could implement automatic cart addition if on product page
  }

  /// Handle go to cart command
  Future<void> _handleGoToCart(BuildContext context) async {
    await _voiceService.speak("Taking you to your cart now!");
    // Navigator.pushNamed(context, '/cart');
    if (kDebugMode) {
      print('🛒 Voice Command: Go to cart');
    }
  }

  /// Handle go to home command
  Future<void> _handleGoToHome(BuildContext context) async {
    await _voiceService.speak("Going back to the home page!");
    // Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    if (kDebugMode) {
      print('🏠 Voice Command: Go to home');
    }
  }

  /// Handle go to orders command
  Future<void> _handleGoToOrders(BuildContext context) async {
    await _voiceService.speak("Showing your order history!");
    // Navigator.pushNamed(context, '/orders');
    if (kDebugMode) {
      print('📦 Voice Command: Go to orders');
    }
  }

  /// Handle go to profile command
  Future<void> _handleGoToProfile(BuildContext context) async {
    await _voiceService.speak("Opening your profile and settings!");
    // Navigator.pushNamed(context, '/profile');
    if (kDebugMode) {
      print('👤 Voice Command: Go to profile');
    }
  }

  /// Handle help command
  Future<void> _handleHelp() async {
    await _voiceService.speak(
      "Here are some things you can say to me: "
      "Search for products, go to cart, show my orders, browse categories, "
      "or just ask me anything about shopping. What would you like to do?"
    );
  }

  /// Handle show categories command
  Future<void> _handleShowCategories() async {
    await _voiceService.speak(
      "Here are our main categories: Food, Electronics, Clothing, and Other items. "
      "You can say 'show me electronics' or 'browse food' to explore specific categories."
    );
  }

  /// Handle category navigation
  Future<void> _handleCategory(String category, BuildContext context) async {
    await _voiceService.speak("Showing you $category products!");
    // Navigator.pushNamed(context, '/category', arguments: category);
    if (kDebugMode) {
      print('📂 Voice Command: Show $category');
    }
  }

  /// Get available voice commands
  List<String> getAvailableCommands() {
    return [
      "Search for [product name]",
      "Add to cart",
      "Go to cart",
      "Show my orders",
      "Go to profile",
      "Browse categories",
      "Show electronics",
      "Show food",
      "Show clothing",
      "Help me",
    ];
  }

  /// Check if input contains a voice command
  bool isVoiceCommand(String input) {
    return _identifyCommand(input.toLowerCase()) != null;
  }

  /// Dispose resources
  void dispose() {
    _commandController.close();
  }
}
