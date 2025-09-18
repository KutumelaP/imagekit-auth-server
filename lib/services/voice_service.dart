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
    this.speechRate = 0.6, // Slower for baby speech
    this.pitch = 1.8, // Very high pitch for baby voice
    this.voiceName = "en-US-Wavenet-B", // Male voice for Nathan
    this.audioEncoding = "MP3",
  });

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
  bool _useBabyVoice = true; // Nathan is always baby voice!
  
  // Getters
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  String? get currentText => _currentText;
  VoiceConfig get config => _config;
  bool get useBabyVoice => _useBabyVoice;

  /// Initialize the service with optional Google API key
  Future<void> initialize({String? googleApiKey}) async {
    try {
      _googleApiKey = googleApiKey ?? ApiKeys.googleTtsKey;
      
      // Configure local TTS with baby voice settings
      await _flutterTts.setLanguage(_config.language);
      await _flutterTts.setSpeechRate(_config.speechRate);
      await _flutterTts.setPitch(_config.pitch);
      
      // Set Nathan's adorable baby voice
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

      if (kDebugMode) {
        print('✅ VoiceService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing VoiceService: $e');
      }
      rethrow;
    }
  }

  /// Set baby Nathan voice with cute, high-pitched settings
  Future<void> _setBabyNathanVoice() async {
    // Baby Nathan voice characteristics - male voice with very high pitch, slower speech
    final babyVoices = [
      // Try male child/baby voice options
      {"name": "en-us-x-sfg#male_1-local", "locale": "en-US"}, // Young male voice
      {"name": "child", "locale": "en-US"},
      {"name": "baby", "locale": "en-US"},
      {"name": "nathan", "locale": "en-US"},
      {"name": "boy", "locale": "en-US"},
    ];

    bool voiceSet = false;
    
    // Try baby/child voice options
    for (final voice in babyVoices) {
      try {
        await _flutterTts.setVoice(voice);
        voiceSet = true;
        if (kDebugMode) {
          print('✅ Baby Nathan voice set: ${voice["name"]}');
        }
        break;
      } catch (e) {
        // Continue to next voice option
        continue;
      }
    }
    
    // Set baby voice characteristics
    await _flutterTts.setPitch(1.8); // Very high pitch for baby voice
    await _flutterTts.setSpeechRate(0.6); // Slower speech like a baby
  }

  /// Update voice configuration
  Future<void> updateConfig(VoiceConfig newConfig) async {
    _config = newConfig;
    
    // Update local TTS settings
    await _flutterTts.setLanguage(_config.language);
    await _flutterTts.setSpeechRate(_config.speechRate);
    await _flutterTts.setPitch(_config.pitch);
    
    // Set Nathan's baby voice
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

    // Stop any current playback
    await stop();

    _currentText = text;
    _isPlaying = true;

    try {
      // Use local TTS with Nathan's baby voice
      await _flutterTts.speak(text);
      
      if (kDebugMode) {
        print('🎤 Nathan speaking: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in speak method: $e');
      }
      _isPlaying = false;
      _currentText = null;
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      
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
      await _flutterTts.pause();
      
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
