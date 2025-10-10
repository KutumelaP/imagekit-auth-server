import 'dart:convert';
import 'dart:math';
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
    this.speechRate = 1.0, // Normal human speech rate
    this.pitch = 0.8, // Lower pitch for deeper male voice
    this.voiceName = "en-US-Wavenet-D", // Deep male voice
    this.audioEncoding = "MP3",
  });

  /// Predefined Wavenet voice configurations for different personalities
  static const VoiceConfig professionalMale = VoiceConfig(
    language: "en-US",
    speechRate: 1.0, // Normal human speech rate
    pitch: 0.8, // Lower pitch for deeper male voice
    voiceName: "en-US-Wavenet-D", // Deep professional male voice
    audioEncoding: "MP3",
  );

  static const VoiceConfig friendlyMale = VoiceConfig(
    language: "en-US", 
    speechRate: 1.0, // Normal human speech rate
    pitch: 1.0, // Natural pitch
    voiceName: "en-US-Wavenet-C", // Natural friendly voice
    audioEncoding: "MP3",
  );

  static const VoiceConfig professionalFemale = VoiceConfig(
    language: "en-US",
    speechRate: 1.0, // Normal human speech rate
    pitch: 1.0, // Natural pitch
    voiceName: "en-US-Wavenet-A", // Professional female voice
    audioEncoding: "MP3",
  );

  static const VoiceConfig warmFemale = VoiceConfig(
    language: "en-US",
    speechRate: 1.0, // Normal human speech rate
    pitch: 1.1, // Slightly higher pitch for warmth
    voiceName: "en-US-Wavenet-E", // Warm, friendly female voice
    audioEncoding: "MP3",
  );

  static const VoiceConfig energeticMale = VoiceConfig(
    language: "en-US",
    speechRate: 1.0, // Normal human speech rate
    pitch: 1.0, // Natural pitch
    voiceName: "en-US-Wavenet-B", // Energetic male voice
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

  // Verbose diagnostic logging toggle (shows in release too)
  static bool debugLogging = true;
  void _log(String message) {
    if (debugLogging) {
      // Keep simple print so it shows in web console (Safari/Chrome)
      // ignore: avoid_print
      print(message);
    }
  }

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
  static bool _webAudioPrimed = false;
  
  // API usage tracking
  int _googleTtsRequests = 0;
  int _googleTtsFailures = 0;
  DateTime? _lastGoogleTtsRequest;
  
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

  /// Prime/unlock web audio on iOS Safari by speaking a zero-volume blip on user gesture
  Future<void> primePlaybackIfNeeded() async {
    if (!kIsWeb || _webAudioPrimed) return;
    try {
      _log('🔓 Attempting to prime web audio...');
      // Use local TTS with zero volume for a very short utterance to unlock playback
      await _flutterTts.setVolume(0.0);
      await _flutterTts.speak(' '); // minimal utterance
      await Future.delayed(const Duration(milliseconds: 50));
      await _flutterTts.stop();
      await _flutterTts.setVolume(0.8);
      _webAudioPrimed = true;
      _log('🔓 Web audio primed');
    } catch (e) {
      _log('⚠️ Failed to prime web audio: $e');
    }
  }

  /// Get available Wavenet voice personalities
  static List<Map<String, dynamic>> get availablePersonalities => [
    {
      'name': 'Professional Male',
      'description': 'Natural, professional voice perfect for business',
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
      // We now use server proxy; no client key needed on web. Keep key for mobile fallback.
      _googleApiKey = googleApiKey ?? ApiKeys.googleTtsKey;
      _log('🔧 VoiceService.init → isWeb=$kIsWeb, using proxy=true, googleKeySetForMobile=${_googleApiKey != null && _googleApiKey!.isNotEmpty}');
      
      // Force update voice configuration to normal human speech rate
      _config = const VoiceConfig(
        language: "en-US",
        speechRate: 1.0, // Normal human speech rate for Google TTS
        pitch: 0.8, // Lower pitch for deeper male voice
        voiceName: "en-US-Wavenet-D", // Deep male voice
        audioEncoding: "MP3",
      );
      
      if (kDebugMode) {
        print('🎤 Voice config forced to: speechRate=${_config.speechRate}, pitch=${_config.pitch}');
      }
      
      // Reset state
      _isPlaying = false;
      _isPaused = false;
      _currentText = null;
      
      // Configure local TTS with professional voice settings
      await _flutterTts.setLanguage(_config.language);
      await _flutterTts.setSpeechRate(_config.speechRate);
      await _flutterTts.setPitch(_config.pitch);
      // Safari/Web can hang when awaiting completion; don't await on web
      await _flutterTts.awaitSpeakCompletion(kIsWeb ? false : true);
      
      // Set Nathan's professional voice
      await _setBabyNathanVoice();
      
      // Set up completion listener for local TTS
      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        _isPaused = false;
        _currentText = null;
        _log('✅ Local TTS completed');
      });

      // Set up error handler
      _flutterTts.setErrorHandler((msg) {
        _isPlaying = false;
        _isPaused = false;
        _currentText = null;
        _log('❌ TTS Error: $msg');
      });
      _flutterTts.setStartHandler(() {
        _log('▶️ Local TTS started');
      });

      // AudioPlayer diagnostics
      _player.onPlayerStateChanged.listen((state) {
        _log('🎧 AudioPlayer state: $state');
      });
      _player.onDurationChanged.listen((d) {
        _log('⏱️ Audio duration: ${d.inMilliseconds}ms');
      });
      _player.onPositionChanged.listen((p) {
        _log('➡️ Audio position: ${p.inMilliseconds}ms');
      });

      // Test TTS availability
      final languages = await _flutterTts.getLanguages;
      if (languages.isEmpty) {
        throw Exception('No TTS languages available');
      }

      _log('✅ VoiceService initialized successfully');
      _log('🔊 Google TTS available: $isGoogleTtsAvailable');
      _log('🔊 Voice config: ${_config.voiceName}');
    } catch (e) {
      _log('❌ Error initializing VoiceService: $e');
      // Don't rethrow - allow app to continue without voice
      _isPlaying = false;
      _isPaused = false;
      _currentText = null;
    }
  }

  /// Set Nathan voice with natural, device-appropriate settings
  Future<void> _setBabyNathanVoice() async {
    try {
      // Get available voices from the device
      final voices = await _flutterTts.getVoices;
      
      if (voices != null && voices.isNotEmpty) {
        // Look for a good English voice
        Map<String, String>? selectedVoice;
        
        // Priority order: Male English voices, then any English voice, then default
        for (final voice in voices) {
          try {
            final voiceMap = Map<String, String>.from(voice as Map);
            final name = voiceMap['name']?.toLowerCase() ?? '';
            final locale = voiceMap['locale']?.toLowerCase() ?? '';
            
            // Look for English male voices first
            if (locale.startsWith('en') && (name.contains('male') || name.contains('man'))) {
              selectedVoice = voiceMap;
              break;
            }
          } catch (e) {
            // Skip invalid voice entries
            continue;
          }
        }
        
        // If no male voice found, look for any English voice
        if (selectedVoice == null) {
          for (final voice in voices) {
            try {
              final voiceMap = Map<String, String>.from(voice as Map);
              final locale = voiceMap['locale']?.toLowerCase() ?? '';
              
              if (locale.startsWith('en')) {
                selectedVoice = voiceMap;
                break;
              }
            } catch (e) {
              // Skip invalid voice entries
              continue;
            }
          }
        }
        
        // Set the selected voice
        if (selectedVoice != null) {
          await _flutterTts.setVoice(selectedVoice);
          if (kDebugMode) {
            print('✅ Nathan voice set: ${selectedVoice["name"]} (${selectedVoice["locale"]})');
          }
        }
      }
      
      // Set natural, human-like voice characteristics
      await _flutterTts.setPitch(0.7); // Deeper pitch for male voice
      await _flutterTts.setSpeechRate(0.7); // Faster, more natural conversation pace
      await _flutterTts.setVolume(0.8); // Slightly softer volume
      
      // Try to set additional natural speech parameters if available
      try {
        // Some TTS engines support these for more natural speech
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.awaitSpeakCompletion(true);
      } catch (e) {
        // Ignore if not supported
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error setting voice: $e - using defaults');
      }
      // Fallback to natural settings
      await _flutterTts.setPitch(0.9);
      await _flutterTts.setSpeechRate(0.7);
      await _flutterTts.setVolume(0.8);
    }
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
      print('✅ Voice configuration updated to: ${_config.voiceName}');
    }
  }

  /// Force reset voice configuration to 1.0 speech rate
  Future<void> forceResetToNormalSpeed() async {
    _config = const VoiceConfig(
      language: "en-US",
      speechRate: 1.0, // Normal human speech rate
      pitch: 0.8, // Lower pitch for deeper male voice
      voiceName: "en-US-Wavenet-D", // Deep male voice
      audioEncoding: "MP3",
    );
    
    // Update local TTS settings
    await _flutterTts.setLanguage(_config.language);
    await _flutterTts.setSpeechRate(_config.speechRate);
    await _flutterTts.setPitch(_config.pitch);
    
    if (kDebugMode) {
      print('🎤 Voice config FORCE RESET to: speechRate=${_config.speechRate}, pitch=${_config.pitch}');
    }
  }

  /// Enhance text for more natural speech
  String _enhanceTextForSpeech(String text) {
    // Add natural pauses and improve pronunciation
    String enhanced = text;
    
    // Add longer pauses after sentences for more natural flow
    enhanced = enhanced.replaceAll('.', '.  '); // Double space for longer pause
    enhanced = enhanced.replaceAll('!', '!  ');
    enhanced = enhanced.replaceAll('?', '?  ');
    
    // Add natural pauses after commas and conjunctions
    enhanced = enhanced.replaceAll(',', ',  '); // Longer comma pause
    enhanced = enhanced.replaceAll(' but ', ' but,  '); // Pause before 'but'
    enhanced = enhanced.replaceAll(' and ', ' and,  '); // Pause before 'and'
    enhanced = enhanced.replaceAll(' or ', ' or,  '); // Pause before 'or'
    enhanced = enhanced.replaceAll(' so ', ' so,  '); // Pause before 'so'
    
    // Improve common app-related pronunciations
    enhanced = enhanced.replaceAll('OmniaSA', 'Omnia S A');
    enhanced = enhanced.replaceAll('app', 'app ');
    enhanced = enhanced.replaceAll('TTS', 'text to speech');
    enhanced = enhanced.replaceAll('AI', 'A I');
    enhanced = enhanced.replaceAll('vs', 'versus');
    enhanced = enhanced.replaceAll('&', 'and');
    enhanced = enhanced.replaceAll('website', 'web site');
    
    // Add breathing pauses for longer sentences
    if (enhanced.length > 50) {
      // Add pause in the middle of long sentences
      final words = enhanced.split(' ');
      if (words.length > 8) {
        final midPoint = words.length ~/ 2;
        words.insert(midPoint, ' ');
      }
      enhanced = words.join(' ');
    }
    
    // Remove extra spaces but keep intentional double spaces
    enhanced = enhanced.replaceAll(RegExp(r' {3,}'), '  ').trim();
    
    return enhanced;
  }


  /// Main speak method
  Future<void> speak(String text, {bool preferGoogle = true}) async {
    final startTime = DateTime.now();
    
    if (text.trim().isEmpty) {
      _log('⚠️ Empty text provided to speak');
      return;
    }

    // Check if TTS is available
    if (!await _isTtsAvailable()) {
      _log('❌ TTS not available - skipping speech');
      return;
    }

    // Stop any current playback
    await stop();

    _currentText = text;
    _isPlaying = true;

    try {
      _log('🎤 ===== TTS REQUEST START =====');
      _log('🎤 Text: ${text.substring(0, min(text.length, 100))}...');
      _log('🎤 Text Length: ${text.length}');
      _log('🎤 Prefer Google: $preferGoogle | GoogleAvail: $isGoogleTtsAvailable | isWeb: $kIsWeb');
      _log('🎤 Voice: ${_config.voiceName} | rate=${_config.speechRate} | pitch=${_config.pitch}');
      _log('🎤 Timestamp: ${startTime.toIso8601String()}');

      // Try Google WaveNet first for better voice quality when supported (including web)
      final bool useGoogle = preferGoogle && isGoogleTtsAvailable;
      if (useGoogle) {
        _log('🎤 Using Google TTS with voice: ${_config.voiceName}');
        await _speakGoogleWaveNet(text);
      } else {
        _log('🎤 Using Flutter TTS (preferGoogle=$preferGoogle, googleAvail=$isGoogleTtsAvailable)');
        // Fallback to local TTS with Nathan's voice
        await _flutterTts.stop();
        final enhancedText = _enhanceTextForSpeech(text);
        _log('🎤 Enhanced text (local TTS): ${enhancedText.substring(0, min(enhancedText.length, 100))}...');
        await _flutterTts.speak(enhancedText);
      }
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      _log('🎤 Nathan speaking: ${text.substring(0, text.length > 60 ? 60 : text.length)}...');
      _log('🎤 TTS Processing Time: ${duration}ms');
      _log('🎤 ===== TTS REQUEST END =====');
    } catch (e) {
      _log('❌ Error in speak method: $e');
      _isPlaying = false;
      _currentText = null;
      
      // Try to reinitialize if there's a connection error
      if (e.toString().contains('connection') || e.toString().contains('listening')) {
        _log('🔄 Attempting to reinitialize TTS due to connection error');
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
      _log('🔄 Reinitializing TTS...');
      
      // Reset state
      _isPlaying = false;
      _isPaused = false;
      _currentText = null;
      
      // Reconfigure TTS
      await _flutterTts.setLanguage(_config.language);
      await _flutterTts.setSpeechRate(_config.speechRate);
      await _flutterTts.setPitch(_config.pitch);
      await _flutterTts.awaitSpeakCompletion(kIsWeb ? false : true);
      
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
      
      _log('✅ TTS reinitialized successfully');
    } catch (e) {
      _log('❌ Failed to reinitialize TTS: $e');
    }
  }

  /// Speak using Google Neural2 with ultra-realistic voice
  Future<void> _speakGoogleWaveNet(String text) async {
    final startTime = DateTime.now();
    try {
      // Track API usage
      _googleTtsRequests++;
      _lastGoogleTtsRequest = DateTime.now();
      
      _log('🎤 ===== GOOGLE TTS REQUEST START =====');
      _log('🎤 Voice: ${_config.voiceName} | rate=${_config.speechRate} | pitch=${_config.pitch}');
      _log('🎤 Text Length: ${text.length} | KeySet=${_googleApiKey != null && _googleApiKey!.isNotEmpty}');
      _log('🎤 Google TTS requests: $_googleTtsRequests | ${startTime.toIso8601String()}');

      // Use Cloud Functions HTTP proxy (CORS-enabled)
      final url = Uri.parse(
        'https://us-central1-marketplace-8d6bd.cloudfunctions.net/googleTtsSynthesizeHttp',
      );

      final requestBody = {
        "input": {"text": text},
        "voice": {
          "languageCode": "en-US", // Always use en-US for Google TTS
          "name": _config.voiceName
        },
        "audioConfig": {
          "audioEncoding": "MP3",
          "speakingRate": _config.speechRate,
          "pitch": _config.pitch,
          "volumeGainDb": 0.0,
        }
      };

      _log('🎤 Google TTS Request Body (trunc): ${jsonEncode(requestBody).substring(0, 200)}...');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      _log('🎤 Google TTS Response Status: ${response.statusCode} in ${duration}ms (len=${response.body.length})');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioContent = base64Decode(data['audioContent']);
        
        _log('🎤 Google TTS Success - Audio bytes: ${audioContent.length}');
        
        // Play the audio using AudioPlayer
        try {
          if (kIsWeb) {
            // Web path: try BytesSource first (plugin builds a Blob under the hood), then data URL fallback
            try {
              _log('🎤 Playing web audio via BytesSource');
              await _player.play(BytesSource(Uint8List.fromList(audioContent)));
            } catch (e) {
              _log('⚠️ Web BytesSource failed: $e');
              final base64Audio = data['audioContent'];
              final audioUrl = 'data:audio/mp3;base64,$base64Audio';
              try {
                _log('🎤 Playing web audio via data URL');
                await _player.play(UrlSource(audioUrl));
              } catch (e2) {
                _log('⚠️ Web data URL blocked: $e2 → prime+retry');
                await primePlaybackIfNeeded();
                await Future.delayed(const Duration(milliseconds: 60));
                await _player.play(UrlSource(audioUrl));
              }
            }
          } else {
            // For mobile, use BytesSource
            _log('🎤 Playing mobile audio via BytesSource');
            await _player.play(BytesSource(Uint8List.fromList(audioContent)));
          }
          
          _log('✅ Google TTS playback started | voice=${_config.voiceName}');
          _log('🎤 ===== GOOGLE TTS REQUEST END =====');
        } catch (playError) {
          _log('❌ Audio playback error: $playError');
          _log('🔄 Falling back to Flutter TTS due to audio playback issue');
          // Fallback to Flutter TTS if audio playback fails
          await _flutterTts.stop();
          final enhancedText = _enhanceTextForSpeech(text);
          await _flutterTts.speak(enhancedText);
        }
      } else {
        // Handle different error types
        final errorBody = response.body;
        _log("❌ Google TTS failed: ${response.statusCode} → ${errorBody.substring(0, errorBody.length > 240 ? 240 : errorBody.length)}...");
        
        // Track failures
        _googleTtsFailures++;
        
        // Check for specific error types
        if (response.statusCode == 429) {
          if (kDebugMode) {
            print('⚠️ Google TTS quota exceeded - falling back to local TTS');
            print('⚠️ Total Google TTS requests: $_googleTtsRequests, Failures: $_googleTtsFailures');
          }
        } else if (response.statusCode == 403) {
          if (kDebugMode) {
            print('⚠️ Google TTS API key invalid or disabled - falling back to local TTS');
          }
        } else if (response.statusCode == 400) {
          if (kDebugMode) {
            print('⚠️ Google TTS bad request - falling back to local TTS');
          }
        }
        
        // Fallback to local TTS
        _log('🔄 Falling back to local TTS due to Google TTS error');
        await _flutterTts.stop();
        final enhancedText = _enhanceTextForSpeech(text);
        await _flutterTts.speak(enhancedText);
        
        _log('🎤 ===== GOOGLE TTS REQUEST END =====');
      }
    } catch (e) {
      _log("❌ Google TTS error: $e");
      _log('🔄 Falling back to local TTS due to exception');
      // Fallback to local TTS
      await _flutterTts.stop();
      final enhancedText = _enhanceTextForSpeech(text);
      await _flutterTts.speak(enhancedText);
      
      _log('🎤 ===== GOOGLE TTS REQUEST END =====');
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
    // With proxy, treat as available on all platforms
    return true;
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
      'googleTtsRequests': _googleTtsRequests,
      'googleTtsFailures': _googleTtsFailures,
      'lastGoogleTtsRequest': _lastGoogleTtsRequest?.toIso8601String(),
    };
  }

  /// Get API usage statistics
  Map<String, dynamic> getApiUsageStats() {
    final successRate = _googleTtsRequests > 0 
        ? ((_googleTtsRequests - _googleTtsFailures) / _googleTtsRequests * 100).toStringAsFixed(1)
        : '0.0';
    
    return {
      'totalRequests': _googleTtsRequests,
      'totalFailures': _googleTtsFailures,
      'successRate': '$successRate%',
      'lastRequest': _lastGoogleTtsRequest?.toIso8601String(),
      'isQuotaExceeded': _googleTtsFailures > 0 && _googleTtsRequests > 10,
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

  /// Test Google TTS directly (for debugging)
  Future<void> testGoogleTts(String text) async {
    if (kDebugMode) {
      print('🧪 Testing Google TTS directly...');
      print('🧪 API Key: ${_googleApiKey?.substring(0, 10)}...');
      print('🧪 Voice: ${_config.voiceName}');
    }
    
    try {
      await _speakGoogleWaveNet(text);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Google TTS test failed: $e');
      }
    }
  }

  /// Force Google TTS usage (bypass availability check)
  Future<void> forceGoogleTts(String text) async {
    if (text.trim().isEmpty) return;
    
    await stop();
    _currentText = text;
    _isPlaying = true;
    
    try {
      if (kDebugMode) {
        print('🎤 Force using Google TTS with voice: ${_config.voiceName}');
      }
      await _speakGoogleWaveNet(text);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Force Google TTS failed: $e');
      }
      _isPlaying = false;
      _currentText = null;
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
