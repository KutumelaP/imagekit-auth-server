import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/voice_service.dart';
import 'voice_language_manager.dart';

/// Smart Voice Notification System
class VoiceNotificationSystem {
  static final VoiceNotificationSystem _instance = VoiceNotificationSystem._internal();
  factory VoiceNotificationSystem() => _instance;
  VoiceNotificationSystem._internal();

  final VoiceService _voiceService = VoiceService();
  final VoiceLanguageManager _languageManager = VoiceLanguageManager();
  
  Timer? _proactiveTimer;
  bool _isEnabled = false; // Proactive voice prompts disabled by default
  DateTime? _lastInteraction;
  
  /// Enable/disable voice notifications
  void setEnabled(bool enabled) {
    // Hard-disable proactive prompts
    _isEnabled = false;
    _stopProactiveMonitoring();
  }

  /// Start proactive monitoring
  void _startProactiveMonitoring() {
    // No-op: proactive prompts are disabled
    _stopProactiveMonitoring();
  }

  /// Stop proactive monitoring
  void _stopProactiveMonitoring() {
    _proactiveTimer?.cancel();
    _proactiveTimer = null;
  }

  /// Check for proactive help opportunities
  Future<void> _checkProactiveOpportunities() async {
    // No-op: proactive prompts are disabled
    return;
  }

  /// Send proactive help message
  Future<void> _sendProactiveHelp() async {
    final messages = [
      "Hello! I'm here if you need assistance with anything. Just ask me!",
      "Hi! I can help you search for products, navigate the app, or answer any questions you have.",
      "Need a hand? I can help you find stores, deals, or track orders.",
    ];
    
    final randomMessage = messages[DateTime.now().millisecond % messages.length];
    await _voiceService.speak(randomMessage);
  }

  /// Send voice notification
  Future<void> sendNotification({
    required String message,
    required VoiceNotificationType type,
    bool speakImmediately = true,
  }) async {
    if (!_isEnabled) return;
    
    final localizedMessage = _getLocalizedNotification(message, type);
    
    if (speakImmediately) {
      await _voiceService.speak(localizedMessage);
    }
    
    _lastInteraction = DateTime.now();
    
    if (kDebugMode) {
      print('🔔 Voice Notification [$type]: $localizedMessage');
    }
  }

  /// Get localized notification message
  String _getLocalizedNotification(String message, VoiceNotificationType type) {
    final currentLang = _languageManager.currentLanguage.code;
    
    switch (type) {
      case VoiceNotificationType.deal:
        return _getDealNotification(message, currentLang);
      case VoiceNotificationType.order:
        return _getOrderNotification(message, currentLang);
      case VoiceNotificationType.cart:
        return _getCartNotification(message, currentLang);
      case VoiceNotificationType.reminder:
        return _getReminderNotification(message, currentLang);
      case VoiceNotificationType.welcome:
        return _getWelcomeNotification(message, currentLang);
      case VoiceNotificationType.help:
        return _getHelpNotification(message, currentLang);
    }
  }

  /// Deal notification in different languages
  String _getDealNotification(String message, String lang) {
    switch (lang) {
      case 'zu':
        return "Umsindo! $message - Bona isaphulelo esikhulu!";
      case 'xh':
        return "Umsindo! $message - Bona isaphulelo esikhulu!";
      case 'af':
        return "Geweldig! $message - Kyk na hierdie groot afslag!";
      case 'nso':
        return "Go thabišago! $message - Lebelela thekolelo ye kgolo!";
      default:
        return "Exciting! $message - Check out this great deal!";
    }
  }

  /// Order notification in different languages
  String _getOrderNotification(String message, String lang) {
    switch (lang) {
      case 'zu':
        return "I-oda lakho: $message";
      case 'xh':
        return "I-oda yakho: $message";
      case 'af':
        return "Jou bestelling: $message";
      case 'nso':
        return "Order ya gago: $message";
      default:
        return "Your order: $message";
    }
  }

  /// Cart notification in different languages
  String _getCartNotification(String message, String lang) {
    switch (lang) {
      case 'zu':
        return "Isitolo sakho: $message";
      case 'xh':
        return "Ivenkile yakho: $message";
      case 'af':
        return "Jou mandjie: $message";
      case 'nso':
        return "Tšhwantšho ya gago: $message";
      default:
        return "Your cart: $message";
    }
  }

  /// Reminder notification in different languages
  String _getReminderNotification(String message, String lang) {
    switch (lang) {
      case 'zu':
        return "Isikhumbuzo: $message";
      case 'xh':
        return "Isikhumbuzo: $message";
      case 'af':
        return "Herinnering: $message";
      case 'nso':
        return "Segopotšo: $message";
      default:
        return "Reminder: $message";
    }
  }

  /// Welcome notification in different languages
  String _getWelcomeNotification(String message, String lang) {
    switch (lang) {
      case 'zu':
        return "Siyakwamukela! $message";
      case 'xh':
        return "Siyakwamukela! $message";
      case 'af':
        return "Welkom! $message";
      case 'nso':
        return "Re go amogela! $message";
      default:
        return "Welcome! $message";
    }
  }

  /// Help notification in different languages
  String _getHelpNotification(String message, String lang) {
    switch (lang) {
      case 'zu':
        return "Usizo: $message";
      case 'xh':
        return "Uncedo: $message";
      case 'af':
        return "Hulp: $message";
      case 'nso':
        return "Thušo: $message";
      default:
        return "Help: $message";
    }
  }

  /// Send deal notification
  Future<void> sendDealNotification(String productName, double discount) async {
    await sendNotification(
      message: "New deal on $productName - ${discount.toInt()}% off!",
      type: VoiceNotificationType.deal,
    );
  }

  /// Send order status notification
  Future<void> sendOrderStatusNotification(String orderId, String status) async {
    await sendNotification(
      message: "Order #$orderId is now $status",
      type: VoiceNotificationType.order,
    );
  }

  /// Send cart reminder
  Future<void> sendCartReminder(int itemCount) async {
    await sendNotification(
      message: "You have $itemCount items in your cart. Ready to checkout?",
      type: VoiceNotificationType.cart,
    );
  }

  /// Send welcome notification
  Future<void> sendWelcomeNotification(String userName) async {
    await sendNotification(
      message: "Welcome back, $userName! I'm here to help you shop.",
      type: VoiceNotificationType.welcome,
    );
  }

  /// Send help notification
  Future<void> sendHelpNotification(String helpMessage) async {
    await sendNotification(
      message: helpMessage,
      type: VoiceNotificationType.help,
    );
  }

  /// Send reminder notification
  Future<void> sendReminderNotification(String reminder) async {
    await sendNotification(
      message: reminder,
      type: VoiceNotificationType.reminder,
    );
  }

  /// Update last interaction time
  void updateLastInteraction() {
    _lastInteraction = DateTime.now();
  }

  /// Get notification settings widget
  Widget buildNotificationSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Voice Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable Voice Notifications'),
            subtitle: const Text('Get spoken updates about deals, orders, and more'),
            value: _isEnabled,
            onChanged: setEnabled,
          ),
          const SizedBox(height: 16),
          const Text(
            'Notification Types:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...VoiceNotificationType.values.map((type) => ListTile(
            leading: Icon(_getNotificationIcon(type)),
            title: Text(_getNotificationTitle(type)),
            subtitle: Text(_getNotificationDescription(type)),
          )),
        ],
      ),
    );
  }

  /// Get notification icon
  IconData _getNotificationIcon(VoiceNotificationType type) {
    switch (type) {
      case VoiceNotificationType.deal:
        return Icons.local_offer;
      case VoiceNotificationType.order:
        return Icons.shopping_bag;
      case VoiceNotificationType.cart:
        return Icons.shopping_cart;
      case VoiceNotificationType.reminder:
        return Icons.notifications;
      case VoiceNotificationType.welcome:
        return Icons.waving_hand;
      case VoiceNotificationType.help:
        return Icons.help;
    }
  }

  /// Get notification title
  String _getNotificationTitle(VoiceNotificationType type) {
    switch (type) {
      case VoiceNotificationType.deal:
        return 'Deal Alerts';
      case VoiceNotificationType.order:
        return 'Order Updates';
      case VoiceNotificationType.cart:
        return 'Cart Reminders';
      case VoiceNotificationType.reminder:
        return 'General Reminders';
      case VoiceNotificationType.welcome:
        return 'Welcome Messages';
      case VoiceNotificationType.help:
        return 'Help Notifications';
    }
  }

  /// Get notification description
  String _getNotificationDescription(VoiceNotificationType type) {
    switch (type) {
      case VoiceNotificationType.deal:
        return 'Get notified about new deals and discounts';
      case VoiceNotificationType.order:
        return 'Receive updates about your order status';
      case VoiceNotificationType.cart:
        return 'Reminders about items in your cart';
      case VoiceNotificationType.reminder:
        return 'General reminders and notifications';
      case VoiceNotificationType.welcome:
        return 'Welcome messages and greetings';
      case VoiceNotificationType.help:
        return 'Helpful tips and assistance';
    }
  }

  /// Dispose resources
  void dispose() {
    _stopProactiveMonitoring();
  }
}

/// Voice notification types
enum VoiceNotificationType {
  deal,
  order,
  cart,
  reminder,
  welcome,
  help,
}
