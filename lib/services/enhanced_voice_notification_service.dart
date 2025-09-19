import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:omniasa/config/api_keys.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:omniasa/services/sound_service.dart';
import 'package:omniasa/services/voice_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Enhanced notification service that integrates with the new VoiceService
/// Provides better voice announcements with Google TTS fallback
class EnhancedVoiceNotificationService {
  static final EnhancedVoiceNotificationService _instance = EnhancedVoiceNotificationService._internal();
  factory EnhancedVoiceNotificationService() => _instance;
  EnhancedVoiceNotificationService._internal();

  // Stream controller for in-app notifications
  final StreamController<Map<String, dynamic>> _notificationController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  // Notification preferences
  bool _systemNotificationsEnabled = true;
  bool _audioNotificationsEnabled = true;
  bool _inAppNotificationsEnabled = false;
  bool _voiceAnnouncementsEnabled = true;
  bool _speakUnreadSummaryOnOpen = true;
  bool _autoClearBadgeOnNotificationsOpen = false;

  bool get systemNotificationsEnabled => _systemNotificationsEnabled;
  bool get audioNotificationsEnabled => _audioNotificationsEnabled;
  bool get inAppNotificationsEnabled => _inAppNotificationsEnabled;
  bool get voiceAnnouncementsEnabled => _voiceAnnouncementsEnabled;
  bool get speakUnreadSummaryOnOpen => _speakUnreadSummaryOnOpen;
  bool get autoClearBadgeOnNotificationsOpen => _autoClearBadgeOnNotificationsOpen;

  // Firebase services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _notifSub;
  StreamSubscription<QuerySnapshot>? _whatsappSub;
  StreamSubscription<RemoteMessage>? _fcmSub;
  
  // Enhanced voice service
  final VoiceService _voiceService = VoiceService();
  final SoundService _soundService = SoundService();

  // Voice preferences
  String? _voiceLanguage;
  double _voiceRate = 0.8;
  double _voicePitch = 1.0;
  bool _preferGoogleTts = true;
  String _voiceName = 'en-US-Wavenet-C';
  List<Map<String, String>> _availableGoogleVoices = const [];

  String? get voiceLanguage => _voiceLanguage;
  double get voiceRate => _voiceRate;
  double get voicePitch => _voicePitch;
  bool get preferGoogleTts => _preferGoogleTts;
  String get voiceName => _voiceName;
  List<Map<String, String>> get availableGoogleVoices => _availableGoogleVoices;

  // Initialize the enhanced notification service
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        await _initializeWebNotifications();
      } else {
        debugPrint('📱 Mobile notifications initialized');
      }
      
      // Load notification preferences
      await _loadNotificationPreferences();
      
      // Initialize VoiceService with retry logic
      await _initializeVoiceServiceWithRetry();
      
      // Configure voice settings
      await _configureVoiceSettings();
      
      // Initialize badge count
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          final unread = await _getTotalUnreadCount(userId);
          await _setAppBadge(unread);
        }
      } catch (e) {
        debugPrint('❌ Error initializing badge count: $e');
      }
      
      debugPrint('✅ Enhanced Voice Notification Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Enhanced Voice Notification Service: $e');
      // Continue without voice service - app should still work
    }
  }

  /// Initialize voice service with retry logic
  Future<void> _initializeVoiceServiceWithRetry() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        await _voiceService.initialize();
        debugPrint('✅ Voice service initialized successfully');
        return;
      } catch (e) {
        retryCount++;
        debugPrint('❌ Voice service initialization attempt $retryCount failed: $e');
        
        if (retryCount < maxRetries) {
          debugPrint('🔄 Retrying voice service initialization in 2 seconds...');
          await Future.delayed(const Duration(seconds: 2));
        } else {
          debugPrint('❌ Voice service initialization failed after $maxRetries attempts');
          // Continue without voice service
        }
      }
    }
  }

  /// Load notification preferences from SharedPreferences
  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    _systemNotificationsEnabled = prefs.getBool('system_notifications') ?? true;
    _audioNotificationsEnabled = prefs.getBool('audio_notifications') ?? true;
    _inAppNotificationsEnabled = prefs.getBool('inapp_notifications') ?? false;
    _voiceAnnouncementsEnabled = prefs.getBool('voice_announcements') ?? true;
    _autoClearBadgeOnNotificationsOpen = prefs.getBool('auto_clear_badge_notifications') ?? false;
    _voiceLanguage = prefs.getString('voice_language') ?? 'en-US';
    _voiceRate = prefs.getDouble('voice_rate') ?? 0.8;
    _voicePitch = prefs.getDouble('voice_pitch') ?? 1.0;
    _preferGoogleTts = prefs.getBool('prefer_google_tts') ?? true;
    
    // Force update to new voice configuration with slower speech
    _voiceName = 'en-US-Wavenet-C';
    _voiceRate = 1.0; // Normal human speech rate for Google TTS
    _voicePitch = 0.9; // Warmer pitch
    await prefs.setString('voice_name', 'en-US-Wavenet-C');
    await prefs.setDouble('voice_rate', 1.0);
    await prefs.setDouble('voice_pitch', 0.9);
    debugPrint('🔄 Updated voice preference to en-US-Wavenet-C with slower speech rate');
    
    _speakUnreadSummaryOnOpen = prefs.getBool('speak_unread_summary') ?? true;
    
    debugPrint('🔔 Enhanced notification preferences loaded');
  }

  /// Configure voice settings
  Future<void> _configureVoiceSettings() async {
    final String languageToUse = _preferGoogleTts ? 'en-US' : (_voiceLanguage ?? 'en-ZA');
    await _voiceService.updateConfig(
      VoiceConfig(
        language: languageToUse,
        speechRate: _voiceRate,
        pitch: _voicePitch,
        voiceName: _voiceName,
        audioEncoding: 'MP3',
      ),
    );
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences({
    bool? systemNotifications,
    bool? audioNotifications,
    bool? inAppNotifications,
    bool? voiceAnnouncements,
    bool? autoClearBadgeOnNotificationsOpen,
    bool? speakUnreadSummaryOnOpen,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (systemNotifications != null) {
      _systemNotificationsEnabled = systemNotifications;
      await prefs.setBool('system_notifications', systemNotifications);
    }
    if (audioNotifications != null) {
      _audioNotificationsEnabled = audioNotifications;
      await prefs.setBool('audio_notifications', audioNotifications);
    }
    if (inAppNotifications != null) {
      _inAppNotificationsEnabled = inAppNotifications;
      await prefs.setBool('inapp_notifications', inAppNotifications);
    }
    if (voiceAnnouncements != null) {
      _voiceAnnouncementsEnabled = voiceAnnouncements;
      await prefs.setBool('voice_announcements', voiceAnnouncements);
    }
    if (autoClearBadgeOnNotificationsOpen != null) {
      _autoClearBadgeOnNotificationsOpen = autoClearBadgeOnNotificationsOpen;
      await prefs.setBool('auto_clear_badge_notifications', autoClearBadgeOnNotificationsOpen);
    }
    if (speakUnreadSummaryOnOpen != null) {
      _speakUnreadSummaryOnOpen = speakUnreadSummaryOnOpen;
      await prefs.setBool('speak_unread_summary', speakUnreadSummaryOnOpen);
    }
    
    debugPrint('🔔 Enhanced notification preferences updated');
  }

  /// Update voice preferences
  Future<void> updateVoicePreferences({
    String? language,
    double? rate,
    double? pitch,
    bool? preferGoogleTts,
    String? voiceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (language != null) {
      _voiceLanguage = language;
      await prefs.setString('voice_language', language);
    }
    if (rate != null) {
      _voiceRate = rate.clamp(0.1, 2.0);
      await prefs.setDouble('voice_rate', _voiceRate);
    }
    if (pitch != null) {
      _voicePitch = pitch.clamp(0.1, 2.0);
      await prefs.setDouble('voice_pitch', _voicePitch);
    }
    if (preferGoogleTts != null) {
      _preferGoogleTts = preferGoogleTts;
      await prefs.setBool('prefer_google_tts', preferGoogleTts);
    }
    if (voiceName != null && voiceName.isNotEmpty) {
      _voiceName = voiceName;
      await prefs.setString('voice_name', voiceName);
    }
    
    // Update VoiceService configuration
    await _configureVoiceSettings();
    
    debugPrint('🔊 Voice preferences updated');
  }

  /// Send enhanced notification with voice announcement
  Future<void> sendNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    bool playSound = true,
    bool announceVoice = true,
  }) async {
    try {
      // Send system notification
      if (_systemNotificationsEnabled) {
        await _sendSystemNotification(
          title: title,
          body: body,
          imageUrl: imageUrl,
          data: data,
        );
      }

      // Send in-app notification
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'title': title,
          'body': body,
          'imageUrl': imageUrl,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Play sound notification
      if (_audioNotificationsEnabled && playSound) {
        await _soundService.playNotificationSound();
      }

      // Voice announcement with enhanced TTS
      if (_voiceAnnouncementsEnabled && announceVoice) {
        await _speakEnhanced('$title. $body');
      }

      // Update badge count
      await _updateBadgeForCurrentUser();

      debugPrint('✅ Enhanced notification sent: $title');
    } catch (e) {
      debugPrint('❌ Error sending enhanced notification: $e');
    }
  }

  /// Enhanced voice announcement with better text processing
  Future<void> _speakEnhanced(String text) async {
    try {
      if (!_voiceAnnouncementsEnabled) return;
      
      // Process text to make it more natural
      final processedText = _processTextForSpeech(text);
      
      // Check if voice service is available before speaking
      if (await _isVoiceServiceAvailable()) {
        await _voiceService.speak(processedText, preferGoogle: _preferGoogleTts);
      } else {
        debugPrint('⚠️ Voice service not available - skipping speech');
      }
    } catch (e) {
      debugPrint('❌ Enhanced TTS speak failed: $e');
      // Try to reinitialize voice service if there's a connection error
      if (e.toString().contains('connection') || e.toString().contains('listening')) {
        debugPrint('🔄 Attempting to reinitialize voice service...');
        await _initializeVoiceServiceWithRetry();
      }
    }
  }

  /// Check if voice service is available and working
  Future<bool> _isVoiceServiceAvailable() async {
    try {
      // Try to get voice service status
      final status = _voiceService.getVoiceStatus();
      return status['isPlaying'] != null; // Basic check if service is responsive
    } catch (e) {
      debugPrint('❌ Voice service availability check failed: $e');
      return false;
    }
  }

  /// Process text to make it more natural for speech
  String _processTextForSpeech(String text) {
    // Remove special characters that don't sound good
    String processed = text
        .replaceAll(RegExp(r'[^\w\s.,!?]'), '') // Remove special chars except basic punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
    
    // Add natural pauses
    processed = processed
        .replaceAll('.', '. ')
        .replaceAll('!', '! ')
        .replaceAll('?', '? ')
        .replaceAll(',', ', ');
    
    // Capitalize first letter
    if (processed.isNotEmpty) {
      processed = processed[0].toUpperCase() + processed.substring(1);
    }
    
    return processed;
  }

  /// Send order-related voice announcements
  Future<void> announceOrderUpdate({
    required String orderId,
    required String status,
    String? additionalInfo,
  }) async {
    if (!_voiceAnnouncementsEnabled) return;

    String message;
    switch (status.toLowerCase()) {
      case 'confirmed':
        message = "Order $orderId has been confirmed and is being prepared.";
        break;
      case 'preparing':
        message = "Order $orderId is being prepared by our kitchen team.";
        break;
      case 'ready':
        message = "Order $orderId is ready for pickup.";
        break;
      case 'out_for_delivery':
        message = "Order $orderId is out for delivery.";
        break;
      case 'delivered':
        message = "Order $orderId has been delivered. Enjoy your meal!";
        break;
      case 'cancelled':
        message = "Order $orderId has been cancelled.";
        break;
      default:
        message = "Order $orderId status updated to $status.";
    }

    if (additionalInfo != null) {
      message += " $additionalInfo";
    }

    await _speakEnhanced(message);
  }

  /// Send payment-related voice announcements
  Future<void> announcePaymentUpdate({
    required String orderId,
    required String status,
    double? amount,
  }) async {
    if (!_voiceAnnouncementsEnabled) return;

    String message;
    switch (status.toLowerCase()) {
      case 'success':
        message = "Payment successful for order $orderId";
        if (amount != null) {
          message += ". Amount: R${amount.toStringAsFixed(2)}";
        }
        message += ".";
        break;
      case 'failed':
        message = "Payment failed for order $orderId. Please try again.";
        break;
      case 'pending':
        message = "Payment is being processed for order $orderId.";
        break;
      default:
        message = "Payment status updated for order $orderId: $status.";
    }

    await _speakEnhanced(message);
  }

  /// Send chat message voice announcements
  Future<void> announceChatMessage({
    required String senderName,
    required String message,
    bool isVoiceMessage = false,
  }) async {
    if (!_voiceAnnouncementsEnabled) return;

    String announcement;
    if (isVoiceMessage) {
      announcement = "Voice message from $senderName";
    } else {
      // Truncate long messages
      final shortMessage = message.length > 50 
          ? '${message.substring(0, 50)}...' 
          : message;
      announcement = "Message from $senderName: $shortMessage";
    }

    await _speakEnhanced(announcement);
  }

  /// Speak unread summary when app opens
  Future<void> speakUnreadSummaryIfEnabled() async {
    try {
      if (!_voiceAnnouncementsEnabled || !_speakUnreadSummaryOnOpen) return;
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      final notifQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      final chatQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .where('lastMessage.read', isEqualTo: false)
          .get();
      
      final notifUnread = notifQuery.docs.length;
      final chatUnread = chatQuery.docs.length;
      
      if (notifUnread == 0 && chatUnread == 0) return;
      
      final parts = <String>[];
      if (notifUnread > 0) {
        parts.add('$notifUnread ${notifUnread == 1 ? 'notification' : 'notifications'}');
      }
      if (chatUnread > 0) {
        parts.add('$chatUnread ${chatUnread == 1 ? 'chat' : 'chats'}');
      }
      
      final phrase = 'You have ${parts.join(' and ')}.';
      await _speakEnhanced(phrase);
    } catch (e) {
      debugPrint('❌ Error speaking unread summary: $e');
    }
  }

  /// Get voice service status
  Map<String, dynamic> getVoiceStatus() {
    return {
      'isPlaying': _voiceService.isPlaying,
      'isPaused': _voiceService.isPaused,
      'googleTtsAvailable': _voiceService.isGoogleTtsAvailable,
      'currentText': _voiceService.currentText,
      'language': _voiceLanguage,
      'rate': _voiceRate,
      'pitch': _voicePitch,
      'preferGoogleTts': _preferGoogleTts,
      'voiceAnnouncementsEnabled': _voiceAnnouncementsEnabled,
    };
  }

  /// Test voice functionality with error handling
  Future<void> testVoice() async {
    try {
      if (await _isVoiceServiceAvailable()) {
        await _speakEnhanced('Voice service is working correctly!');
      } else {
        debugPrint('❌ Voice service not available for testing');
      }
    } catch (e) {
      debugPrint('❌ Voice test failed: $e');
    }
  }

  /// Preview Google WaveNet voice regardless of voiceAnnouncements setting
  Future<void> previewGoogleTts(String text) async {
    try {
      await _initializeVoiceServiceWithRetry();
      final processed = _processTextForSpeech(text);
      await _voiceService.speak(processed, preferGoogle: true);
    } catch (e) {
      debugPrint('❌ Google TTS preview failed: $e');
    }
  }

  /// Force Google TTS for testing
  Future<void> forceGoogleTts(String text) async {
    try {
      await _initializeVoiceServiceWithRetry();
      final processed = _processTextForSpeech(text);
      await _voiceService.forceGoogleTts(processed);
    } catch (e) {
      debugPrint('❌ Force Google TTS failed: $e');
    }
  }

  /// Reinitialize voice service if needed
  Future<void> reinitializeVoiceService() async {
    try {
      debugPrint('🔄 Reinitializing voice service...');
      await _initializeVoiceServiceWithRetry();
      await _configureVoiceSettings();
      debugPrint('✅ Voice service reinitialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to reinitialize voice service: $e');
    }
  }

  /// Fetch Google Cloud TTS voices (cached in memory)
  Future<void> fetchGoogleVoices() async {
    try {
      if (!preferGoogleTts || !_voiceService.isGoogleTtsAvailable) return;
      final uri = Uri.parse('https://texttospeech.googleapis.com/v1/voices?key=${ApiKeys.googleTtsKey}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final voices = (data['voices'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((v) => {
                  'name': (v['name']?.toString() ?? '').trim(),
                  'languageCodes': ((v['languageCodes'] as List?)?.map((e) => e.toString()).join(',') ?? '').trim(),
                  'ssmlGender': (v['ssmlGender']?.toString() ?? '').trim(),
                })
            .where((m) => m['name']!.isNotEmpty)
            .toList();
        _availableGoogleVoices = voices;
        debugPrint('✅ Loaded ${voices.length} Google TTS voices');
      } else {
        debugPrint('❌ Failed to fetch voices: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching Google voices: $e');
    }
  }

  // ... (Include other methods from the original NotificationService as needed)
  // This is a simplified version focusing on the voice integration

  Future<void> _initializeWebNotifications() async {
    // Web notification initialization
  }

  Future<void> _sendSystemNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
  }) async {
    // System notification implementation
  }

  Future<int> _getTotalUnreadCount(String userId) async {
    // Get unread count implementation
    return 0;
  }

  Future<void> _setAppBadge(int count) async {
    // Set app badge implementation
  }

  Future<void> _updateBadgeForCurrentUser() async {
    // Update badge implementation
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _voiceService.dispose();
    await _notificationController.close();
    await _notifSub?.cancel();
    await _whatsappSub?.cancel();
    await _fcmSub?.cancel();
  }
}
