import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Only import js_util on web platform
import 'dart:js_util' as js_util;
import 'dart:typed_data';

/// Web audio recorder for capturing audio in browsers
/// Specifically designed to work with iOS Safari and other web browsers
class WebAudioRecorder {
  static const int _maxRecordingDuration = 30; // seconds
  static const int _sampleRate = 16000; // Optimal for speech recognition
  
  Completer<String>? _recordingCompleter;
  dynamic _mediaRecorder;
  dynamic _stream;
  List<dynamic> _audioChunks = [];
  Timer? _maxDurationTimer;

  /// Check if audio recording is supported in the current browser
  static Future<bool> isSupported() async {
    if (!kIsWeb) return false;
    
    try {
      final navigator = js_util.getProperty(js_util.globalThis, 'navigator');
      final mediaDevices = js_util.getProperty(navigator, 'mediaDevices');
      return js_util.hasProperty(mediaDevices, 'getUserMedia');
    } catch (e) {
      return false;
    }
  }

  /// Start recording audio from the microphone
  Future<String> startRecording() async {
    if (_recordingCompleter != null) {
      throw StateError('Recording already in progress');
    }

    try {
      _recordingCompleter = Completer<String>();
      _audioChunks.clear();

      // Request microphone access
      final navigator = js_util.getProperty(js_util.globalThis, 'navigator');
      final mediaDevices = js_util.getProperty(navigator, 'mediaDevices');
      
      final constraints = js_util.jsify({
        'audio': {
          'sampleRate': _sampleRate,
          'channelCount': 1,
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      });

      _stream = await js_util.promiseToFuture(
        js_util.callMethod(mediaDevices, 'getUserMedia', [constraints])
      );

      // Create MediaRecorder
      final mediaRecorderConstructor = js_util.getProperty(js_util.globalThis, 'MediaRecorder');
      
      // Try different MIME types for better compatibility
      final mimeTypes = [
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/ogg;codecs=opus',
        'audio/mp4',
        'audio/wav'
      ];
      
      String? supportedMimeType;
      for (final mimeType in mimeTypes) {
        if (js_util.callMethod(mediaRecorderConstructor, 'isTypeSupported', [mimeType])) {
          supportedMimeType = mimeType;
          break;
        }
      }

      _mediaRecorder = js_util.callConstructor(
        mediaRecorderConstructor,
        [_stream, if (supportedMimeType != null) js_util.jsify({'mimeType': supportedMimeType})]
      );

      // Set up event listeners
      js_util.setProperty(_mediaRecorder, 'ondataavailable', js_util.allowInterop((event) {
        final data = js_util.getProperty(event, 'data');
        if (js_util.getProperty(data, 'size') > 0) {
          _audioChunks.add(data);
        }
      }));

      js_util.setProperty(_mediaRecorder, 'onstop', js_util.allowInterop((_) {
        _processRecording();
      }));

      js_util.setProperty(_mediaRecorder, 'onerror', js_util.allowInterop((error) {
        if (kDebugMode) {
          print('🎤 MediaRecorder error: $error');
        }
        _completeWithError('Recording failed');
      }));

      // Start recording
      js_util.callMethod(_mediaRecorder, 'start', []);

      // Set maximum recording duration
      _maxDurationTimer = Timer(const Duration(seconds: _maxRecordingDuration), () {
        stopRecording();
      });

      if (kDebugMode) {
        print('🎤 Started recording with MIME type: $supportedMimeType');
      }

      return await _recordingCompleter!.future;

    } catch (e) {
      _cleanup();
      if (kDebugMode) {
        print('🎤 Recording error: $e');
      }
      throw Exception('Failed to start recording: $e');
    }
  }

  /// Stop recording and return the audio data as base64
  Future<void> stopRecording() async {
    if (_mediaRecorder == null) return;

    try {
      _maxDurationTimer?.cancel();
      js_util.callMethod(_mediaRecorder, 'stop', []);
      
      // Stop all tracks in the stream
      if (_stream != null) {
        final tracks = js_util.callMethod(_stream, 'getTracks', []);
        final trackCount = js_util.getProperty(tracks, 'length');
        for (int i = 0; i < trackCount; i++) {
          final track = js_util.getProperty(tracks, i.toString());
          js_util.callMethod(track, 'stop', []);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎤 Error stopping recording: $e');
      }
    }
  }

  /// Process the recorded audio chunks
  Future<void> _processRecording() async {
    try {
      if (_audioChunks.isEmpty) {
        _completeWithError('No audio data recorded');
        return;
      }

      // Create a Blob from the audio chunks
      final blobConstructor = js_util.getProperty(js_util.globalThis, 'Blob');
      final audioBlob = js_util.callConstructor(blobConstructor, [
        js_util.jsify(_audioChunks),
        js_util.jsify({'type': 'audio/webm'})
      ]);

      // Convert Blob to ArrayBuffer
      final arrayBuffer = await js_util.promiseToFuture(
        js_util.callMethod(audioBlob, 'arrayBuffer', [])
      );

      // Convert to Uint8List and then to base64
      final uint8List = Uint8List.view(arrayBuffer);
      final base64Audio = base64Encode(uint8List);

      if (kDebugMode) {
        print('🎤 Audio processed: ${uint8List.length} bytes');
      }

      _recordingCompleter?.complete(base64Audio);
      _cleanup();

    } catch (e) {
      if (kDebugMode) {
        print('🎤 Error processing recording: $e');
      }
      _completeWithError('Failed to process audio');
    }
  }

  /// Complete with error and cleanup
  void _completeWithError(String error) {
    _recordingCompleter?.completeError(Exception(error));
    _cleanup();
  }

  /// Clean up resources
  void _cleanup() {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _mediaRecorder = null;
    _stream = null;
    _audioChunks.clear();
    _recordingCompleter = null;
  }

  /// Send audio to Firebase Cloud Function for speech recognition
  static Future<String> recognizeSpeech(String base64Audio, {String languageCode = 'en-US'}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('processAudioSimple');
      final result = await callable.call({
        'audioData': base64Audio,
        'languageCode': languageCode,
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        final transcript = data['transcript'] as String;
        if (kDebugMode) {
          print('🎤 Speech recognition result: $transcript');
          if (data['isDemo'] == true) {
            print('🎤 Using demo mode (random response)');
          }
        }
        return transcript;
      } else {
        throw Exception('Speech recognition failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎤 Speech recognition error: $e');
      }
      throw Exception('Failed to process speech: $e');
    }
  }
}
