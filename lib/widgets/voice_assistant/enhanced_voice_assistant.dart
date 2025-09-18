import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/voice_service.dart';
import 'voice_assistant_service.dart';
import 'voice_command_processor.dart';
import 'voice_language_manager.dart';
import 'voice_notification_system.dart';
import 'voice_accessibility_manager.dart';
import 'voice_analytics_tracker.dart';

/// Enhanced Voice Assistant with all advanced features
class EnhancedVoiceAssistant {
  static final EnhancedVoiceAssistant _instance = EnhancedVoiceAssistant._internal();
  factory EnhancedVoiceAssistant() => _instance;
  EnhancedVoiceAssistant._internal();

  // Core services
  final VoiceService _voiceService = VoiceService();
  final VoiceAssistantService _assistantService = VoiceAssistantService();
  
  // Advanced features
  final VoiceCommandProcessor _commandProcessor = VoiceCommandProcessor();
  final VoiceLanguageManager _languageManager = VoiceLanguageManager();
  final VoiceNotificationSystem _notificationSystem = VoiceNotificationSystem();
  final VoiceAccessibilityManager _accessibilityManager = VoiceAccessibilityManager();
  final VoiceAnalyticsTracker _analyticsTracker = VoiceAnalyticsTracker();

  bool _isInitialized = false;
  String _currentUserId = '';
  String _currentScreen = 'home';

  /// Initialize the enhanced voice assistant
  Future<void> initialize({
    required String userId,
    required String userName,
    bool isNewUser = false,
    String initialLanguage = 'en',
  }) async {
    if (_isInitialized) return;

    try {
      _currentUserId = userId;

      // Initialize core services
      await _voiceService.initialize();
      await _assistantService.initialize(
        userName: userName,
        isNewUser: isNewUser,
      );

      // Initialize advanced features
      await _languageManager.changeLanguage(initialLanguage);
      await _analyticsTracker.loadAnalyticsData();
      
      _notificationSystem.setEnabled(true);
      _analyticsTracker.setEnabled(true);

      // Set up command processing
      _commandProcessor.commandStream.listen((command) {
        _handleVoiceCommand(command);
      });

      _isInitialized = true;

      if (kDebugMode) {
        print('🚀 Enhanced Voice Assistant initialized for $userName');
      }

      // Send welcome notification
      await _notificationSystem.sendWelcomeNotification(userName);

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Enhanced Voice Assistant: $e');
      }
    }
  }

  /// Process voice input with all advanced features
  Future<void> processVoiceInput(String input, BuildContext context) async {
    final startTime = DateTime.now();
    bool successful = false;

    try {
      // Auto-detect language
      await _languageManager.autoDetectLanguage(input);

      // Check if it's an accessibility command
      if (await _handleAccessibilityCommand(input)) {
        successful = true;
        return;
      }

      // Check if it's a voice command
      if (_commandProcessor.isVoiceCommand(input)) {
        await _commandProcessor.processVoiceInput(input, context);
        successful = true;
      } else {
        // Handle as general conversation
        await _assistantService.handleUserQuestion(input);
        successful = true;
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing voice input: $e');
      }
      await _voiceService.speak("I'm sorry, I didn't understand that. Could you try again?");
    } finally {
      // Track analytics
      final responseTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();
      await _analyticsTracker.trackVoiceCommand(
        userId: _currentUserId,
        command: input,
        language: _languageManager.currentLanguage.code,
        successful: successful,
        responseTime: responseTime,
        screen: _currentScreen,
        category: _categorizeCommand(input),
      );

      // Update notification system
      _notificationSystem.updateLastInteraction();
    }
  }

  /// Handle accessibility commands
  Future<bool> _handleAccessibilityCommand(String input) async {
    final accessibilityCommands = [
      'enable screen reader',
      'disable screen reader',
      'enable voice navigation',
      'disable voice navigation',
      'accessibility help',
    ];

    for (final command in accessibilityCommands) {
      if (input.toLowerCase().contains(command)) {
        await _accessibilityManager.handleAccessibilityCommand(input);
        return true;
      }
    }
    return false;
  }

  /// Handle voice commands
  Future<void> _handleVoiceCommand(String command) async {
    if (kDebugMode) {
      print('🎤 Processing voice command: $command');
    }
  }

  /// Categorize command for analytics
  String _categorizeCommand(String input) {
    final inputLower = input.toLowerCase();
    
    if (inputLower.contains('search') || inputLower.contains('find')) {
      return 'search';
    } else if (inputLower.contains('cart') || inputLower.contains('buy')) {
      return 'shopping';
    } else if (inputLower.contains('order') || inputLower.contains('track')) {
      return 'orders';
    } else if (inputLower.contains('help') || inputLower.contains('what')) {
      return 'help';
    } else if (inputLower.contains('navigate') || inputLower.contains('go to')) {
      return 'navigation';
    } else {
      return 'general';
    }
  }

  /// Set current screen for context awareness
  void setCurrentScreen(String screen) {
    _currentScreen = screen;
    _assistantService.setContext(screen);
  }

  /// Send smart notifications
  Future<void> sendSmartNotification({
    required String message,
    required VoiceNotificationType type,
  }) async {
    await _notificationSystem.sendNotification(
      message: message,
      type: type,
    );
  }

  /// Change language
  Future<void> changeLanguage(String languageCode) async {
    await _languageManager.changeLanguage(languageCode);
    await _voiceService.speak(_languageManager.getLocalizedMessage('welcome'));
  }

  /// Enable accessibility features
  void enableAccessibility({
    bool screenReader = false,
    bool voiceNavigation = false,
    bool highContrastVoice = false,
  }) {
    if (screenReader) _accessibilityManager.enableScreenReaderMode(true);
    if (voiceNavigation) _accessibilityManager.enableVoiceOnlyNavigation(true);
    if (highContrastVoice) _accessibilityManager.enableHighContrastVoice(true);
  }

  /// Get usage statistics
  VoiceUsageStats getUsageStatistics() {
    return _analyticsTracker.calculateUsageStats();
  }

  /// Get available voice commands in current language
  List<String> getAvailableCommands() {
    return _languageManager.getLocalizedCommands();
  }

  /// Build enhanced voice assistant widget
  Widget buildEnhancedAssistant({
    required Widget child,
    bool showSettings = false,
  }) {
    return Stack(
      children: [
        child,
        
        // Enhanced floating mic with advanced features
        Positioned(
          bottom: 80,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Analytics indicator
              if (kDebugMode)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: StreamBuilder<VoiceUsageStats>(
                    stream: _analyticsTracker.statsStream,
                    builder: (context, snapshot) {
                      final stats = snapshot.data;
                      return Text(
                        'Commands: ${stats?.totalCommands ?? 0}\n'
                        'Success: ${stats?.successRate.toStringAsFixed(1) ?? '0'}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Language indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _languageManager.currentLanguage.code.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Enhanced voice mic button - Baby Nathan's mic
              StreamBuilder<bool>(
                stream: _assistantService.listeningStream,
                builder: (context, snapshot) {
                  final isListening = snapshot.data ?? false;
                  return FloatingActionButton(
                    heroTag: "enhanced_voice_mic",
                    backgroundColor: isListening 
                      ? Colors.red.shade400 // Recording color
                      : Colors.orange.shade300, // Baby Nathan's default color
                    child: Icon(
                      isListening ? Icons.mic : Icons.mic_none, 
                      color: Colors.white
                    ),
                    onPressed: () async {
                      // Toggle voice listening
                      if (isListening) {
                        await _assistantService.stopListening();
                      } else {
                        await _assistantService.startListening();
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
        
        // Settings button (if enabled)
        if (showSettings)
          Positioned(
            top: 50,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: "voice_settings",
              backgroundColor: Colors.grey,
              child: const Icon(Icons.settings, size: 20),
              onPressed: () {
                if (kDebugMode) {
                  print('⚙️ Settings tapped');
                }
              },
            ),
          ),
        
      ],
    );
  }



  /// Dispose all resources
  void dispose() {
    _commandProcessor.dispose();
    _languageManager.dispose();
    _notificationSystem.dispose();
    _analyticsTracker.dispose();
  }
}
