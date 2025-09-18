import 'package:flutter/material.dart';
import 'lib/widgets/voice_assistant/voice_assistant_service.dart';

/// Quick test to verify voice assistant is working
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔍 Testing Voice Assistant Integration...');
  
  // Initialize voice assistant
  final voiceAssistant = VoiceAssistantService();
  await voiceAssistant.initialize(
    userName: 'Test User',
    isNewUser: true,
  );
  
  // Set context
  voiceAssistant.setContext('home');
  
  print('✅ Voice Assistant initialized');
  print('Status: ${voiceAssistant.getStatus()}');
  
  // Test voice announcement
  print('🔊 Testing voice announcement...');
  await voiceAssistant.provideProactiveGuidance('first_open');
  
  // Wait a bit to hear the voice
  await Future.delayed(Duration(seconds: 3));
  
  print('✅ Voice Assistant test completed!');
  print('');
  print('You should now see:');
  print('1. A floating mic button in the bottom-right corner');
  print('2. Voice announcements when you interact with the app');
  print('3. Context-aware responses based on the current screen');
  print('');
  print('Try tapping the floating mic button to test voice interaction!');
  
  await voiceAssistant.dispose();
}
