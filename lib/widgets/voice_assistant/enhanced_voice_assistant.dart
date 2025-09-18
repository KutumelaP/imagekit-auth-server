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
              const SizedBox(height: 8),
              
              // Enhanced voice mic button - Baby Nathan's mic with animations
              StreamBuilder<bool>(
                stream: _assistantService.listeningStream,
                builder: (context, snapshot) {
                  final isListening = snapshot.data ?? false;
                  return StreamBuilder<bool>(
                    stream: _assistantService.processingStream,
                    builder: (context, processingSnapshot) {
                      final isProcessing = processingSnapshot.data ?? false;
                      
                      return _PulsingMicButton(
                        isListening: isListening,
                        isProcessing: isProcessing,
                        child: FloatingActionButton(
                          heroTag: "enhanced_voice_mic",
                          backgroundColor: isListening 
                            ? Colors.red.shade400 // Recording/listening color
                            : isProcessing 
                              ? Colors.blue.shade400 // Processing color
                              : Colors.orange.shade300, // Baby Nathan's default color
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isListening
                                ? Icons.mic
                                : isProcessing
                                  ? (kIsWeb ? Icons.mic : Icons.psychology) // Brain icon on mobile, mic on web
                                  : Icons.mic_none,
                              key: ValueKey(isListening ? 'listening' : isProcessing ? 'processing' : 'idle'),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          onPressed: () async {
                            // Prevent interaction during processing
                            if (isProcessing) return;
                            
                            // Toggle voice listening
                            if (isListening) {
                              await _assistantService.stopListening();
                            } else {
                              await _assistantService.startListening();
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        
        // Settings button removed per request
        
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

/// Custom pulsing animation widget for the microphone button
class _PulsingMicButton extends StatefulWidget {
  final bool isListening;
  final bool isProcessing;
  final Widget child;

  const _PulsingMicButton({
    required this.isListening,
    required this.isProcessing,
    required this.child,
  });

  @override
  State<_PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<_PulsingMicButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(_PulsingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isListening ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: widget.isListening ? [
                BoxShadow(
                  color: Colors.red.shade400.withOpacity(0.5),
                  blurRadius: 20 * _pulseAnimation.value,
                  spreadRadius: 5 * _pulseAnimation.value,
                ),
              ] : widget.isProcessing ? [
                BoxShadow(
                  color: Colors.blue.shade400.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ] : [],
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
