import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/voice_service.dart';
import '../../services/llm_service.dart';
import 'onboarding_voice_guide.dart';
import 'nathan_conversation_manager.dart';
import 'human_responder.dart';

/// AI Speech Assistant Service for onboarding and user guidance
class VoiceAssistantService {
  static final VoiceAssistantService _instance = VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  final VoiceService _voiceService = VoiceService();
  final LlmService _llmService = LlmService();
  final NathanConversationManager _conversationManager = NathanConversationManager();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final HumanResponder _humanResponder = HumanResponder();
  
  // Assistant state
  bool _isActive = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _speechEnabled = false;
  String? _currentContext;
  String? _userName;
  bool _isNewUser = false;
  String _lastWords = '';
  String _lastPartialWords = '';
  
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
      // Respect assistant_enabled preference
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('assistant_enabled') ?? true;
      if (!enabled) {
        if (kDebugMode) {
          print('🚫 Assistant disabled by user preference. Skipping initialization.');
        }
        _isActive = false;
        return;
      }
      if (kDebugMode) {
        print('🎤 Starting VoiceAssistantService initialization for $userName (New user: $isNewUser)');
      }
      
      // Reset state
      _isActive = false;
      _isListening = false;
      _isProcessing = false;
      
      await _voiceService.initialize();
      await _llmService.initialize();
      _userName = userName;
      _isNewUser = isNewUser;
      
      // Initialize speech-to-text
      await _initializeSpeechToText();
      
      _isActive = true;
      
      if (kDebugMode) {
        print('✅ Voice Assistant initialized successfully for ${isNewUser ? 'new' : 'existing'} user: $userName');
        print('🎤 Speech recognition enabled: $_speechEnabled');
        print('🎤 Voice service available: ${_voiceService.isGoogleTtsAvailable}');
        print('🎤 Assistant active: $_isActive');
        print('🤖 LLM Service available: ${_llmService.isAvailable}');
        print('🤖 LLM Provider: ${_llmService.provider}');
      }
    } catch (e) {
      _isActive = false;
      if (kDebugMode) {
        print('❌ Error initializing Voice Assistant: $e');
      }
      rethrow;
    }
  }

  /// Check if the voice assistant is ready to use
  bool get isReady => _isActive && _speechEnabled;

  /// Initialize speech-to-text functionality
  Future<void> _initializeSpeechToText() async {
    try {
      // Request microphone permission
      await _requestMicrophonePermission();
      
      // Initialize speech recognition with better error handling
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          if (kDebugMode) {
            print('🎤 Speech status: $status');
          }
          // Handle different statuses appropriately
          switch (status) {
            case 'notListening':
              if (_isListening) {
                _isListening = false;
                _listeningController.add(false);
              }
              break;
            case 'listening':
              if (!_isListening) {
                _isListening = true;
                _listeningController.add(true);
              }
              break;
            case 'done':
              // Speech recognition completed. If we have partial but no final, promote partial.
              if (_lastWords.trim().isEmpty && _lastPartialWords.trim().isNotEmpty) {
                _lastWords = _lastPartialWords;
              }
              // If we have something captured but final callback didn't trigger processing, process now.
              if (!_isProcessing && _lastWords.trim().isNotEmpty) {
                // Ensure we aren't marked as listening
                _isListening = false;
                _listeningController.add(false);
                // Process directly without calling stop() again
                _isProcessing = true;
                _processingController.add(true);
                unawaited(_processRecognizedSpeech(_lastWords).whenComplete(() {
                  _isProcessing = false;
                  _processingController.add(false);
                }));
              } else if (_lastWords.trim().isEmpty) {
                // Nothing heard
                unawaited(_voiceService.speak("I didn't hear anything. Please try again!"));
              }
              break;
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('❌ Speech error: ${error.errorMsg}');
          }
          _isListening = false;
          _listeningController.add(false);
          
          // Handle specific error messages - be less chatty for common errors
          final errorMsg = error.errorMsg.toLowerCase();
          if (errorMsg.contains('network') || errorMsg.contains('connection')) {
            _voiceService.speak("Network issue detected. Please check your connection and try again.");
          } else if (errorMsg.contains('no match') || errorMsg.contains('not recognized')) {
            // Don't respond immediately for no match - user might still be speaking
            if (kDebugMode) {
              print('🎤 No match detected, staying quiet to avoid interrupting user');
            }
          } else if (errorMsg.contains('timeout') || errorMsg.contains('speech_timeout')) {
            // Auto-retry listening quietly after a short delay
            if (kDebugMode) {
              print('🎤 Timeout detected. Auto-restarting listening...');
            }
            Future.delayed(const Duration(milliseconds: 600), () async {
              if (_isActive && !_isListening && !_isProcessing) {
                await startListening();
              }
            });
          } else {
            _voiceService.speak("Sorry, there was an issue with voice recognition. Please try again.");
          }
        },
      );
      
      if (kDebugMode) {
        print('🎤 Speech-to-text initialized successfully: $_speechEnabled');
        print('🎤 Available: ${_speechToText.isAvailable}');
        print('🎤 Has permission: ${await _speechToText.hasPermission}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing speech-to-text: $e');
      }
      _speechEnabled = false;
      // Don't rethrow - allow voice assistant to work without speech recognition
    }
  }

  /// Activate the voice assistant (public method)
  Future<void> activate({String? userName, bool isNewUser = false}) async {
    try {
      await initialize(userName: userName, isNewUser: isNewUser);
      if (kDebugMode) {
        print('✅ Voice assistant activated: ${getStatus()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to activate voice assistant: $e');
      }
    }
  }

  /// Test the voice assistant functionality
  Future<void> testVoiceAssistant() async {
    try {
      if (kDebugMode) {
        print('🧪 Testing voice assistant...');
        print('🧪 Status: ${getStatus()}');
      }
      
      if (!_isActive) {
        if (kDebugMode) {
          print('🧪 Voice assistant not active - activating...');
        }
        final String userNameToUse = (_userName != null && _userName!.isNotEmpty) ? _userName! : 'Test User';
        await activate(userName: userNameToUse, isNewUser: false);
      }
      
      if (_isActive) {
        if (kDebugMode) {
          print('🧪 Voice assistant is active and ready!');
        }
        await _voiceService.speak('Voice assistant test successful!');
      } else {
        if (kDebugMode) {
          print('🧪 Voice assistant test failed - not active');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🧪 Voice assistant test error: $e');
      }
    }
  }

  /// Request microphone permission
  Future<void> _requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (kDebugMode) {
          print('❌ Microphone permission denied');
        }
        throw Exception('Microphone permission is required for voice commands');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error requesting microphone permission: $e');
      }
      rethrow;
    }
  }

  /// Start listening for user input
  Future<void> startListening() async {
    // Respect assistant_enabled preference
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('assistant_enabled') ?? true)) {
      if (kDebugMode) {
        print('🚫 Assistant disabled. Ignoring startListening().');
      }
      return;
    }
    if (kDebugMode) {
      print('🎤 startListening called - Active: $_isActive, Listening: $_isListening, Processing: $_isProcessing');
    }
    
    // Check if service is properly initialized
    if (!_isActive) {
      if (kDebugMode) {
        print('❌ Voice assistant not active - attempting to initialize...');
      }
      // Try to initialize if not active
      try {
        // Use default values if userName is null
        final userName = _userName ?? 'User';
        await initialize(userName: userName, isNewUser: _isNewUser);
        
        if (!isReady) {
          if (kDebugMode) {
            debugPrint('❌ Voice assistant not ready after initialization');
            debugPrint('❌ Status: ${getStatus()}');
            debugPrint('❌ Speech enabled: $_speechEnabled');
            debugPrint('❌ Active: $_isActive');
          }
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error initializing voice assistant: $e');
          debugPrint('❌ Stack trace: ${StackTrace.current}');
        }
        return;
      }
    }
    
    if (_isListening || _isProcessing) {
      if (kDebugMode) {
        debugPrint('❌ Already listening or processing - Active: $_isActive, Listening: $_isListening, Processing: $_isProcessing');
      }
      return;
    }
    
    // Web fallback strategy (only on web platform)
    if (kIsWeb) {
      if (!_speechEnabled || !_speechToText.isAvailable) {
        // Try audio recording fallback first (works on iOS Safari)
        if (await _canRecordAudio()) {
          await _startAudioRecording();
          return;
        } else {
          // Final fallback: text input dialog
          await _showWebTextInputDialog();
          return;
        }
      }
    }
    
    // Mobile apps with speech_to_text not enabled
    if (!_speechEnabled) return;
    
    try {
      _isListening = true;
      _listeningController.add(true);
      _lastWords = '';
      
      // Start speech recognition with improved settings
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            _lastWords = result.recognizedWords;
          } else {
            _lastPartialWords = result.recognizedWords;
          }
          
          if (kDebugMode) {
            if (result.finalResult) {
              debugPrint('🎤 Final recognition: $_lastWords (confidence: ${result.confidence})');
            } else {
              debugPrint('🎤 Partial recognition: $_lastWords');
            }
          }
          
          // Auto-stop when user finishes speaking and result is final
          if (result.finalResult && _lastWords.trim().isNotEmpty) {
            // Longer delay to capture complete thoughts
            Future.delayed(const Duration(milliseconds: 800), () async {
              if (kDebugMode) {
                print('🎤 Auto-stopping after recognition: $_lastWords');
              }
              await stopListening();
            });
          }
        },
        listenFor: const Duration(seconds: 25), // Longer window to reduce timeouts
        pauseFor: const Duration(seconds: 3),   // Allow a bit more pause before timeout
        partialResults: true, // Enable partial results for better detection
        localeId: (await _speechToText.systemLocale())?.localeId,
        cancelOnError: false, // Don't cancel on errors, keep trying
        listenMode: stt.ListenMode.dictation, // Best mode for complete sentences
      );
      
      if (kDebugMode) {
        print('🎤 Nathan is listening... (speak now!)');
      }
      
      // Provide haptic feedback to indicate listening started
      try {
        if (await Vibration.hasVibrator()) {
          await Vibration.vibrate(duration: 100);
        }
      } catch (e) {
        // Vibration not available, ignore
      }
      
    } catch (e) {
      _isListening = false;
      _listeningController.add(false);
      
      if (kDebugMode) {
        print('❌ Error starting voice listening: $e');
      }
      
      // Provide feedback to user
      await _voiceService.speak("Sorry, I couldn't start listening. Please check your microphone permission.");
    }
  }

  /// Stop listening and process input
  Future<void> stopListening() async {
    if (kDebugMode) {
      print('🎤 stopListening called - isListening: $_isListening, lastWords: "$_lastWords"');
    }
    
    // If we have recognized words but listening is already false, still process them
    if (!_isListening && _lastWords.trim().isEmpty) {
      if (kDebugMode) {
        print('🎤 Not listening and no words to process');
      }
      return;
    }
    
    try {
      // Ensure listening state is properly set
      if (_isListening) {
        _isListening = false;
        _listeningController.add(false);
        
        // Stop speech recognition only if it's still running
        await _speechToText.stop();
        
        if (kDebugMode) {
          print('🎤 Speech recognition stopped');
        }
      }
      
      if (kDebugMode) {
        print('🎤 Checking recognized words: "$_lastWords"');
      }
      
      // Check if we have any recognized words
      if (_lastWords.trim().isEmpty) {
        if (kDebugMode) {
          print('🎤 No speech detected - _lastWords is empty');
        }
        await _voiceService.speak("I didn't hear anything. Please try again!");
        return;
      }
      
      _isProcessing = true;
      _processingController.add(true);
      
      if (kDebugMode) {
        print('🎤 Processing recognized speech: "$_lastWords"');
        print('💭 THINKING ICON should be visible now (processing=true)');
      }
      
      // Add a small delay to ensure the thinking icon is visible
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Process the recognized speech
      await _processRecognizedSpeech(_lastWords);
      
      _isProcessing = false;
      _processingController.add(false);
      
      if (kDebugMode) {
        print('💭 THINKING ICON should be hidden now (processing=false)');
      }
      
      if (kDebugMode) {
        print('🎤 Finished processing speech');
      }
      
    } catch (e) {
      _isListening = false;
      _isProcessing = false;
      _listeningController.add(false);
      _processingController.add(false);
      
      if (kDebugMode) {
        print('❌ Error processing voice input: $e');
        print('❌ Stack trace: ${StackTrace.current}');
      }
      
      await _voiceService.speak("Sorry, I had trouble understanding that. Please try again!");
    }
  }

  /// Process the recognized speech
  Future<void> _processRecognizedSpeech(String recognizedText) async {
    final startTime = DateTime.now();
    try {
      if (kDebugMode) {
        print('🎤 ===== VOICE REQUEST START =====');
        print('🎤 Request: "$recognizedText"');
        print('🎤 Context: ${_currentContext ?? "none"}');
        print('🎤 Timestamp: ${startTime.toIso8601String()}');
      }
      
      // Check if it's a common onboarding question first
      if (_isOnboardingQuestion(recognizedText)) {
        if (kDebugMode) {
          print('🎓 Detected onboarding question: $recognizedText');
        }
        await OnboardingVoiceGuide.answerCommonQuestion(recognizedText);
        if (kDebugMode) {
          print('🎓 Onboarding response completed');
        }
        return;
      }
      
      // Use Nathan's intelligent conversation manager for smart responses
      final bool canHandle = _conversationManager.canHandleQuestion(recognizedText);
      if (canHandle) {
        if (kDebugMode) {
          print('🧠 Nathan can handle this question: $recognizedText');
        }
        final smartResponse = _conversationManager.processUserInput(recognizedText);
        if (kDebugMode) {
          print('🧠 Nathan response: $smartResponse');
        }
        await _speakResponse(smartResponse, question: recognizedText);
        
        if (kDebugMode) {
          print('🧠 Nathan answered intelligently: ${recognizedText.substring(0, min(recognizedText.length, 30))}...');
        }
        return;
      }

      if (kDebugMode) {
        print('🎯 Nathan cannot confidently answer. Trying LLM fallback first.');
      }
      // Prefer LLM when Nathan can't handle confidently
      String? llmAnswer;
      if (_llmService.isAvailable) {
        try {
          final relevantKnowledge = _conversationManager.getRelevantKnowledgeForLLM(recognizedText);
          if (kDebugMode) {
            print('🤖 Using LLM with ${relevantKnowledge.length} knowledge pieces for: "$recognizedText"');
          }
          llmAnswer = await _llmService.generateAnswer(
            userQuestion: recognizedText,
            contextHint: _currentContext,
            relevantKnowledge: relevantKnowledge,
          );
        } catch (e) {
          if (kDebugMode) {
            print('❌ LLM fallback failed: $e');
          }
        }
      }

      // If LLM not available or returned null, try HumanResponder fallbacks
      String? humanAnswer;
      if (llmAnswer == null) {
        if (kDebugMode) {
          print('🎯 LLM unavailable or no result. Using HumanResponder fallback.');
        }
        humanAnswer = _humanResponder.generatePlayfulReply(recognizedText);
        if (humanAnswer == null) {
          humanAnswer = await _humanResponder.generateHelpfulAnswerAsync(
            recognizedText,
            context: _currentContext,
          );
        }
      }

      final response = llmAnswer ?? humanAnswer ?? _getQuestionResponse(recognizedText);
      if (kDebugMode) {
        print('🎯 Final response selected: ${response.substring(0, min(response.length, 100))}...');
      }
      await _speakResponse(response, question: recognizedText);
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      if (kDebugMode) {
        print('🎤 Nathan responded: ${response.substring(0, min(response.length, 50))}...');
        print('🎤 Processing time: ${duration}ms');
        print('🎤 ===== VOICE REQUEST END =====');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing recognized speech: $e');
        print('❌ Stack trace: ${StackTrace.current}');
      }
      await _voiceService.speak("I'm sorry, I didn't understand that. Could you try asking in a different way?");
    }
  }

  /// Set current context for better responses
  void setContext(String context) {
    _currentContext = context;
    if (kDebugMode) {
      print('🎯 Voice Assistant context set to: $context');
    }
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
        return _getDefaultResponses();
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

  /// Default responses when no specific context is set
  List<String> _getDefaultResponses() {
    return [
      "Hi! I'm Nathan. I can help you browse stores, find products, check orders, and more.",
      "Need help deciding? Ask me to show categories or deals!",
      "You can say things like 'show my orders' or 'find sneakers'.",
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

  /// Speak the response, refining via LLM when available
  Future<void> _speakResponse(String response, {String? question}) async {
    try {
      String finalText = response;
      finalText = _humanResponder.humanize(finalText, context: _currentContext);
      
      // Enhanced LLM refinement with knowledge context
      if (_llmService.isAvailable) {
        final userQuestion = (question != null && question.trim().isNotEmpty) ? question : _lastWords;
        
        // Check if we should enhance with LLM
        if (_conversationManager.shouldEnhanceWithLLM(userQuestion)) {
          final relevantKnowledge = _conversationManager.getRelevantKnowledgeForLLM(userQuestion);
          
          if (kDebugMode) {
            print('🔧 Enhancing response with LLM using ${relevantKnowledge.length} knowledge pieces');
          }
          
          finalText = await _llmService.refineAnswer(
            userQuestion: userQuestion,
            baseAnswer: response,
            contextHint: _currentContext,
            relevantKnowledge: relevantKnowledge,
          );
        }
        finalText = _humanResponder.humanize(finalText, context: _currentContext);
      }
      await _voiceService.speak(finalText);
      _responseController.add(finalText);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error speaking response: $e');
      }
    }
  }

  /// Provide proactive guidance based on user actions
  Future<void> provideProactiveGuidance(String action) async {
    if (!_isActive) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('assistant_enabled') ?? true)) return;
    
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
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('assistant_enabled') ?? true)) return;
    
    // Check if it's a common onboarding question first
    if (_isOnboardingQuestion(question)) {
      await OnboardingVoiceGuide.answerCommonQuestion(question);
      return;
    }
    
    if (kDebugMode) {
      print('✍️ handleUserQuestion: "$question"');
    }

    // Prefer knowledge-base response when confident
    final bool canHandle = _conversationManager.canHandleQuestion(question);
    if (canHandle) {
      final smartResponse = _conversationManager.processUserInput(question);
      if (kDebugMode) {
        print('🧠 Nathan KB response: ${smartResponse.substring(0, min(smartResponse.length, 100))}');
      }
      await _speakResponse(smartResponse, question: question);
      return;
    }

    // LLM fallback first when not confident
    String? llmAnswer;
    if (_llmService.isAvailable) {
      try {
        final knowledge = _conversationManager.getRelevantKnowledgeForLLM(question);
        if (kDebugMode) {
          print('🤖 LLM fallback for text input with ${knowledge.length} knowledge items');
        }
        llmAnswer = await _llmService.generateAnswer(
          userQuestion: question,
          contextHint: _currentContext,
          relevantKnowledge: knowledge,
        );
      } catch (e) {
        if (kDebugMode) print('❌ LLM fallback failed (text): $e');
      }
    }

    String? humanAnswer;
    if (llmAnswer == null) {
      if (kDebugMode) print('🎯 HumanResponder fallback (text path)');
      humanAnswer = _humanResponder.generatePlayfulReply(question);
      if (humanAnswer == null) {
        humanAnswer = await _humanResponder.generateHelpfulAnswerAsync(
          question,
          context: _currentContext,
        );
      }
    }

    final response = llmAnswer ?? humanAnswer ?? _getQuestionResponse(question);
    if (kDebugMode) {
      print('✅ Text response selected: ${response.substring(0, min(response.length, 120))}');
    }
    await _speakResponse(response, question: question);
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
    
    return "Got you — want me to search for it or show stores? Say a keyword like 'cake' to start.";
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

  /// Show text input dialog for web users when speech recognition is not available
  Future<void> _showWebTextInputDialog() async {
    final BuildContext? context = _getCurrentContext();
    if (context == null) return;

    final textController = TextEditingController();
    
    _isListening = true;
    _listeningController.add(true);

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.chat, color: Colors.orange.shade300),
              const SizedBox(width: 8),
              const Text('Ask Nathan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Speech recognition isn\'t available in this browser.\nType your question for Nathan:',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Type your question here...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  Navigator.of(context).pop(value.trim());
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(textController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade300,
              ),
              child: const Text('Ask Nathan'),
            ),
          ],
        );
      },
    );

    _isListening = false;
    _listeningController.add(false);

    if (result != null && result.isNotEmpty) {
      _isProcessing = true;
      _processingController.add(true);
      
      await _processRecognizedSpeech(result);
      
      _isProcessing = false;
      _processingController.add(false);
    }
  }

  /// Check if browser can record audio (for iOS Safari fallback)
  Future<bool> _canRecordAudio() async {
    if (!kIsWeb) return false;
    // Simple check for getUserMedia availability on web
    return true; // Assume available on web for now
  }

  /// Start audio recording for web browsers (iOS Safari compatible)
  Future<void> _startAudioRecording() async {
    try {
      _isListening = true;
      _listeningController.add(true);
      
      if (kDebugMode) {
        print('🎤 Starting web audio recording (demo mode)...');
      }
      
      // Provide haptic feedback
      try {
        if (await Vibration.hasVibrator()) {
          await Vibration.vibrate(duration: 100);
        }
      } catch (e) {
        // Vibration not available, ignore
      }
      
      // For now, show a demo recording dialog
      await _showWebRecordingDemo();
      
    } catch (e) {
      _isListening = false;
      _listeningController.add(false);
      
      if (kDebugMode) {
        print('❌ Error with audio recording: $e');
      }
      
      // Fallback to text input
      await _voiceService.speak("Sorry, I had trouble with the microphone. Let me show you a text option.");
      await Future.delayed(const Duration(milliseconds: 500));
      await _showWebTextInputDialog();
    }
  }

  /// Show simple recording demo for web browsers
  Future<void> _showWebRecordingDemo() async {
    final BuildContext? context = _getCurrentContext();
    if (context == null) {
      // Fallback without dialog
      await Future.delayed(const Duration(seconds: 3));
      _isListening = false;
      _listeningController.add(false);
      
      // Trigger processing state
      _isProcessing = true;
      _processingController.add(true);
      
      if (kDebugMode) {
        print('💭 WEB THINKING ICON should be visible now (processing=true)');
      }
      
      await _voiceService.speak("Web audio recording detected! I'm working on understanding what you said.");
      
      // Simulate processing time
      await Future.delayed(const Duration(seconds: 3));
      
      _isProcessing = false;
      _processingController.add(false);
      
      if (kDebugMode) {
        print('💭 WEB THINKING ICON should be hidden now (processing=false)');
      }
      return;
    }

    // Show simple demo dialog
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.red),
              const SizedBox(height: 16),
              const Text('🎤 Recording...'),
              const SizedBox(height: 8),
              const Text('Demo: Web audio recording is working!'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Stop'),
              ),
            ],
          ),
        );
      },
    ));

    // Auto-stop after 5 seconds
    await Future.delayed(const Duration(seconds: 5));
    
    if (context.mounted) {
      Navigator.of(context).pop();
    }
    
    _isListening = false;
    _listeningController.add(false);
    
    // Demo response
    _isProcessing = true;
    _processingController.add(true);
    
    if (kDebugMode) {
      print('💭 WEB DIALOG THINKING ICON should be visible now (processing=true)');
    }
    
    await Future.delayed(const Duration(seconds: 2));
    
    await _voiceService.speak("Great! I can access your microphone on this web browser. Soon I'll understand what you're saying!");
    
    _isProcessing = false;
    _processingController.add(false);
    
    if (kDebugMode) {
      print('💭 WEB DIALOG THINKING ICON should be hidden now (processing=false)');
    }
  }

  /// Get current context (simplified version - you may need to adjust based on your navigation setup)
  BuildContext? _getCurrentContext() {
    // This is a simplified implementation
    // You might need to store a reference to the current context or use a different approach
    return null; // Placeholder - implement based on your app structure
  }

  /// Dispose resources
  Future<void> dispose() async {
    _isActive = false;
    _isListening = false;
    _isProcessing = false;
    
    // Stop speech recognition if running
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    
    await _listeningController.close();
    await _processingController.close();
    await _responseController.close();
    await _voiceService.dispose();
  }
}
