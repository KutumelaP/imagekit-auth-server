import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:marketplace_app/utils/web_js_stub.dart'
    if (dart.library.html) 'package:marketplace_app/utils/web_js_real.dart' as js;
import 'sound_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:marketplace_app/utils/web_env.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart'
  if (dart.library.html) 'package:marketplace_app/utils/badger_stub.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';



class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _notifSub;
  StreamSubscription<RemoteMessage>? _fcmSub;
  bool _notifListenerInitialized = false;
  final Set<String> _spokenNotificationIds = <String>{};
  
  // Sound service for audio notifications
  final SoundService _soundService = SoundService();
  final FlutterTts _tts = FlutterTts();
  // TTS preferences
  String? _ttsLanguage; // e.g., 'en-US'
  String? _ttsVoiceName; // platform voice name
  String? _ttsVoiceLocale; // e.g., 'en-US'
  double _ttsRate = 0.45;
  double _ttsPitch = 1.0;
  double _ttsVolume = 1.0;

  // Cached options
  List<dynamic> _availableVoices = const [];
  List<dynamic> _availableLanguages = const [];

  String? get ttsLanguage => _ttsLanguage;
  String? get ttsVoiceName => _ttsVoiceName;
  String? get ttsVoiceLocale => _ttsVoiceLocale;
  double get ttsRate => _ttsRate;
  double get ttsPitch => _ttsPitch;
  double get ttsVolume => _ttsVolume;
  List<dynamic> get availableVoices => _availableVoices;
  List<dynamic> get availableLanguages => _availableLanguages;

  // Initialize the notification service
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        // Web: Use browser notifications
        await _initializeWebNotifications();
      } else {
        // Mobile: For now, just load preferences
        print('📱 Mobile notifications will be implemented later');
      }
      
      // Load notification preferences
      await _loadNotificationPreferences();
      await _applyTtsSettings();
      await refreshTtsOptions();
      await _ensureZAdefaults();
      // Initialize badge count from unread
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          final unread = await _getTotalUnreadCount(userId);
          await _setAppBadge(unread);
        }
      } catch (_) {}
      
      print('✅ Notification Service initialized');
      _attachRealtimeSpeakListener();
      _attachFcmOnMessageSpeak();
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }

  /// Initialize web notifications
  Future<void> _initializeWebNotifications() async {
    try {
      // Gate by environment to avoid Safari tab errors and memory pressure
      if (!WebEnv.isWebPushSupported) {
        print('❌ Browser does not support notifications');
        return;
      }

      // Ensure Notification API exists
      if (!js.context.hasProperty('Notification')) {
        print('❌ Browser does not define Notification API');
        return;
      }

      // Read current permission via JS interop
      final currentPermission = js.context.callMethod('eval', ['Notification.permission']);
      print('🔔 Current notification permission: $currentPermission');

      if (currentPermission == 'default') {
        print('🔔 Requesting notification permissions...');
        try {
          js.context.callMethod('eval', [
            'Notification.requestPermission().then(function(r){console.log("🔔 Notification permission result:",r)}).catch(function(e){console.error("❌ Error requesting permission:",e)})'
          ]);
        } catch (e) {
          print('❌ Error requesting notification permission: $e');
        }
      } else if (currentPermission == 'granted') {
        print('✅ Notification permissions already granted');
      } else {
        print('❌ Notification permissions denied');
      }
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
    }
  }



  // Load notification preferences
  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _systemNotificationsEnabled = prefs.getBool('system_notifications') ?? true;
    _audioNotificationsEnabled = prefs.getBool('audio_notifications') ?? true;
    _inAppNotificationsEnabled = prefs.getBool('inapp_notifications') ?? false;
    _voiceAnnouncementsEnabled = prefs.getBool('voice_announcements') ?? true;
    _autoClearBadgeOnNotificationsOpen = prefs.getBool('auto_clear_badge_notifications') ?? false;
    _ttsLanguage = prefs.getString('tts_language') ?? 'en-ZA';
    _ttsVoiceName = prefs.getString('tts_voice_name');
    _ttsVoiceLocale = prefs.getString('tts_voice_locale');
    _ttsRate = prefs.getDouble('tts_rate') ?? 0.45;
    _ttsPitch = prefs.getDouble('tts_pitch') ?? 1.0;
    _ttsVolume = prefs.getDouble('tts_volume') ?? 1.0;
    _speakUnreadSummaryOnOpen = prefs.getBool('speak_unread_summary') ?? true;
    
    print('🔔 Notification preferences loaded: System: $_systemNotificationsEnabled, Audio: $_audioNotificationsEnabled, In-app: $_inAppNotificationsEnabled');
  }

  // Update notification preferences
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
    
    print('🔔 Notification preferences updated');
  }

  Future<void> updateTtsPreferences({
    String? language,
    String? voiceName,
    String? voiceLocale,
    double? rate,
    double? pitch,
    double? volume,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (language != null) {
      _ttsLanguage = language;
      await prefs.setString('tts_language', language);
    }
    if (voiceName != null) {
      _ttsVoiceName = voiceName;
      await prefs.setString('tts_voice_name', voiceName);
    }
    if (voiceLocale != null) {
      _ttsVoiceLocale = voiceLocale;
      await prefs.setString('tts_voice_locale', voiceLocale);
    }
    if (rate != null) {
      _ttsRate = rate.clamp(0.1, 1.0);
      await prefs.setDouble('tts_rate', _ttsRate);
    }
    if (pitch != null) {
      _ttsPitch = pitch.clamp(0.5, 2.0);
      await prefs.setDouble('tts_pitch', _ttsPitch);
    }
    if (volume != null) {
      _ttsVolume = volume.clamp(0.0, 1.0);
      await prefs.setDouble('tts_volume', _ttsVolume);
    }
    await _applyTtsSettings();
  }

  Future<void> refreshTtsOptions() async {
    try {
      // These can throw on some platforms; guard with try/catch
      final voices = await _tts.getVoices;
      final langs = await _tts.getLanguages;
      if (voices is List) _availableVoices = voices;
      if (langs is List) _availableLanguages = langs;
    } catch (_) {
      // Fallbacks
      _availableVoices = const [];
      _availableLanguages = const ['en-US'];
    }
  }

  Future<void> _ensureZAdefaults() async {
    try {
      if (_ttsLanguage == null || _ttsLanguage!.isEmpty) {
        await updateTtsPreferences(language: 'en-ZA');
      }
      
      // Set human-like default TTS settings for better naturalness
      if (_ttsRate == 0.5) { // Default unchanged
        await updateTtsPreferences(
          rate: 0.6,  // Slightly faster than default for more natural flow
          pitch: 0.9, // Slightly lower pitch sounds more natural
          volume: 0.8 // Comfortable volume level
        );
      }
      
      if ((_ttsVoiceName == null || _ttsVoiceName!.isEmpty) && _availableVoices.isNotEmpty) {
        // Prioritize more natural-sounding voices
        String? bestVoice;
        String? bestLocale;
        
        for (final v in _availableVoices) {
          if (v is Map) {
            final locale = (v['locale']?.toString() ?? '').toLowerCase();
            final name = (v['name']?.toString() ?? '').toLowerCase();
            
            // Prioritize South African voices first
            if (locale.contains('en-za') || locale.contains('en_za')) {
              // Look for enhanced/premium/neural voices
              if (name.contains('enhanced') || name.contains('premium') || 
                  name.contains('neural') || name.contains('natural') ||
                  name.contains('female') || name.contains('male')) {
                bestVoice = v['name']?.toString();
                bestLocale = v['locale']?.toString();
                break;
              } else if (bestVoice == null) {
                // Fallback to any South African voice
                bestVoice = v['name']?.toString();
                bestLocale = v['locale']?.toString();
              }
            }
            // Fallback to other English voices if no ZA available
            else if (bestVoice == null && (locale.contains('en-') || locale.contains('en_'))) {
              if (name.contains('enhanced') || name.contains('premium') || 
                  name.contains('neural') || name.contains('natural')) {
                bestVoice = v['name']?.toString();
                bestLocale = v['locale']?.toString();
              }
            }
          }
        }
        
        if (bestVoice != null && bestVoice.isNotEmpty) {
          await updateTtsPreferences(voiceName: bestVoice, voiceLocale: bestLocale);
        }
      }
    } catch (_) {}
  }

  Future<void> _applyTtsSettings() async {
    try {
      await _tts.setSpeechRate(_ttsRate);
      await _tts.setPitch(_ttsPitch);
      await _tts.setVolume(_ttsVolume);
      if (_ttsLanguage != null) {
        await _tts.setLanguage(_ttsLanguage!);
      }
      if (_ttsVoiceName != null && _ttsVoiceLocale != null) {
        await _tts.setVoice({ 'name': _ttsVoiceName!, 'locale': _ttsVoiceLocale! });
      }
    } catch (e) {
      print('❌ Applying TTS settings failed: $e');
    }
  }

  // Convert order/product IDs to human-readable format
  static String formatOrderNumber(String orderId) {
    if (orderId.isEmpty) return orderId;
    
    // If it's already a formatted number (contains letters/spaces), leave it
    if (orderId.contains(' ') || RegExp(r'[A-Za-z]').hasMatch(orderId)) {
      return orderId;
    }
    
    // Firebase document IDs are typically 20+ characters
    if (orderId.length > 15) {
      // Take first 3 and last 4 characters with hyphens for readability
      return 'Order ${orderId.substring(0, 3)}-${orderId.substring(orderId.length - 4)}';
    } else if (orderId.length > 8) {
      // Medium length IDs - split in middle
      final mid = orderId.length ~/ 2;
      return 'Order ${orderId.substring(0, mid)}-${orderId.substring(mid)}';
    } else {
      // Short IDs - just add prefix
      return 'Order $orderId';
    }
  }
  
  static String formatProductId(String productId) {
    if (productId.isEmpty) return productId;
    
    // If it's already formatted, leave it
    if (productId.contains(' ') || RegExp(r'[A-Za-z]').hasMatch(productId)) {
      return productId;
    }
    
    // Similar logic for product IDs
    if (productId.length > 15) {
      return 'Product ${productId.substring(0, 3)}-${productId.substring(productId.length - 4)}';
    } else if (productId.length > 8) {
      final mid = productId.length ~/ 2;
      return 'Product ${productId.substring(0, mid)}-${productId.substring(mid)}';
    } else {
      return 'Product $productId';
    }
  }

  // Preprocess text to sound more natural when spoken
  String _makeTextMoreNatural(String text) {
    String processedText = text;
    
    // Convert order and product IDs to human-readable format
    processedText = processedText
        .replaceAllMapped(RegExp(r'Order\s*[#:]?\s*([A-Za-z0-9]{8,})', caseSensitive: false), (match) {
          final orderId = match.group(1)!;
          return formatOrderNumber(orderId);
        })
        .replaceAllMapped(RegExp(r'order\s*(?:number|id|#)?\s*([A-Za-z0-9]{8,})', caseSensitive: false), (match) {
          final orderId = match.group(1)!;
          return formatOrderNumber(orderId);
        })
        .replaceAllMapped(RegExp(r'Product\s*[#:]?\s*([A-Za-z0-9]{8,})', caseSensitive: false), (match) {
          final productId = match.group(1)!;
          return formatProductId(productId);
        })
        .replaceAllMapped(RegExp(r'product\s*(?:id|#)?\s*([A-Za-z0-9]{8,})', caseSensitive: false), (match) {
          final productId = match.group(1)!;
          return formatProductId(productId);
        });
    
    // Replace abbreviations with full words for better pronunciation
    processedText = processedText
        .replaceAll(RegExp(r'\bR(\d+)', caseSensitive: false), r'Rand \1') // R100 -> Rand 100
        .replaceAll(RegExp(r'\bRS(\d+)', caseSensitive: false), r'Rand \1') // RS100 -> Rand 100
        .replaceAll(RegExp(r'\bZAR(\d+)', caseSensitive: false), r'Rand \1') // ZAR100 -> Rand 100
        .replaceAll('&', 'and') // & -> and
        .replaceAll('@', 'at') // @ -> at
        .replaceAll('vs', 'versus') // vs -> versus
        .replaceAll('etc', 'etcetera') // etc -> etcetera
        .replaceAll('kg', 'kilograms') // kg -> kilograms
        .replaceAll('km', 'kilometers') // km -> kilometers
        .replaceAll('m²', 'square meters') // m² -> square meters
        .replaceAll('°C', 'degrees celsius') // °C -> degrees celsius
        .replaceAll('%', 'percent') // % -> percent
        .replaceAll('No.', 'Number') // No. -> Number
        .replaceAll('Dr.', 'Doctor') // Dr. -> Doctor
        .replaceAll('Mr.', 'Mister') // Mr. -> Mister
        .replaceAll('Mrs.', 'Missus') // Mrs. -> Missus
        .replaceAll('St.', 'Street') // St. -> Street
        .replaceAll('Ave.', 'Avenue') // Ave. -> Avenue
        .replaceAll('Rd.', 'Road') // Rd. -> Road
        .replaceAll('CEO', 'Chief Executive Officer')
        .replaceAll('SMS', 'text message')
        .replaceAll('GPS', 'GPS navigation')
        .replaceAll('ID', 'identification')
        .replaceAll('FAQ', 'frequently asked questions')
        .replaceAll('PDF', 'document')
        .replaceAll('URL', 'web address')
        .replaceAll('WiFi', 'Wi-Fi')
        .replaceAll('COVID', 'Covid')
        .replaceAll('USD', 'US Dollars')
        .replaceAll('EUR', 'Euros')
        .replaceAll('GBP', 'British Pounds');
    
    // Add natural pauses for better rhythm
    processedText = processedText
        .replaceAll(RegExp(r'([.!?])\s*'), r'\1 ... ') // Add pause after sentences
        .replaceAll(RegExp(r'([,:;])\s*'), r'\1 .. ') // Add shorter pause after commas
        .replaceAll(RegExp(r'(-{2,}|\s-\s)'), ' .. ') // Replace dashes with pauses
        .replaceAll(RegExp(r'\s+'), ' '); // Clean up multiple spaces
    
    // South African specific pronunciations
    processedText = processedText
        .replaceAll('Gauteng', 'How-teng') // Better pronunciation
        .replaceAll('Pretoria', 'Pre-tor-ia')
        .replaceAll('Johannesburg', 'Joe-han-nis-burg')
        .replaceAll('Stellenbosch', 'Stel-len-bosh')
        .replaceAll('Durban', 'Der-ban')
        .replaceAll('Cape Town', 'Cape Town')
        .replaceAll('Sandton', 'Sand-ton')
        .replaceAll('Rosebank', 'Rose-bank')
        .replaceAll('braai', 'barbecue') // For international users
        .replaceAll('biltong', 'bil-tong');
    
    // Add emotional context for notifications
    if (processedText.toLowerCase().contains('order confirmed') || 
        processedText.toLowerCase().contains('payment successful')) {
      processedText = 'Great news! ' + processedText;
    } else if (processedText.toLowerCase().contains('delivered') || 
               processedText.toLowerCase().contains('completed')) {
      processedText = 'Excellent! ' + processedText;
    } else if (processedText.toLowerCase().contains('error') || 
               processedText.toLowerCase().contains('failed')) {
      processedText = 'Unfortunately, ' + processedText;
    } else if (processedText.toLowerCase().contains('reminder') || 
               processedText.toLowerCase().contains('due')) {
      processedText = 'Just a friendly reminder: ' + processedText;
    }
    
    return processedText.trim();
  }

  // 🚀 AWESOME NOTIFICATION PERMISSION REQUEST
  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) {
        // Web: Ensure Notification API exists before checking permission
        if (!WebEnv.hasNotificationApi) {
          print('❌ Browser does not support notifications');
          return false;
        }

        // Web: Check current permission status first
        if (!js.context.hasProperty('Notification')) {
          print('❌ Browser does not define Notification API');
          return false;
        }
        
        final String? currentPermission = js.context.callMethod('eval', ['Notification.permission']);
        print('🔔 Current notification permission: $currentPermission');
        
        if (currentPermission == 'granted') {
          print('✅ Notifications already enabled!');
          await _showWelcomeNotification();
          return true;
        } else if (currentPermission == 'denied') {
          print('❌ Notifications blocked by user');
          await _showPermissionHelpNotification();
          return false;
        } else {
          // Permission is 'default', request it with better UX
          print('🔔 Requesting awesome notification permissions...');
          
          // Show pre-permission explanation
          await _showPrePermissionNotification();
          
          // Request permission with proper Promise handling
          try {
            final permissionResult = await _requestNotificationPermissionAsync();
            
            if (permissionResult == 'granted') {
              print('✅ Notification permissions granted!');
              await _showWelcomeNotification();
              return true;
            } else if (permissionResult == 'denied') {
              print('❌ Notification permissions denied');
              await _showPermissionHelpNotification();
              return false;
            } else {
              print('⏳ Notification permission request dismissed');
              return false;
            }
          } catch (e) {
            print('❌ Error requesting notification permission: $e');
            return false;
          }
        }
      } else {
        // Mobile: For now, return true (will be implemented later)
        return true;
      }
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  // 🎯 Request notification permission with proper Promise handling
  Future<String> _requestNotificationPermissionAsync() async {
    try {
      // Create a more robust permission request
      final result = js.context.callMethod('eval', ['''
        (async function() {
          try {
            console.log("🔔 Requesting notification permission...");
            const permission = await Notification.requestPermission();
            console.log("🔔 Permission result:", permission);
            return permission;
          } catch (error) {
            console.error("❌ Permission request error:", error);
            return "error";
          }
        })()
      ''']);
      
      // Handle the Promise result
      if (result != null) {
        return result.toString();
      }
      return 'error';
    } catch (e) {
      print('❌ Error in async permission request: $e');
      return 'error';
    }
  }

  // 📢 Show pre-permission explanation
  Future<void> _showPrePermissionNotification() async {
    try {
      // Could show an in-app dialog explaining the benefits
      print('💡 Would show pre-permission explanation here');
      // For now, just log - in a real app you'd show a friendly dialog
    } catch (e) {
      print('❌ Error showing pre-permission notification: $e');
    }
  }

  // 🎉 Show welcome notification after permission granted
  Future<void> _showWelcomeNotification() async {
    try {
      if (kIsWeb) {
        js.context.callMethod('eval', ['''
          if (Notification.permission === 'granted') {
            new Notification('🎉 Awesome Notifications Enabled!', {
              body: 'You\'ll now receive real-time updates about your orders, messages, and promotions.',
              icon: '/icons/Icon-192.png',
              badge: '/icons/Icon-192.png',
              tag: 'welcome',
              silent: false,
              requireInteraction: false,
              vibrate: [100, 50, 100, 50, 200],
              image: '/icons/notification-hero.png',
              actions: [
                { action: 'explore', title: '🚀 Explore App', icon: '/icons/explore-icon.png' },
                { action: 'settings', title: '⚙️ Settings', icon: '/icons/settings-icon.png' }
              ]
            });
          }
        ''']);
      }
    } catch (e) {
      print('❌ Error showing welcome notification: $e');
    }
  }

  // 💡 Show help for users who denied permissions
  Future<void> _showPermissionHelpNotification() async {
    try {
      print('💡 Notifications are blocked. You can enable them in your browser settings.');
      // Could show in-app guidance here
    } catch (e) {
      print('❌ Error showing permission help: $e');
    }
  }

  // Show chat notification
  Future<void> showChatNotification({
    required String chatId,
    required String senderId,
    required String message,
  }) async {
    try {
      // Don't show notification if sender is the current user
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null && senderId == currentUserId) {
        print('🔇 Skipping chat notification - message sent by current user');
        return;
      }

      // Get sender's name
      final senderDoc = await _firestore
          .collection('users')
          .doc(senderId)
          .get();
      
      final senderName = senderDoc.data()?['displayName'] ?? 
                        senderDoc.data()?['email']?.split('@')[0] ?? 
                        'Someone';

      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          _showWebNotification(
            title: senderName,
            body: message.isNotEmpty ? message : 'New message',
            icon: '/icons/Icon-192.png',
            tag: 'chat_$chatId',
            payload: {
              'type': 'chat_message',
              'chatId': chatId,
              'senderId': senderId,
            },
          );
        } else {
          // Mobile: For now, just show in-app notification
          print('📱 Mobile notification will be implemented later');
        }
      }

      // Add to notification stream for in-app display (temporary)
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'chat_message',
          'title': senderName,
          'body': message.isNotEmpty ? message : 'New message',
          'chatId': chatId,
          'senderId': senderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Play sound if enabled
      if (_audioNotificationsEnabled) {
        await _soundService.playNotificationSound();
      }
      // Update badge count
      await _updateBadgeForCurrentUser();

      // DO NOT store chat messages in notifications database
      // Chat messages should only appear in the chat interface
      // This prevents chat messages from cluttering the notifications list

      print('🔔 Chat notification sent for chat $chatId from $senderName');
    } catch (e) {
      print('❌ Error showing chat notification: $e');
    }
  }

  // Show order notification
  Future<void> showOrderNotification({
    required String title,
    required String body,
    required String orderId,
    required String type,
  }) async {
    try {
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          _showWebNotification(
            title: title,
            body: body,
            icon: '/icons/Icon-192.png',
            tag: 'order_$orderId',
            payload: {
              'type': 'order',
              'orderId': orderId,
              'orderType': type,
            },
          );
        } else {
          // Mobile: For now, just show in-app notification
          print('📱 Mobile notification will be implemented later');
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'order',
          'title': title,
          'body': body,
          'orderId': orderId,
          'orderType': type,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Play sound if enabled
      if (_audioNotificationsEnabled) {
        await _soundService.playNotificationSound();
      }
      // Update badge count
      await _updateBadgeForCurrentUser();

      // Voice announcement if enabled
      if (_voiceAnnouncementsEnabled) {
        await _speakSafe('$title. $body');
      }

      // Store in Firestore for persistence
      await _storeNotificationInDatabase(
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        title: title,
        body: body,
        type: 'order',
        data: {
          'orderId': orderId,
          'orderType': type,
        },
      );

      print('🔔 Order notification shown: $title');
    } catch (e) {
      print('❌ Error showing order notification: $e');
    }
  }

  // Show web notification using browser's native notification API
  void _showWebNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
    Map<String, dynamic>? payload,
  }) {
    try {
      // Check if browser supports notifications
      if (!js.context.hasProperty('Notification')) {
        print('❌ Browser does not support notifications');
        return;
      }

      // Check permission
      final permission = js.context.callMethod('eval', ['Notification.permission']);
      if (permission != 'granted') {
        print('❌ Notification permission not granted');
        return;
      }

      // Create notification options
      final options = js.JsObject.jsify({
        'body': body,
        'icon': icon ?? '/icons/Icon-192.png',
        'tag': tag ?? 'marketplace_notification',
        'data': payload ?? {},
        'requireInteraction': false,
        'silent': false,
      });

      // Create notification via constructor: new Notification(title, options)
      final dynamic notification = js.context.callMethod('eval', [
        'new Notification(' +
            js.context.callMethod('JSON', ['']).toString() +
            ')'
      ]);

      // Add click event listener
      if (notification != null) notification.callMethod('addEventListener', [
        'click',
        js.allowInterop((event) {
          print('🔔 Web notification clicked');
          // TODO: implement deep-link routing via hash or postMessage
          if (payload != null && payload['orderId'] != null) {
            print('🔔 Navigating to order: ${payload['orderId']}');
          }
        })
      ]);

      // Auto-close after 5 seconds
      js.context.callMethod('setTimeout', [
        js.allowInterop(() {
          if (notification != null) notification.callMethod('close');
        }),
        5000
      ]);

      print('✅ Web notification shown: $title');
    } catch (e) {
      print('❌ Error showing web notification: $e');
    }
  }

  Future<void> _speakSafe(String text) async {
    try {
      if (!_voiceAnnouncementsEnabled) return;
      if (kIsWeb) {
        // Web: use SpeechSynthesis via JS
        try {
          // Process text to sound more natural
          final naturalText = _makeTextMoreNatural(text);
          final jsText = naturalText.replaceAll("'", " ");
          
          js.context.callMethod('eval', [
            "(function(){try{window.speechSynthesis.cancel();var u=new SpeechSynthesisUtterance('" + jsText + "');" +
            "u.rate=" + _ttsRate.toString() + ";u.pitch=" + _ttsPitch.toString() + ";u.volume=" + _ttsVolume.toString() + ";" +
            ( _ttsLanguage != null ? "u.lang='" + (_ttsLanguage ?? '') + "';" : "" ) +
            "window.speechSynthesis.speak(u);}catch(e){}})();"
          ]);
        } catch (_) {}
        return;
      }
      await _tts.stop();
      // Process text to sound more natural
      final naturalText = _makeTextMoreNatural(text);
      await _tts.speak(naturalText);
    } catch (e) {
      print('❌ TTS speak failed: $e');
    }
  }

  // Public preview speak
  Future<void> speakPreview(String text) async {
    await _speakSafe(text);
  }

  // Speak unread summary
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
      final int notifUnread = notifQuery.size;
      final int chatUnread = await _getTotalUnreadCount(userId);
      final int total = notifUnread + chatUnread;
      if (total <= 0) return;
      final parts = <String>[];
      if (notifUnread > 0) parts.add('$notifUnread ${notifUnread == 1 ? 'notification' : 'notifications'}');
      if (chatUnread > 0) parts.add('$chatUnread ${chatUnread == 1 ? 'chat' : 'chats'}');
      final phrase = 'You have ${parts.join(' and ')}.';
      await _speakSafe(phrase);
    } catch (_) {}
  }

  // Show general notification
  Future<void> showGeneralNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    try {
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          _showWebNotification(
            title: title,
            body: body,
            icon: '/icons/Icon-192.png',
            tag: 'general_${DateTime.now().millisecondsSinceEpoch}',
            payload: payload?.map((key, value) => MapEntry(key, value)),
          );
        } else {
          // Mobile: For now, just show in-app notification
          print('📱 Mobile notification will be implemented later');
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'general',
          'title': title,
          'body': body,
          'payload': payload,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Store in Firestore for persistence
      await _storeNotificationInDatabase(
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        title: title,
        body: body,
        type: 'general',
        data: payload?.map((key, value) => MapEntry(key, value)),
      );

      // Voice announcement if enabled
      if (_voiceAnnouncementsEnabled) {
        await _speakSafe('$title. $body');
      }
      // Update badge count
      await _updateBadgeForCurrentUser();

      print('🔔 General notification shown: $title');
    } catch (e) {
      print('❌ Error showing general notification: $e');
    }
  }

  // Admin alert helper for high-risk events
  static Future<void> sendAdminAlert({
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'title': title,
        'message': message,
        'data': data,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Test notification method for debugging
  Future<void> testNotification() async {
    try {
      print('🧪 Testing notification system...');
      
      if (kIsWeb) {
        _showWebNotification(
          title: 'Test Notification',
          body: 'This is a test notification from Mzansi Marketplace',
          icon: '/icons/Icon-192.png',
          tag: 'test_${DateTime.now().millisecondsSinceEpoch}',
          payload: {
            'type': 'test',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } else {
        // Mobile: For now, just show in-app notification
        print('📱 Mobile test notification will be implemented later');
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'test',
          'title': 'Test Notification',
          'body': 'This is a test notification to verify the system is working',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
      
      print('✅ Test notification sent successfully');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) {
      // Web notifications are auto-dismissed, no need to cancel
      print('🔔 Web notifications auto-dismissed');
    } else {
      // Mobile: For now, just log
      print('📱 Mobile notification cancellation will be implemented later');
    }
  }

  Future<void> _setAppBadge(int count) async {
    try {
      if (count <= 0) {
        await FlutterAppBadger.removeBadge();
      } else {
        await FlutterAppBadger.updateBadgeCount(count);
      }
    } catch (e) {
      print('❌ Badge update failed: $e');
    }
  }

  Future<void> _updateBadgeForCurrentUser() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final unread = await _getTotalUnreadCount(userId);
      await _setAppBadge(unread);
    } catch (e) {
      print('❌ Badge recalc failed: $e');
    }
  }

  // Public wrapper to recalc badge
  Future<void> recalcBadge() async {
    await _updateBadgeForCurrentUser();
  }

  // Public method to get unread count for a specific user
  Future<int> getUnreadCountForUser(String userId) async {
    return await _getTotalUnreadCount(userId);
  }

  void _attachRealtimeSpeakListener() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      _notifSub?.cancel();
      _notifListenerInitialized = false;
      _notifSub = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .listen((snapshot) async {
        if (!_voiceAnnouncementsEnabled) return;
        if (!_notifListenerInitialized) {
          _notifListenerInitialized = true;
          return;
        }
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final id = change.doc.id;
            if (_spokenNotificationIds.contains(id)) continue;
            _spokenNotificationIds.add(id);
            final data = change.doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            await _speakForNotificationData(data);
          }
        }
      }, onError: (e) {
        print('❌ Realtime speak listener error: $e');
      });
    } catch (e) {
      print('❌ Failed to attach realtime speak listener: $e');
    }
  }

  void _attachFcmOnMessageSpeak() {
    try {
      if (kIsWeb) return;
      _fcmSub?.cancel();
      _fcmSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (!_voiceAnnouncementsEnabled) return;
        
        // Check if this is from the current user (sender) - don't announce
        final currentUserId = _auth.currentUser?.uid;
        final senderId = message.data['senderId']?.toString();
        if (currentUserId != null && senderId == currentUserId) {
          return;
        }
        
        // Use simplified announcements based on message type
        final type = message.data['type']?.toString().toLowerCase() ?? '';
        final title = message.notification?.title ?? message.data['title']?.toString() ?? '';
        final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
        
        // Use same simplified logic as _speakForNotificationData
        await _speakForNotificationData({
          'type': type,
          'title': title,
          'body': body,
          'senderId': senderId,
          ...message.data,
        });
      }, onError: (e) {
        print('❌ FCM onMessage listener error: $e');
      });
    } catch (e) {
      print('❌ Failed to attach FCM onMessage listener: $e');
    }
  }

  Future<void> _speakForNotificationData(Map<String, dynamic> data) async {
    try {
      final type = (data['type'] as String?)?.toLowerCase() ?? '';
      
      // Check if this is a message from the current user (sender) - don't announce
      final currentUserId = _auth.currentUser?.uid;
      final senderId = data['senderId']?.toString();
      if (currentUserId != null && senderId == currentUserId) {
        // Don't announce messages sent by the current user
        return;
      }
      
      // Simplified announcements based on notification type
      switch (type) {
        case 'new_order_seller':
          await _speakSafe('You have a new order.');
          return;
        case 'order_status':
          await _speakSafe('Order status updated.');
          return;
        case 'chat_message':
          await _speakSafe('New message.');
          return;
        case 'payment_received':
          await _speakSafe('Payment received.');
          return;
        case 'payout_processed':
          await _speakSafe('Payout processed.');
          return;
        case 'product_approved':
          await _speakSafe('Product approved.');
          return;
        case 'product_rejected':
          await _speakSafe('Product rejected.');
          return;
        case 'delivery_update':
          await _speakSafe('Delivery update.');
          return;
        case 'review_received':
          await _speakSafe('New review received.');
          return;
        default:
          // For unknown types, just announce generic notification
          await _speakSafe('New notification.');
          return;
      }
    } catch (e) {
      print('❌ speakForNotificationData failed: $e');
    }
  }

  // Mark all notifications as read for current user
  Future<void> markAllNotificationsAsReadForCurrentUser() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final qs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .limit(500)
          .get();
      if (qs.docs.isEmpty) {
        await _updateBadgeForCurrentUser();
        return;
      }
      final batch = _firestore.batch();
      for (final d in qs.docs) {
        batch.update(d.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await _updateBadgeForCurrentUser();
    } catch (e) {
      print('❌ markAllNotificationsAsReadForCurrentUser failed: $e');
    }
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) {
      // Web notifications are auto-dismissed
      print('🔔 Web notification auto-dismissed: $id');
    } else {
      // Mobile: For now, just log
      print('📱 Mobile notification cancellation will be implemented later: $id');
    }
  }

  // Show in-app notification (snackbar)
  void showInAppNotification(BuildContext context, String message) {
    if (!_inAppNotificationsEnabled) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Dispose
  void dispose() {
    _notificationController.close();
    _notifSub?.cancel();
    _fcmSub?.cancel();
  }

  // ===== COMPATIBILITY METHODS FOR EXISTING CODE =====

  // Refresh notifications (compatibility method)
  Future<void> refreshNotifications() async {
    print('🔔 Refreshing notifications...');
    // This is a compatibility method - actual refresh logic would be implemented here
  }

  // Send local notification (compatibility method)
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await showGeneralNotification(
      title: title,
      body: body,
      payload: data?.map((key, value) => MapEntry(key.toString(), value.toString())),
    );
  }

  // Delete notification (compatibility method)
  Future<void> deleteNotification(String notificationId) async {
     try {
      print('🔔 Deleting notification: $notificationId');
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
      print('✅ Notification deleted successfully: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
      throw e;
    }
  }

  // Delete all notifications (compatibility method)
  Future<void> deleteAllNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found');
        return;
      }

      print('🔔 Deleting all notifications for user: ${currentUser.uid}');
      
      // Get all notifications for the current user
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .get();
      
      // Delete each notification
      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('✅ All notifications deleted successfully');
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
      throw e;
    }
  }

  // Mark notification as read (compatibility method)
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      print('🔔 Marking notification as read: $notificationId');
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      final msg = e.toString();
      // Soft-fail on permission issues so UX continues (rules may block updates)
      if (msg.contains('permission-denied')) {
        print('⚠️ Permission denied marking notification as read; continuing.');
        return;
      }
      print('❌ Error marking notification as read: $e');
      throw e;
    }
  }

  // Get notifications with validation (compatibility method)
  Stream<QuerySnapshot> getNotificationsWithValidation() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found');
        return Stream.empty();
      }

      print('🔍 Fetching notifications for user: ${currentUser.uid}');
      
      final stream = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .snapshots();
      
      return stream;
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return Stream.empty();
    }
  }



  // Send new order notification to seller
  Future<void> sendNewOrderNotificationToSeller({
    required String sellerId,
    required String orderId,
    required String buyerName,
    required double orderTotal,
    required String sellerName,
  }) async {
    try {
      print('🔍 DEBUG: sendNewOrderNotificationToSeller called');
      print('🔍 DEBUG: sellerId: $sellerId');
      print('🔍 DEBUG: orderId: $orderId');
      print('🔍 DEBUG: buyerName: $buyerName');
      print('🔍 DEBUG: orderTotal: $orderTotal');
      print('🔍 DEBUG: sellerName: $sellerName');
      
      // Validate seller ID
      if (sellerId.isEmpty) {
        print('❌ ERROR: Cannot send notification - sellerId is empty');
        return;
      }

      // Verify seller exists and is actually a seller
      print('🔍 DEBUG: Verifying seller exists...');
      final sellerDocCheck = await _firestore
          .collection('users')
          .doc(sellerId)
          .get();
      
      if (!sellerDocCheck.exists) {
        print('❌ ERROR: Cannot send notification - seller $sellerId does not exist');
        return;
      }

      final sellerDataCheck = sellerDocCheck.data();
      if (sellerDataCheck?['role'] != 'seller') {
        print('❌ ERROR: Cannot send notification - user $sellerId is not a seller (role: ${sellerDataCheck?['role']})');
        return;
      }

      print('🔔 Sending new order notification to seller: $sellerId');
      print('🔔 Order details: ID=$orderId, Buyer=$buyerName, Total=R$orderTotal');
      
      // Store notification in Firestore database
      print('🔍 DEBUG: Storing notification in database...');
      await _storeNotificationInDatabase(
        userId: sellerId,
        title: 'New Order Received',
        body: 'You have a new order from $buyerName for R${orderTotal.toStringAsFixed(2)}',
        type: 'new_order_seller',
        orderId: orderId,
        data: {
          'buyerName': buyerName,
          'orderTotal': orderTotal.toString(),
          'sellerName': sellerName,
        },
      );
      print('🔍 DEBUG: Notification stored in database');
      
      // Show local notification
      final notificationTitle = 'New Order Received';
      final notificationBody = 'You have a new order from $buyerName for R${orderTotal.toStringAsFixed(2)}';
      
      print('🔔 Showing order notification - Title: $notificationTitle, Body: $notificationBody');
      print('🔔 Notification settings - System: $_systemNotificationsEnabled, In-app: $_inAppNotificationsEnabled');
      
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          print('🔍 DEBUG: Showing web notification...');
          _showWebNotification(
            title: notificationTitle,
            body: notificationBody,
            icon: '/icons/Icon-192.png',
            tag: 'order_$orderId',
            payload: {
              'type': 'new_order_seller',
              'orderId': orderId,
            },
          );
          print('🔍 DEBUG: Web notification shown');
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        print('🔍 DEBUG: Adding to notification stream...');
        _notificationController.add({
          'type': 'new_order_seller',
          'title': notificationTitle,
          'body': notificationBody,
          'orderId': orderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('🔍 DEBUG: Added to notification stream');
      }
      
      // Play notification sound
      if (_audioNotificationsEnabled) {
        print('🔍 DEBUG: Playing notification sound...');
        await _soundService.playNotificationSound();
        print('🔍 DEBUG: Notification sound played');
      }
      // Voice announcement
      if (_voiceAnnouncementsEnabled) {
        try {
          await _speakSafe('New order received. Buyer $buyerName. Total R${orderTotal.toStringAsFixed(2)}.');
        } catch (_) {}
      }
      
      print('✅ New order notification to seller completed successfully');
      
    } catch (e) {
      print('❌ Error sending new order notification to seller: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
    }
  }

  // Store notification in Firestore database
  Future<void> _storeNotificationInDatabase({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? orderId,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('🔍 DEBUG: _storeNotificationInDatabase called');
      print('🔍 DEBUG: userId: $userId');
      print('🔍 DEBUG: title: $title');
      print('🔍 DEBUG: body: $body');
      print('🔍 DEBUG: type: $type');
      print('🔍 DEBUG: orderId: $orderId');
      print('🔍 DEBUG: data: $data');
      
      // Validate user ID is not empty
      if (userId.isEmpty) {
        print('❌ ERROR: Cannot store notification - userId is empty');
        return;
      }

      // Verify the user exists in the database
      print('🔍 DEBUG: Verifying user exists in database...');
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        print('❌ ERROR: Cannot store notification - user $userId does not exist in database');
        return;
      }
      print('🔍 DEBUG: User exists in database');

      final notificationData = {
        'title': title,
        'body': body,
        'type': type,
        'orderId': orderId,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'userId': userId,
        'route': '/order-tracking',
        'deeplink': 'foodmarketplace://order/$orderId',
        'screen': 'OrderTrackingScreen',
      };

      print('🔍 DEBUG: Notification data prepared: $notificationData');
      print('🔍 DEBUG: Adding to notifications collection...');

      final docRef = await _firestore
          .collection('notifications')
          .add(notificationData);
      
      print('✅ Notification stored in database for user: $userId with ID: ${docRef.id}');
      print('📋 Notification data: $notificationData');
      
    } catch (e) {
      print('❌ Error storing notification in database: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
    }
  }

  // Send order status notification to buyer
  Future<void> sendOrderStatusNotificationToBuyer({
    required String buyerId,
    required String orderId,
    required String status,
    required String sellerName,
  }) async {
    try {
      // Validate buyer ID
      if (buyerId.isEmpty) {
        print('❌ ERROR: Cannot send notification - buyerId is empty');
        return;
      }

      // Verify buyer exists
      final buyerDocCheck = await _firestore
          .collection('users')
          .doc(buyerId)
          .get();
      
      if (!buyerDocCheck.exists) {
        print('❌ ERROR: Cannot send notification - buyer $buyerId does not exist');
        return;
      }

      print('🔔 Sending order status notification to buyer: $buyerId');
      print('🔔 Order ID: $orderId, Status: $status, Seller: $sellerName');
      
      // Store notification in Firestore database
      await _storeNotificationInDatabase(
        userId: buyerId,
        title: 'Order Status Updated',
        body: 'Your order status has been updated to: $status',
        type: 'order_status',
        orderId: orderId,
        data: {
          'status': status,
          'sellerName': sellerName,
        },
      );
      
      print('✅ Notification stored in database for buyer: $buyerId');
      
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          try {
            _showWebNotification(
              title: 'Order Status Updated',
              body: 'Your order status has been updated to: $status',
              icon: '/icons/Icon-192.png',
              tag: 'order_$orderId',
              payload: {
                'type': 'order_status',
                'orderId': orderId,
              },
            );
            print('✅ Web notification sent');
          } catch (e) {
            print('❌ Web notification failed: $e');
          }
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'order_status',
          'title': 'Order Status Updated',
          'body': 'Your order status has been updated to: $status',
          'orderId': orderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ In-app notification added to stream');
      }
      
      // Play notification sound
      if (_audioNotificationsEnabled) {
        try {
          await _soundService.playNotificationSound();
          print('✅ Notification sound played');
        } catch (e) {
          print('❌ Notification sound failed: $e');
        }
      }
      // Voice announcement
      if (_voiceAnnouncementsEnabled) {
        try {
          await _speakSafe('Your order status is now $status.');
        } catch (_) {}
      }
      
      print('✅ Order status notification sent successfully to buyer: $buyerId');
      
    } catch (e) {
      print('❌ Error sending order status notification to buyer: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Fallback: Try to send a simple in-app notification
      try {
        _notificationController.add({
          'type': 'order_status',
          'title': 'Order Update',
          'body': 'Your order status has been updated to: $status',
          'orderId': orderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ Fallback in-app notification sent');
      } catch (fallbackError) {
        print('❌ Fallback notification also failed: $fallbackError');
      }
    }
  }

  // Send order status notification (compatibility method)
  Future<void> sendOrderStatusNotification({
    required String userId,
    required String orderId,
    required String status,
    required String orderNumber,
    required double totalPrice,
  }) async {
    try {
      print('🔔 Sending order status notification to user: $userId');
      print('🔔 Order details: ID=$orderId, Number=$orderNumber, Status=$status, Total=R$totalPrice');
      
      // Store notification in database
      await _storeNotificationInDatabase(
        userId: userId,
        title: 'Order Status Updated',
        body: '${formatOrderNumber(orderNumber)} status updated to $status',
        type: 'order_status',
        orderId: orderId,
        data: {
          'status': status,
          'orderNumber': orderNumber,
          'totalPrice': totalPrice.toString(),
        },
      );
      
      print('✅ Notification stored in database for user: $userId');
      
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          try {
            _showWebNotification(
              title: 'Order Status: $status',
              body: '${formatOrderNumber(orderNumber)} status updated to $status',
              icon: '/icons/Icon-192.png',
              tag: 'order_$orderId',
              payload: {
                'type': 'order_status',
                'orderId': orderId,
                'orderNumber': orderNumber,
              },
            );
            print('✅ Web notification sent');
          } catch (e) {
            print('❌ Web notification failed: $e');
          }
        }
      }

      // Add to notification stream for in-app display
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'order_status',
          'title': 'Order Status: $status',
          'body': '${formatOrderNumber(orderNumber)} status updated to $status',
          'orderId': orderId,
          'orderNumber': orderNumber,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ In-app notification added to stream');
      }
      
      // Play notification sound
      if (_audioNotificationsEnabled) {
        try {
          await _soundService.playNotificationSound();
          print('✅ Notification sound played');
        } catch (e) {
          print('❌ Notification sound failed: $e');
        }
      }
      // Voice announcement
      if (_voiceAnnouncementsEnabled) {
        try {
          await _speakSafe('${formatOrderNumber(orderNumber)}. Status now $status.');
        } catch (_) {}
      }
      
      print('✅ Order status notification sent successfully to user: $userId');
      
    } catch (e) {
      print('❌ Error sending order status notification to user: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Fallback: Try to send a simple in-app notification
      try {
        _notificationController.add({
          'type': 'order_status',
          'title': 'Order Update',
          'body': '${formatOrderNumber(orderNumber)} status updated to $status',
          'orderId': orderId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ Fallback in-app notification sent');
      } catch (fallbackError) {
        print('❌ Fallback notification also failed: $fallbackError');
      }
    }
  }

  // Request microphone permission (compatibility method)
  Future<bool> requestMicrophonePermission() async {
    print('🎤 Requesting microphone permission...');
    // This would use permission_handler package in a real implementation
    return true; // Assume granted for now
  }

  // Create notification (compatibility method)
  static Future<void> createNotification({
    required String title,
    required String body,
    required String userId,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final notificationService = NotificationService();
    await notificationService.showGeneralNotification(
      title: title,
      body: body,
      payload: data?.map((key, value) => MapEntry(key.toString(), value.toString())),
    );
  }

  // Show popup notification (compatibility method)
  static void showPopupNotification({
    required String title,
    required String message,
    VoidCallback? onTap,
  }) {
    print('🔔 Showing popup notification: $title');
    // This will be handled by the InAppNotificationWidget
  }

  // Show true system notification (compatibility method)
  static Future<void> showTrueSystemNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    print('🔔 Showing system notification: $title');
    // This will be handled by the InAppNotificationWidget
  }

  // Send driver assignment notification (compatibility method)
  static Future<void> sendDriverAssignmentNotification({
    required String driverId,
    required String orderId,
    required String message,
  }) async {
    print('🔔 Driver assignment notification sent to driver: $driverId');
    // This would send to driver's FCM token in a real implementation
  }

  // Send driver order status notification (compatibility method)
  static Future<void> sendDriverOrderStatusNotification({
    required String driverId,
    required String orderId,
    required String status,
    required String message,
  }) async {
    print('🔔 Driver order status notification sent to driver: $driverId');
    // This would send to driver's FCM token in a real implementation
  }

  // Send driver earnings notification (compatibility method)
  static Future<void> sendDriverEarningsNotification({
    required String driverId,
    required double amount,
    required String period,
  }) async {
    print('🔔 Driver earnings notification sent to driver: $driverId');
    // This would send to driver's FCM token in a real implementation
  }

  // Send push notification (compatibility method)
  static Future<void> sendPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    print('🔔 Push notification sent:');
    print('  Token: $token');
    print('  Title: $title');
    print('  Body: $body');
    print('  Data: $data');
    // TODO: Implement actual FCM sending
  }

  // Send chat notification to recipient
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    try {
      // Validate recipient ID
      if (recipientId.isEmpty) {
        print('❌ ERROR: Cannot send chat notification - recipientId is empty');
        return;
      }

      // Verify recipient exists
      final recipientDocCheck = await _firestore
          .collection('users')
          .doc(recipientId)
          .get();
      
      if (!recipientDocCheck.exists) {
        print('❌ ERROR: Cannot send chat notification - recipient $recipientId does not exist');
        return;
      }

      // Validate sender ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ ERROR: Cannot send chat notification - no authenticated sender');
        return;
      }

      // Verify sender exists
      final senderDocCheck = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!senderDocCheck.exists) {
        print('❌ ERROR: Cannot send chat notification - sender ${currentUser.uid} does not exist');
        return;
      }

      // Ensure sender and recipient are different
      if (currentUser.uid == recipientId) {
        print('❌ ERROR: Cannot send chat notification to self');
        return;
      }

      print('🔔 Sending chat notification to user: $recipientId');
      
      // DO NOT store chat messages in notifications database
      // Chat messages should only appear in the chat interface
      // This prevents chat messages from cluttering the notifications list
      
      // Show system notification if enabled
      if (_systemNotificationsEnabled) {
        if (kIsWeb) {
          _showWebNotification(
            title: 'New message from $senderName',
            body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
            icon: '/icons/Icon-192.png',
            tag: 'chat_$chatId',
            payload: {
              'type': 'chat_message',
              'chatId': chatId,
              'senderId': currentUser.uid,
              'senderName': senderName,
            },
          );
        }
      }

      // Add to notification stream for in-app display (temporary)
      if (_inAppNotificationsEnabled) {
        _notificationController.add({
          'type': 'chat_message',
          'title': 'New message from $senderName',
          'body': message.length > 50 ? '${message.substring(0, 50)}...' : message,
          'chatId': chatId,
          'senderId': currentUser.uid,
          'senderName': senderName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
      
      // Play notification sound
      if (_audioNotificationsEnabled) {
        await _soundService.playNotificationSound();
      }
      
    } catch (e) {
      print('❌ Error sending chat notification to recipient: $e');
    }
  }

  /// Get total unread count for a user across all chats AND notifications
  Future<int> _getTotalUnreadCount(String userId) async {
    try {
      int totalUnread = 0;
      
      // Count unread chat messages
      final chatsQuery = await _firestore
          .collection('chats')
          .where(Filter.or(
            Filter('buyerId', isEqualTo: userId),
            Filter('sellerId', isEqualTo: userId),
          ))
          .get();
      
      for (var chat in chatsQuery.docs) {
        final data = chat.data();
        final unreadCount = data['unreadCount'] as int? ?? 0;
        totalUnread += unreadCount;
      }
      
      // Count unread notifications (excluding chat messages)
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      for (var notification in notificationsQuery.docs) {
        final data = notification.data();
        final type = data['type'] as String? ?? '';
        // Only count non-chat notifications since chat messages are handled above
        if (type != 'chat_message') {
          totalUnread += 1;
        }
      }
      
      print('🔔 Total unread count for user $userId: $totalUnread (chats + notifications)');
      return totalUnread;
    } catch (e) {
      print('❌ Error getting total unread count: $e');
      return 0;
    }
  }
} 