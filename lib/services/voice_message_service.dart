import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;

class VoiceMessageService {
  static bool _isRecording = false;
  static bool _isPlaying = false;
  static String? _currentRecordingPath;
  static String? _currentPlayingUrl;
  static Timer? _durationTimer;
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Check if platform supports real audio recording
  static bool get _supportsRealRecording {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  // Initialize the service
  static Future<void> initialize() async {
    try {
      print('✅ Voice message service initialized successfully');
    } catch (e) {
      print('❌ Error initializing voice message service: $e');
    }
  }

  // Start recording voice message (simplified version for compatibility)
  static Future<String?> startRecording({
    required Function(int) onDurationUpdate,
  }) async {
    try {
      if (_isRecording) {
        print('⚠️ Already recording');
        return null;
      }

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('❌ Microphone permission denied');
        throw Exception('Microphone permission is required to record voice messages');
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/voice_message_$timestamp.m4a';

      // Create a placeholder file to simulate recording
      // In a production app, you would integrate a proper audio recording library
      final file = File(_currentRecordingPath!);
      await file.writeAsString('placeholder_audio_data');

      _isRecording = true;
      print('🎤 Started recording voice message to: $_currentRecordingPath');

      // Start duration timer
      _startDurationTimer(onDurationUpdate);

      return _currentRecordingPath;
    } catch (e) {
      print('❌ Error starting recording: $e');
      _isRecording = false;
      _durationTimer?.cancel();
      rethrow;
    }
  }

  // Stop recording
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('⚠️ Not currently recording');
        return null;
      }

      _isRecording = false;
      _durationTimer?.cancel();
      print('🎤 Stopped recording voice message: $_currentRecordingPath');

      return _currentRecordingPath;
    } catch (e) {
      print('❌ Error stopping recording: $e');
      _isRecording = false;
      _durationTimer?.cancel();
      return null;
    }
  }

  // Upload voice message to local storage (to avoid Firebase subscription requirements)
  static Future<String?> uploadVoiceMessage({
    required String localPath,
    required String chatId,
    required String senderId,
  }) async {
    const int maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        final file = File(localPath);
        if (!await file.exists()) {
          print('❌ Voice message file not found: $localPath');
          throw Exception('Voice message file not found');
        }

        // Check file size (max 10MB)
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('Voice message is too large (max 10MB)');
        }

        print('🔍 Starting voice message local storage... (attempt ${retryCount + 1}/$maxRetries)');

        // Get app documents directory for local storage
        final appDir = await getApplicationDocumentsDirectory();
        final voiceMessagesDir = Directory('${appDir.path}/voice_messages/$chatId');
        
        // Create directory if it doesn't exist
        if (!await voiceMessagesDir.exists()) {
          await voiceMessagesDir.create(recursive: true);
        }

        // Create unique filename
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        final destinationPath = '${voiceMessagesDir.path}/$fileName';
        final destinationFile = File(destinationPath);

        // Copy file to local storage
        await file.copy(destinationPath);

        // Verify file was copied successfully
        if (await destinationFile.exists()) {
          print('✅ Voice message stored locally: $destinationPath');
          
          // Clean up original file
          await file.delete();
          
          // Return local file path for playback
          return destinationPath;
        } else {
          print('❌ Voice message storage failed - file not found at destination');
          throw Exception('Failed to store voice message locally');
        }
      } catch (e) {
        retryCount++;
        print('❌ Error storing voice message (attempt $retryCount/$maxRetries): $e');
        
        // If this is the last attempt, provide specific error message
        if (retryCount >= maxRetries) {
          String errorMessage = 'Failed to store voice message after $maxRetries attempts';
          if (e.toString().contains('permission')) {
            errorMessage = 'Permission denied. Please check your storage permissions.';
          } else if (e.toString().contains('space') || e.toString().contains('disk')) {
            errorMessage = 'Insufficient storage space. Please free up some space and try again.';
          } else if (e.toString().contains('file')) {
            errorMessage = 'File system error. Please try again.';
          }
          
          throw Exception(errorMessage);
        }
        
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
    
    throw Exception('Failed to store voice message after $maxRetries attempts');
  }

  // Play voice message from local file path
  static Future<void> playVoiceMessage({
    required String filePath,
    required VoidCallback onPlay,
    required VoidCallback onStop,
    required VoidCallback onComplete,
  }) async {
    try {
      print('🔍 Playing voice message: $filePath');
      
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ Voice message file not found: $filePath');
        throw Exception('Voice message file not found');
      }

      // Stop any currently playing audio
      await _audioPlayer.stop();
      
      // Set up audio player
      await _audioPlayer.setSource(DeviceFileSource(filePath));
      
      // Set up completion listener
      _audioPlayer.onPlayerComplete.listen((_) {
        print('✅ Voice message playback completed');
        onComplete();
      });

      // Start playing
      await _audioPlayer.resume();
      onPlay();
      
      print('✅ Voice message playback started');
    } catch (e) {
      print('❌ Error playing voice message: $e');
      rethrow;
    }
  }

  // Stop playing
  static Future<void> stopPlaying() async {
    try {
      if (!_isPlaying) return;

      await _audioPlayer.stop();
      _isPlaying = false;
      _currentPlayingUrl = null;
      print('🔊 Stopped playing voice message');
    } catch (e) {
      print('❌ Error stopping playback: $e');
    }
  }

  // Check if currently recording
  static bool get isRecording => _isRecording;

  // Check if currently playing
  static bool get isPlaying => _isPlaying;

  // Get current playing URL
  static String? get currentPlayingUrl => _currentPlayingUrl;

  // Check if platform supports real recording
  static bool get supportsRealRecording => _supportsRealRecording;

  // Get recording duration
  static Future<int> getRecordingDuration() async {
    // For now, return 0 as we're using a simplified approach
    return 0;
  }

  // Format duration as MM:SS
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Start duration timer for recording
  static void _startDurationTimer(Function(int) onDurationUpdate) {
    int duration = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      duration++;
      onDurationUpdate(duration);
    });
  }

  // Dispose resources
  static Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      if (_isPlaying) {
        await stopPlaying();
      }
      _durationTimer?.cancel();
      await _audioPlayer.dispose();
      print('✅ Voice message service disposed');
    } catch (e) {
      print('❌ Error disposing voice message service: $e');
    }
  }
} 