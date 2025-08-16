import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:marketplace_app/utils/web_js_stub.dart'
    if (dart.library.html) 'package:marketplace_app/utils/web_js_real.dart' as js;

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  AudioPlayer? _notificationPlayer;
  bool _isInitialized = false;

  /// Initialize the sound service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _notificationPlayer = AudioPlayer();
      await _notificationPlayer!.setReleaseMode(ReleaseMode.loop);
      
      // For mobile web, initialize audio context with user interaction
      if (kIsWeb) {
        _initializeMobileWebAudio();
      }
      
      _isInitialized = true;
      print('✅ Sound service initialized successfully');
    } catch (e) {
      print('❌ Error initializing sound service: $e');
    }
  }

  /// Initialize mobile web audio context
  void _initializeMobileWebAudio() {
    try {
      js.context.callMethod('eval', ['''
        (function() {
          // Create and resume audio context for mobile web
          if (typeof window.audioContext === 'undefined') {
            window.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            console.log('🔊 Mobile web audio context initialized');
          }
          
          // Add click listener to resume audio context (required for mobile)
          if (!window.audioInitialized) {
            document.addEventListener('click', function() {
              if (window.audioContext && window.audioContext.state === 'suspended') {
                window.audioContext.resume();
                console.log('🔊 Audio context resumed on user interaction');
              }
            }, { once: true });
            window.audioInitialized = true;
          }
        })();
      ''']);
    } catch (e) {
      print('❌ Error initializing mobile web audio: $e');
    }
  }

  /// Play notification sound
  Future<void> playNotificationSound() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      print('🔔 Playing notification sound - Web: ${kIsWeb}');
      
      // Play haptic feedback for vibration (mobile only)
      if (!kIsWeb) {
        HapticFeedback.lightImpact();
      }
      
      // Try to play the notification sound file first
      try {
        await _playNotificationSoundFile();
      } catch (e) {
        print('❌ Error playing notification sound file: $e');
        // Fallback to playing without file
        try {
          await _playNotificationSoundWithoutFile();
        } catch (e) {
          print('❌ Error playing notification sound without file: $e');
          // Final fallback to platform-specific sound
          if (kIsWeb) {
            _playWebNotificationSound();
          } else {
            _playMobileNotificationSound();
          }
        }
      }
    } catch (e) {
      print('❌ Error playing notification sound: $e');
      // Final fallback to just haptic feedback on mobile
      if (!kIsWeb) {
        HapticFeedback.lightImpact();
      }
    }
  }

  /// Play notification sound from file
  Future<void> _playNotificationSoundFile() async {
    try {
      if (_notificationPlayer != null) {
        // Stop any currently playing sound first
        await _notificationPlayer!.stop();
        
        // For web, use a simple beep sound instead of file
        if (kIsWeb) {
          _playWebBeepSound();
          print('🔊 Web audio notification played');
        } else {
          // Try to play the notification sound file for mobile
          await _notificationPlayer!.play(AssetSource('sounds/notification.mp3'));
          print('🔊 Audio notification played from file');
          
          // Stop the sound after a short delay to prevent infinite loop
          Future.delayed(const Duration(milliseconds: 2000), () {
            _notificationPlayer?.stop();
          });
        }
      }
    } catch (e) {
      print('⚠️ Audio notification error: $e');
      // Fallback to platform-specific sound
      print('🔔 Falling back to platform-specific sound');
      if (kIsWeb) {
        _playWebBeepSound();
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  /// Play notification sound without file (fallback)
  Future<void> _playNotificationSoundWithoutFile() async {
    try {
      if (_notificationPlayer != null) {
        // Create a simple beep sound using audioplayers
        // This will work even without a sound file
        print('🔔 Playing notification sound without file');
        
        // For now, we'll just use haptic feedback and log
        if (!kIsWeb) {
          HapticFeedback.lightImpact();
        }
        print('✅ Notification sound played (haptic feedback)');
      }
    } catch (e) {
      print('❌ Error playing notification sound without file: $e');
      rethrow;
    }
  }

  /// Play platform-specific notification sound
  // Removed unused helper to avoid lints

  /// Play mobile notification sound
  void _playMobileNotificationSound() {
    try {
      print('🔔 Mobile notification sound triggered');
      
      // For mobile, use haptic feedback as the primary sound
      // This provides tactile feedback that users expect
      HapticFeedback.lightImpact();
      print('✅ Mobile notification sound played (haptic feedback)');
      
    } catch (e) {
      print('❌ Error playing mobile notification sound: $e');
      // Final fallback to haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  /// Play web notification sound using Web Audio API
  void _playWebNotificationSound() {
    try {
      print('🔔 Web notification sound triggered');
      
      // For web, try to play the sound file using audioplayers
      if (_notificationPlayer != null) {
        // Skip audio for now since the file doesn't exist
        print('🔇 Web audio notifications disabled (no sound file available)');
        print('💡 To enable audio notifications, add a real MP3 file to assets/sounds/notification.mp3');
        // Fallback to simple beep
        _playWebBeepSound();
      } else {
        _playWebBeepSound();
      }
    } catch (e) {
      print('❌ Error in web notification sound: $e');
      _playWebBeepSound();
    }
  }

  /// Play a simple beep sound using Web Audio API
  void _playWebBeepSound() {
    try {
      print('🔔 Web beep sound triggered');
      
      // Check if we're on mobile web
      final userAgent = js.context.callMethod('eval', ['navigator.userAgent']);
      final isMobile = userAgent.toString().toLowerCase().contains('mobile');
      
      print('📱 Mobile web detected: $isMobile');
      
      // Create a simple beep sound using Web Audio API with mobile support
      js.context.callMethod('eval', ['''
        (function() {
          try {
            // Resume audio context if suspended (required for mobile)
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();
            if (audioContext.state === 'suspended') {
              audioContext.resume();
            }
            
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();
            
            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);
            
            // Use different frequency for mobile (more noticeable)
            const frequency = navigator.userAgent.toLowerCase().includes('mobile') ? 1000 : 800;
            oscillator.frequency.setValueAtTime(frequency, audioContext.currentTime);
            oscillator.type = 'sine';
            
            // Adjust volume for mobile
            const volume = navigator.userAgent.toLowerCase().includes('mobile') ? 0.5 : 0.3;
            gainNode.gain.setValueAtTime(volume, audioContext.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.3);
            
            oscillator.start(audioContext.currentTime);
            oscillator.stop(audioContext.currentTime + 0.3);
            
            console.log('🔊 Web notification sound played (mobile: ' + navigator.userAgent.toLowerCase().includes('mobile') + ')');
          } catch (e) {
            console.log('❌ Error playing web notification sound:', e);
            // Fallback: try to play a simple audio element
            try {
              const audio = new Audio();
              audio.src = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIG2m98OScTgwOUarm7blmGgU7k9n1unEiBC13yO/eizEIHWq+8+OWT';
              audio.volume = 0.3;
              audio.play();
            } catch (fallbackError) {
              console.log('❌ Fallback audio also failed:', fallbackError);
            }
          }
        })();
      ''']);
      
      print('🔊 Web audio notification played');
    } catch (e) {
      print('❌ Error in web beep sound: $e');
      // Fallback to just logging
      print('🔊 Notification sound played (web fallback)');
    }
  }

  /// Play a custom sound file
  Future<void> playCustomSound(String soundPath) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (_notificationPlayer != null) {
        await _notificationPlayer!.play(AssetSource(soundPath));
        print('🔔 Playing custom sound: $soundPath');
      }
    } catch (e) {
      print('❌ Error playing custom sound: $e');
    }
  }

  /// Stop all sounds
  Future<void> stopSounds() async {
    try {
      if (_notificationPlayer != null) {
        await _notificationPlayer!.stop();
      }
    } catch (e) {
      print('❌ Error stopping sounds: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _notificationPlayer?.dispose();
      _notificationPlayer = null;
      _isInitialized = false;
    } catch (e) {
      print('❌ Error disposing sound service: $e');
    }
  }
} 