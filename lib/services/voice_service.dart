import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';

/// Configuration class for voice settings
class VoiceConfig {
  final String language;
  final double speechRate;
  final double pitch;
  final String voiceName;
  final String audioEncoding;
  
  const VoiceConfig({
    this.language = "en-US",
    this.speechRate = 0.8, // Slower for deeper male voice
    this.pitch = 0.7, // Lower pitch for male voice
    this.voiceName = "en-US-Neural2-D", // Ultra realistic Neural2 male voice
    this.audioEncoding = "MP3",
  });

  /// Predefined Neural2 voice configurations for different personalities
  static const VoiceConfig professionalMale = VoiceConfig(
    language: "en-US",
    speechRate: 0.8,
    pitch: 0.7,
    voiceName: "en-US-Neural2-D", // Deep, professional male
    audioEncoding: "MP3",
  );

  static const VoiceConfig friendlyMale = VoiceConfig(
    language: "en-US", 
    speechRate: 0.9,
    pitch: 0.8,
    voiceName: "en-US-Neural2-F", // Friendly male voice
    audioEncoding: "MP3",
  );

  static const VoiceConfig professionalFemale = VoiceConfig(
    language: "en-US",
    speechRate: 0.85,
    pitch: 1.0,
    voiceName: "en-US-Neural2-A", // Professional female voice
    audioEncoding: "MP3",
  );

  static const VoiceConfig warmFemale = VoiceConfig(
    language: "en-US",
    speechRate: 0.9,
    pitch: 1.1,
    voiceName: "en-US-Neural2-C", // Warm, friendly female voice
    audioEncoding: "MP3",
  );

  static const VoiceConfig energeticMale = VoiceConfig(
    language: "en-US",
    speechRate: 1.0,
    pitch: 0.9,
    voiceName: "en-US-Neural2-E", // Energetic male voice
    audioEncoding: "MP3",
  );

  /// Create a copy with some parameters changed
  VoiceConfig copyWith({
    String? language,
    double? speechRate,
    double? pitch,
    String? voiceName,
    String? audioEncoding,
  }) {
    return VoiceConfig(
      language: language ?? this.language,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      voiceName: voiceName ?? this.voiceName,
      audioEncoding: audioEncoding ?? this.audioEncoding,
    );
  }
}

/// Enhanced VoiceService with Google TTS and local TTS fallback
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  
  // Configuration
  VoiceConfig _config = const VoiceConfig();
  String? _googleApiKey;
  
  // State management
  bool _isPlaying = false;
  bool _isPaused = false;
  String? _currentText;
  bool _useBabyVoice = false; // Nathan is now a professional assistant
  
  // Getters
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  String? get currentText => _currentText;
  VoiceConfig get config => _config;
  bool get useBabyVoice => _useBabyVoice;

  /// Switch to a different voice personality
  Future<void> setVoicePersonality(VoiceConfig personality) async {
    _config = personality;
    if (kDebugMode) {
      print('🎤 Voice personality changed to: ${personality.voiceName}');
    }
  }

  /// Get available Neural2 voice personalities
  static List<Map<String, dynamic>> get availablePersonalities => [
    {
      'name': 'Professional Male',
      'description': 'Deep, authoritative voice perfect for business',
      'config': VoiceConfig.professionalMale,
    },
    {
      'name': 'Friendly Male', 
      'description': 'Warm, approachable voice for customer service',
      'config': VoiceConfig.friendlyMale,
    },
    {
      'name': 'Professional Female',
      'description': 'Clear, confident voice for presentations',
      'config': VoiceConfig.professionalFemale,
    },
    {
      'name': 'Warm Female',
      'description': 'Gentle, caring voice for support and guidance',
      'config': VoiceConfig.warmFemale,
    },
    {
      'name': 'Energetic Male',
      'description': 'Dynamic, enthusiastic voice for marketing',
      'config': VoiceConfig.energeticMale,
    },
  ];

  /// Initialize the service with optional Google API key
  Future<void> initialize({String? googleApiKey}) async {
    try {
      _googleApiKey = googleApiKey ?? ApiKeys.googleTtsKey;
      
      // Reset state
      _isPlaying = false;
      _isPaused = false;
      _currentText = null;
      
      // Configure local TTS with professional voice settings
      await _flutterTts.setLanguage(_config.language);
      await _flutterTts.setSpeechRate(_config.speechRate);
      await _flutterTts.setPitch(_config.pitch);
      await _flutterTts.awaitSpeakCompletion(true);
      
      // Set Nathan's professional voice
      await _setBabyNathanVoice();
      
      // Set up completion listener for local TTS
      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        _isPaused = false;
        _currentText = null;
        if (kDebugMode) {
          print('✅ Local TTS completed');
        }
      });

      // Set up error handler
      _flutterTts.setErrorHandler((msg) {
        _isPlaying = false;
        _isPaused = false;
        _currentText = null;
        if (kDebugMode) {
          print('❌ TTS Error: $msg');
        }
      });
      _flutterTts.setStartHandler(() {
        if (kDebugMode) {
          print('▶️ Local TTS started');
        }
      });

      // Test TTS availability
      final languages = await _flutterTts.getLanguages;
      if (languages.isEmpty) {
        throw Exception('No TTS languages available');
      }

      if (kDebugMode) {
        print('✅ VoiceService initialized successfully');
        print('🔊 Available languages: ${languages.length}');
        print('🔊 Google TTS available: $isGoogleTtsAvailable');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing VoiceService: $e');
      }
      // Don't rethrow - allow app to continue without voice
      _isPlaying = false;
      _isPaused = false;
      _currentText = null;
    }
  }

  /// Set Nathan voice with professional settings
  Future<void> _setBabyNathanVoice() async {
    // Nathan voice characteristics - deep male voice
    final maleVoices = [
      // Try deep male voice options
      {"name": "en-us-x-sfg#male_1-local", "locale": "en-US"}, // Deep male voice
      {"name": "en-us-x-sfg#male_2-local", "locale": "en-US"}, // Alternative male voice
      {"name": "en-us-x-sfg#male_3-local", "locale": "en-US"}, // Deep male voice
      {"name": "male", "locale": "en-US"},
      {"name": "man", "locale": "en-US"},
      {"name": "adult", "locale": "en-US"},
      {"name": "default", "locale": "en-US"},
    ];

    bool voiceSet = false;
    
    // Try deep male voice options
    for (final voice in maleVoices) {
      try {
        await _flutterTts.setVoice(voice);
        voiceSet = true;
        if (kDebugMode) {
          print('✅ Nathan voice set: ${voice["name"]}');
        }
        break;
      } catch (e) {
        // Continue to next voice option
        continue;
      }
    }
    
    // Set deep male voice characteristics
    await _flutterTts.setPitch(0.7); // Lower pitch for deep male voice
    await _flutterTts.setSpeechRate(0.8); // Slower for deeper male voice
  }

  /// Update voice configuration
  Future<void> updateConfig(VoiceConfig newConfig) async {
    _config = newConfig;
    
    // Update local TTS settings
    await _flutterTts.setLanguage(_config.language);
    await _flutterTts.setSpeechRate(_config.speechRate);
    await _flutterTts.setPitch(_config.pitch);
    
    // Set Nathan's professional voice
    await _setBabyNathanVoice();
    
    if (kDebugMode) {
      print('✅ Voice configuration updated');
    }
  }

  /// Main speak method
  Future<void> speak(String text, {bool preferGoogle = true}) async {
    if (text.trim().isEmpty) {
      if (kDebugMode) {
        print('⚠️ Empty text provided to speak');
      }
      return;
    }

    // Check if TTS is available
    if (!await _isTtsAvailable()) {
      if (kDebugMode) {
        print('❌ TTS not available - skipping speech');
      }
      return;
    }

    // Stop any current playback
    await stop();

    _currentText = text;
    _isPlaying = true;

    try {
      // Try Google WaveNet first for better voice quality
      if (preferGoogle && isGoogleTtsAvailable) {
        await _speakGoogleWaveNet(text);
      } else {
        // Fallback to local TTS with Nathan's voice
        await _flutterTts.stop();
        await _flutterTts.speak(text);
      }
      
      if (kDebugMode) {
        print('🎤 Nathan speaking: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in speak method: $e');
      }
      _isPlaying = false;
      _currentText = null;
      
      // Try to reinitialize if there's a connection error
      if (e.toString().contains('connection') || e.toString().contains('listening')) {
        if (kDebugMode) {
          print('🔄 Attempting to reinitialize TTS due to connection error');
        }
        await _reinitializeTts();
      }
    }
  }

  /// Check if TTS is available and working
  Future<bool> _isTtsAvailable() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('❌ TTS availability check failed: $e');
      }
      return false;
    }
  }

  /// Reinitialize TTS if there's a connection issue
  Future<void> _reinitializeTts() async {
    try {
      if (kDebugMode) {
        print('🔄 Reinitializing TTS...');
      }
      
      // Reset state
      _isPlaying = false;
      _isPaused = false;
      _currentText = null;
      
      // Reconfigure TTS
      await _flutterTts.setLanguage(_config.language);
      await _flutterTts.setSpeechRate(_config.speechRate);
      await _flutterTts.setPitch(_config.pitch);
      await _flutterTts.awaitSpeakCompletion(true);
      
      // Set up handlers again
      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        _isPaused = false;
        _currentText = null;
      });
      
      _flutterTts.setErrorHandler((msg) {
        _isPlaying = false;
        _isPaused = false;
        _currentText = null;
        if (kDebugMode) {
          print('❌ TTS Error after reinit: $msg');
        }
      });
      
      if (kDebugMode) {
        print('✅ TTS reinitialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to reinitialize TTS: $e');
      }
    }
  }

  /// Speak using Google Neural2 with ultra-realistic voice
  Future<void> _speakGoogleWaveNet(String text) async {
    try {
      final url = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_googleApiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "input": {"text": text},
          "voice": {
            "languageCode": _config.language,
            "name": _config.voiceName // Voice selection from config
          },
          "audioConfig": {
            "audioEncoding": _config.audioEncoding,
            "speakingRate": _config.speechRate, // Deep male speech rate
            "pitch": _config.pitch, // Deep male pitch
            "volumeGainDb": 0.0, // Normal volume
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioContent = base64Decode(data['audioContent']);
        
        // Play the audio using AudioPlayer
        await _player.play(BytesSource(Uint8List.fromList(audioContent)));
        
        if (kDebugMode) {
          print('✅ Google Neural2 TTS successful');
        }
      } else {
        if (kDebugMode) {
          print("❌ Google TTS failed: ${response.body}");
        }
        // Fallback to local TTS
        await _flutterTts.stop();
        await _flutterTts.speak(text);
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Google TTS error: $e");
      }
      // Fallback to local TTS
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    try {
      // Stop both local TTS and AudioPlayer
      await _flutterTts.stop();
      await _player.stop();
      
      _isPlaying = false;
      _isPaused = false;
      _currentText = null;
      
      if (kDebugMode) {
        print('⏹️ Voice playback stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error stopping voice playback: $e');
      }
    }
  }

  /// Pause current playback
  Future<void> pause() async {
    if (!_isPlaying) return;
    
    try {
      // Pause both local TTS and AudioPlayer
      await _flutterTts.pause();
      await _player.pause();
      
      _isPaused = true;
      
      if (kDebugMode) {
        print('⏸️ Voice playback paused');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error pausing voice playback: $e');
      }
    }
  }

  /// Resume paused playback
  Future<void> resume() async {
    if (!_isPaused) return;
    
    try {
      // Resume AudioPlayer if it was playing
      await _player.resume();
      
      // Note: FlutterTts doesn't support resume, so we restart from beginning
      if (_currentText != null) {
        await speak(_currentText!);
      }
      
      _isPaused = false;
      
      if (kDebugMode) {
        print('▶️ Voice playback resumed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error resuming voice playback: $e');
      }
    }
  }

  /// Check if Google TTS is available
  bool get isGoogleTtsAvailable {
    return _googleApiKey != null && _googleApiKey!.isNotEmpty;
  }

  /// Get voice service status
  Map<String, dynamic> getVoiceStatus() {
    return {
      'isPlaying': _isPlaying,
      'isPaused': _isPaused,
      'googleTtsAvailable': isGoogleTtsAvailable,
      'currentText': _currentText,
      'language': _config.language,
      'rate': _config.speechRate,
      'pitch': _config.pitch,
      'useBabyVoice': _useBabyVoice,
    };
  }

  /// Test different Google WaveNet voices to find the best voice
  Future<void> testBabyVoices() async {
    if (!isGoogleTtsAvailable) {
      if (kDebugMode) {
        print('❌ Google TTS not available for voice testing');
      }
      return;
    }

    final testText = "Hi! I'm Nathan, your shopping assistant!";
    final voices = [
      {"name": "en-US-Wavenet-A", "description": "Male voice"},
      {"name": "en-US-Wavenet-B", "description": "Male voice"},
      {"name": "en-US-Wavenet-C", "description": "Professional voice"},
      {"name": "en-US-Wavenet-D", "description": "Young voice"},
      {"name": "en-US-Wavenet-E", "description": "Female voice"},
      {"name": "en-US-Wavenet-F", "description": "Female voice"},
    ];

    for (final voice in voices) {
      if (kDebugMode) {
        print('🎤 Testing voice: ${voice["name"]} (${voice["description"]})');
      }
      
      try {
        final url = Uri.parse(
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_googleApiKey',
        );

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "input": {"text": testText},
            "voice": {
              "languageCode": "en-US",
              "name": voice["name"]
            },
            "audioConfig": {
              "audioEncoding": "MP3",
              "speakingRate": 0.8, // Deep male speech rate
              "pitch": 0.7, // Deep male pitch
            }
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final audioContent = base64Decode(data['audioContent']);
          
          // Play the audio
          await _player.play(BytesSource(Uint8List.fromList(audioContent)));
          
          // Wait for playback to complete
          await Future.delayed(const Duration(seconds: 3));
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error testing voice ${voice["name"]}: $e');
        }
      }
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _player.dispose();
      
      if (kDebugMode) {
        print('🧹 VoiceService disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error disposing VoiceService: $e');
      }
    }
  }
}
