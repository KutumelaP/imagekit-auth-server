// Stub implementation for non-web platforms
// This file provides empty implementations for mobile/desktop builds

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Stub implementation of WebAudioRecorder for non-web platforms
class WebAudioRecorder {
  /// Check if audio recording is supported (always false on mobile - uses native speech recognition)
  static Future<bool> isSupported() async {
    return false;
  }

  /// Start recording (not implemented on mobile)
  Future<String> startRecording() async {
    throw UnsupportedError('Web audio recording is not supported on mobile platforms');
  }

  /// Stop recording (not implemented on mobile)
  Future<void> stopRecording() async {
    // No-op
  }

  /// Send audio to Firebase Cloud Function (not used on mobile)
  static Future<String> recognizeSpeech(String base64Audio, {String languageCode = 'en-US'}) async {
    throw UnsupportedError('Cloud speech recognition is not needed on mobile platforms');
  }
}
