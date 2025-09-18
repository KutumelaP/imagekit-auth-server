import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/voice_service.dart';

/// Language configuration for voice assistant
class VoiceLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String voiceName;
  final double speechRate;
  final double pitch;
  final String greeting;
  final String helpMessage;

  const VoiceLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.voiceName,
    this.speechRate = 0.8,
    this.pitch = 1.1,
    required this.greeting,
    required this.helpMessage,
  });
}

/// Multi-language Voice Manager
class VoiceLanguageManager {
  static final VoiceLanguageManager _instance = VoiceLanguageManager._internal();
  factory VoiceLanguageManager() => _instance;
  VoiceLanguageManager._internal();

  final VoiceService _voiceService = VoiceService();
  final StreamController<VoiceLanguage> _languageController = StreamController<VoiceLanguage>.broadcast();
  
  VoiceLanguage _currentLanguage = _supportedLanguages['en']!;
  
  /// Supported languages
  static const Map<String, VoiceLanguage> _supportedLanguages = {
    'en': VoiceLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      voiceName: 'en-US-Wavenet-C', // Child-like voice for Nathan
      speechRate: 0.6, // Slower for baby speech
      pitch: 1.8, // Very high pitch for baby voice
      greeting: "Hello! I'm Nathan, your little shopping buddy! How can I help you today?",
      helpMessage: "I can help you search for products, navigate the app, and answer questions. What would you like to do?",
    ),
    'zu': VoiceLanguage(
      code: 'zu',
      name: 'Zulu',
      nativeName: 'isiZulu',
      voiceName: 'zu-ZA-Wavenet-B', // Male voice for Nathan
      speechRate: 0.6, // Slower for baby speech
      pitch: 1.8, // Very high pitch for baby voice
      greeting: "Sawubona! NginguNathan, umncedi wakho omncane wokuthenga! Ngingakusiza kanjani namuhla?",
      helpMessage: "Ngingakusiza ukufuna imikhiqizo, ukuqondisa uhlelo, nokuphendula imibuzo. Ufuna ukwenzani?",
    ),
    'xh': VoiceLanguage(
      code: 'xh',
      name: 'Xhosa',
      nativeName: 'isiXhosa',
      voiceName: 'xh-ZA-Wavenet-B', // Male voice for Nathan
      speechRate: 0.6, // Slower for baby speech
      pitch: 1.8, // Very high pitch for baby voice
      greeting: "Molo! NdinguNathan, umncedi wakho omncinci wokuthenga! Ndingakunceda njani namhlanje?",
      helpMessage: "Ndingakunceda ukufuna iimveliso, ukuqondisa isicelo, nokuphendula imibuzo. Ufuna ukwenzani?",
    ),
    'af': VoiceLanguage(
      code: 'af',
      name: 'Afrikaans',
      nativeName: 'Afrikaans',
      voiceName: 'af-ZA-Wavenet-B', // Male voice for Nathan
      speechRate: 0.6, // Slower for baby speech
      pitch: 1.8, // Very high pitch for baby voice
      greeting: "Hallo! Ek is Nathan, jou klein inkopie-maatjie! Hoe kan ek jou vandag help?",
      helpMessage: "Ek kan jou help om produkte te soek, die app te navigeer, en vrae te beantwoord. Wat wil jy doen?",
    ),
    'nso': VoiceLanguage(
      code: 'nso',
      name: 'Sepedi',
      nativeName: 'Sesotho sa Leboa',
      voiceName: 'nso-ZA-Wavenet-B', // Male voice for Nathan
      speechRate: 0.6, // Slower for baby speech
      pitch: 1.8, // Very high pitch for baby voice
      greeting: "Dumela! Ke Nathan, morutiši wa gago wa go reka yo monnye! Nka go thuša bjang lehono?",
      helpMessage: "Nka go thuša go nyaka dithoto, go sepela ka app, le go araba dipotšišo. O nyaka go dira eng?",
    ),
  };

  /// Current language
  VoiceLanguage get currentLanguage => _currentLanguage;

  /// Stream of language changes
  Stream<VoiceLanguage> get languageStream => _languageController.stream;

  /// Get all supported languages
  List<VoiceLanguage> get supportedLanguages => _supportedLanguages.values.toList();

  /// Change language
  Future<void> changeLanguage(String languageCode) async {
    if (_supportedLanguages.containsKey(languageCode)) {
      _currentLanguage = _supportedLanguages[languageCode]!;
      
      // Update voice service configuration
      await _voiceService.updateConfig(
        VoiceConfig(
          language: _currentLanguage.code,
          speechRate: _currentLanguage.speechRate,
          pitch: _currentLanguage.pitch,
          voiceName: _currentLanguage.voiceName,
          audioEncoding: "MP3",
        ),
      );
      
      _languageController.add(_currentLanguage);
      
      if (kDebugMode) {
        print('🌍 Language changed to: ${_currentLanguage.nativeName}');
      }
    }
  }

  /// Auto-detect language from user input
  Future<void> autoDetectLanguage(String input) async {
    // Simple language detection based on common words
    final inputLower = input.toLowerCase();
    
    // Zulu detection
    if (inputLower.contains('sawubona') || 
        inputLower.contains('ngiyabonga') || 
        inputLower.contains('ngicela')) {
      await changeLanguage('zu');
      return;
    }
    
    // Xhosa detection
    if (inputLower.contains('molo') || 
        inputLower.contains('ndiyabulela') || 
        inputLower.contains('ndicela')) {
      await changeLanguage('xh');
      return;
    }
    
    // Afrikaans detection
    if (inputLower.contains('hallo') || 
        inputLower.contains('dankie') || 
        inputLower.contains('asseblief')) {
      await changeLanguage('af');
      return;
    }
    
    // Sepedi detection
    if (inputLower.contains('dumela') || 
        inputLower.contains('ke a leboga') || 
        inputLower.contains('hle')) {
      await changeLanguage('nso');
      return;
    }
    
    // Default to English
    await changeLanguage('en');
  }

  /// Get localized message
  String getLocalizedMessage(String key) {
    switch (key) {
      case 'welcome':
        return _currentLanguage.greeting;
      case 'help':
        return _currentLanguage.helpMessage;
      case 'search_prompt':
        return _getSearchPrompt();
      case 'cart_prompt':
        return _getCartPrompt();
      case 'order_prompt':
        return _getOrderPrompt();
      default:
        return key; // Fallback to key if translation not found
    }
  }

  /// Get search prompt in current language
  String _getSearchPrompt() {
    switch (_currentLanguage.code) {
      case 'zu':
        return "Funa imikhiqizo ethile. Sho ukuthi ufuna ukufuna ini?";
      case 'xh':
        return "Funa iimveliso ezithile. Yithi ufuna ukufuna ntoni?";
      case 'af':
        return "Soek vir spesifieke produkte. Sê vir my wat jy soek?";
      case 'nso':
        return "Nyaka dithoto tše di rileng. Mpolele seo o se nyakago?";
      default:
        return "Search for specific products. Tell me what you're looking for?";
    }
  }

  /// Get cart prompt in current language
  String _getCartPrompt() {
    switch (_currentLanguage.code) {
      case 'zu':
        return "Hamba nami esitolo sakho. Ufuna ukubona izinto ozithandayo?";
      case 'xh':
        return "Hamba nam kwivenkile yakho. Ufuna ukubona izinto ozithandayo?";
      case 'af':
        return "Kom saam na my na jou winkelmandjie. Wil jy sien wat jy gekies het?";
      case 'nso':
        return "A re ye go tšhwantšhong ya gago. O nyaka go bona dilo tšeo o di kgethilego?";
      default:
        return "Let's go to your cart. Want to see what you've selected?";
    }
  }

  /// Get order prompt in current language
  String _getOrderPrompt() {
    switch (_currentLanguage.code) {
      case 'zu':
        return "Hamba nami kuma-oda akho. Ufuna ukubona ukuthi ziphi izinto ozithengile?";
      case 'xh':
        return "Hamba nam kwiioda zakho. Ufuna ukubona ukuba ziphi izinto ozithengileyo?";
      case 'af':
        return "Kom saam na my na jou bestellings. Wil jy sien wat jy bestel het?";
      case 'nso':
        return "A re ye go di-order tša gago. O nyaka go bona seo o se rekilego?";
      default:
        return "Let's check your orders. Want to see what you've purchased?";
    }
  }

  /// Speak localized message
  Future<void> speakLocalized(String key) async {
    final message = getLocalizedMessage(key);
    await _voiceService.speak(message);
  }

  /// Get language selection widget
  Widget buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Language / Khetha Ulimi / Khetha Ulwimi / Kies Taal / Kgetha Polelo',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...supportedLanguages.map((language) => ListTile(
            leading: CircleAvatar(
              child: Text(language.code.toUpperCase()),
            ),
            title: Text(language.nativeName),
            subtitle: Text(language.name),
            trailing: _currentLanguage.code == language.code
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => changeLanguage(language.code),
          )),
        ],
      ),
    );
  }

  /// Get voice commands in current language
  List<String> getLocalizedCommands() {
    switch (_currentLanguage.code) {
      case 'zu':
        return [
          "Funa [igama lomkhiqizo]",
          "Faka esitolo",
          "Hamba esitolo",
          "Bonisa ama-oda ami",
          "Hamba kumaphrofayili",
          "Hamba kumikhakha",
          "Siza",
        ];
      case 'xh':
        return [
          "Funa [igama lomveliso]",
          "Faka kwivenkile",
          "Hamba kwivenkile",
          "Bonisa iioda zam",
          "Hamba kwiprofile",
          "Hamba kwimikhakha",
          "Nceda",
        ];
      case 'af':
        return [
          "Soek vir [produk naam]",
          "Voeg by mandjie",
          "Gaan na mandjie",
          "Wys my bestellings",
          "Gaan na profiel",
          "Blai deur kategorieë",
          "Help",
        ];
      case 'nso':
        return [
          "Nyaka [leina la thoto]",
          "Oketša go tšhwantšho",
          "Ya go tšhwantšho",
          "Bontšha di-order tša ka",
          "Ya go profile",
          "Lebelela mekgahlelo",
          "Thušo",
        ];
      default:
        return [
          "Search for [product name]",
          "Add to cart",
          "Go to cart",
          "Show my orders",
          "Go to profile",
          "Browse categories",
          "Help",
        ];
    }
  }

  /// Dispose resources
  void dispose() {
    _languageController.close();
  }
}
