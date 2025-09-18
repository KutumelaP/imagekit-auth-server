import 'package:flutter/material.dart';
import 'lib/services/voice_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VoiceTestScreen(),
    );
  }
}

class VoiceTestScreen extends StatefulWidget {
  @override
  _VoiceTestScreenState createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen> {
  final VoiceService _voiceService = VoiceService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    try {
      await _voiceService.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing voice: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nathan Voice Test'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Test Nathan\'s Baby Voice',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            // Google WaveNet Test
            ElevatedButton(
              onPressed: _isInitialized ? _testGoogleWaveNet : null,
              child: Text('Test Google WaveNet (Child Voice)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.all(16),
              ),
            ),
            SizedBox(height: 10),
            
            // Local TTS Test
            ElevatedButton(
              onPressed: _isInitialized ? _testLocalTTS : null,
              child: Text('Test Local TTS (Fallback)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.all(16),
              ),
            ),
            SizedBox(height: 10),
            
            // Test All Voices
            ElevatedButton(
              onPressed: _isInitialized ? _testAllVoices : null,
              child: Text('Test All Google Voices'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: EdgeInsets.all(16),
              ),
            ),
            SizedBox(height: 20),
            
            Text(
              'Google TTS Available: ${_voiceService.isGoogleTtsAvailable}',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testGoogleWaveNet() async {
    await _voiceService.speak(
      "Hi! I'm Nathan, your baby shopping assistant! I sound much more like a baby now with Google WaveNet!",
      preferGoogle: true,
    );
  }

  Future<void> _testLocalTTS() async {
    await _voiceService.speak(
      "This is my local TTS fallback voice. Not as good as Google WaveNet!",
      preferGoogle: false,
    );
  }

  Future<void> _testAllVoices() async {
    await _voiceService.testBabyVoices();
  }
}
