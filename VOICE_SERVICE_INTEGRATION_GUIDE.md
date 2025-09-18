# Voice Service Integration Guide

## Overview

The VoiceService provides text-to-speech functionality for your food marketplace app with both Google Cloud TTS and local device TTS fallback. This guide shows how to integrate it into different parts of your application.

## Features

- ✅ **Dual TTS Support**: Google Cloud TTS with local device fallback
- ✅ **SSML Support**: Advanced speech markup for emphasis, pauses, and pronunciation
- ✅ **Audio State Management**: Play, pause, resume, and stop controls
- ✅ **Configurable Voice Settings**: Language, rate, pitch, and voice selection
- ✅ **Error Handling**: Graceful fallback and comprehensive error management
- ✅ **Resource Management**: Proper cleanup and disposal

## Setup

### 1. Dependencies

The required dependencies are already in your `pubspec.yaml`:
```yaml
dependencies:
  flutter_tts: ^4.2.3
  audioplayers: ^5.2.1
  http: ^1.1.0
```

### 2. Google Cloud TTS Setup (Optional)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the Text-to-Speech API
3. Create credentials (API Key)
4. Add the API key to your environment or pass it during initialization

### 3. Platform Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice features</string>
```

## Basic Usage

### 1. Initialize the Service

```dart
import 'package:your_app/services/voice_service.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final VoiceService _voiceService = VoiceService();

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    await _voiceService.initialize(
      googleApiKey: "YOUR_GOOGLE_API_KEY", // Optional
    );
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}
```

### 2. Basic Text-to-Speech

```dart
// Simple text speaking
await _voiceService.speak("Welcome to our food marketplace!");

// With Google TTS preference
await _voiceService.speak("Order confirmed!", preferGoogle: true);

// Force local TTS
await _voiceService.speak("Order confirmed!", preferGoogle: false);
```

### 3. SSML Support

```dart
// Advanced speech with emphasis and pauses
final ssml = '''
  <speak>
    <emphasis level="strong">Special Offer!</emphasis>
    <break time="500ms"/>
    Get 20% off on all pizzas today!
    <break time="300ms"/>
    Order now!
  </speak>
''';
await _voiceService.speakSsml(ssml);
```

## Integration Examples

### 1. Order Confirmation Screen

```dart
class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;
  final double total;

  @override
  _OrderConfirmationScreenState createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  final VoiceService _voiceService = VoiceService();

  @override
  void initState() {
    super.initState();
    _announceOrderConfirmation();
  }

  Future<void> _announceOrderConfirmation() async {
    final message = "Order confirmed! Your order number is ${widget.orderId}. "
        "Total amount is R${widget.total.toStringAsFixed(2)}. "
        "Thank you for choosing our marketplace!";
    await _voiceService.speak(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order Confirmed')),
      body: Column(
        children: [
          // Your existing UI
          Text('Order ID: ${widget.orderId}'),
          Text('Total: R${widget.total}'),
          
          // Voice controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => _voiceService.pause(),
                child: Text('Pause'),
              ),
              ElevatedButton(
                onPressed: () => _voiceService.resume(),
                child: Text('Resume'),
              ),
              ElevatedButton(
                onPressed: () => _voiceService.stop(),
                child: Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### 2. Delivery Tracking Screen

```dart
class DeliveryTrackingScreen extends StatefulWidget {
  @override
  _DeliveryTrackingScreenState createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final VoiceService _voiceService = VoiceService();
  String _deliveryStatus = 'preparing';

  Future<void> _announceStatusUpdate(String status) async {
    String message;
    switch (status) {
      case 'preparing':
        message = "Your order is being prepared by our kitchen team.";
        break;
      case 'out_for_delivery':
        message = "Your order is out for delivery! Driver is on the way.";
        break;
      case 'delivered':
        message = "Your order has been delivered! Enjoy your meal!";
        break;
      default:
        message = "Order status updated to: $status.";
    }
    await _voiceService.speak(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Track Delivery')),
      body: Column(
        children: [
          // Status indicator
          Text('Status: $_deliveryStatus'),
          
          // Status update button
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _deliveryStatus = 'out_for_delivery';
              });
              await _announceStatusUpdate(_deliveryStatus);
            },
            child: Text('Update Status'),
          ),
        ],
      ),
    );
  }
}
```

### 3. Product Search Results

```dart
class ProductSearchScreen extends StatefulWidget {
  @override
  _ProductSearchScreenState createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final VoiceService _voiceService = VoiceService();
  List<Product> _searchResults = [];

  Future<void> _performSearch(String query) async {
    // Your existing search logic
    final results = await searchProducts(query);
    setState(() {
      _searchResults = results;
    });

    // Announce search results
    if (results.isNotEmpty) {
      final message = "Found ${results.length} products for '$query'. "
          "Swipe to browse through the results.";
      await _voiceService.speak(message);
    } else {
      await _voiceService.speak("No products found for '$query'. Try a different search term.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Products')),
      body: Column(
        children: [
          // Search bar
          TextField(
            onSubmitted: _performSearch,
            decoration: InputDecoration(
              hintText: 'Search for products...',
              suffixIcon: IconButton(
                icon: Icon(Icons.mic),
                onPressed: () async {
                  // Voice search implementation
                  await _voiceService.speak("Voice search not implemented yet.");
                },
              ),
            ),
          ),
          
          // Search results
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final product = _searchResults[index];
                return ListTile(
                  title: Text(product.name),
                  onTap: () async {
                    // Announce product selection
                    await _voiceService.speak("${product.name} selected. Price: R${product.price}");
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### 4. Accessibility Features

```dart
class AccessibilityService {
  final VoiceService _voiceService = VoiceService();

  // Announce screen changes
  Future<void> announceScreenChange(String screenName) async {
    await _voiceService.speak("Now viewing: $screenName");
  }

  // Announce button actions
  Future<void> announceButtonAction(String action) async {
    await _voiceService.speak("Button pressed: $action");
  }

  // Announce form validation errors
  Future<void> announceValidationError(String field, String error) async {
    await _voiceService.speak("$field error: $error");
  }

  // Announce successful actions
  Future<void> announceSuccess(String action) async {
    await _voiceService.speak("$action completed successfully");
  }
}
```

## Advanced Configuration

### 1. Custom Voice Settings

```dart
// Update voice configuration
await _voiceService.updateConfig(
  const VoiceConfig(
    language: "en-ZA", // South African English
    speechRate: 0.8,   // Slower speech
    pitch: 1.1,        // Higher pitch
    voiceName: "en-US-Wavenet-A", // Different voice
  ),
);
```

### 2. Multi-language Support

```dart
class MultiLanguageVoiceService {
  final VoiceService _voiceService = VoiceService();

  Future<void> speakInLanguage(String text, String languageCode) async {
    await _voiceService.updateConfig(
      VoiceConfig(
        language: languageCode,
        speechRate: 0.8, // Slower for non-native speakers
      ),
    );
    await _voiceService.speak(text);
  }

  // Example usage
  Future<void> announceOrderInAfrikaans(String orderId) async {
    await speakInLanguage("Bestelling bevestig! Bestelling nommer: $orderId", "af-ZA");
  }
}
```

### 3. Voice Controls

```dart
class VoiceControlService {
  final VoiceService _voiceService = VoiceService();

  Future<void> handleVoiceCommand(String command) async {
    switch (command.toLowerCase()) {
      case 'stop':
        await _voiceService.stop();
        break;
      case 'pause':
        await _voiceService.pause();
        break;
      case 'resume':
        await _voiceService.resume();
        break;
      case 'repeat':
        if (_voiceService.currentText != null) {
          await _voiceService.speak(_voiceService.currentText!);
        }
        break;
      default:
        await _voiceService.speak("Command not recognized: $command");
    }
  }
}
```

## Error Handling

```dart
class VoiceServiceWithErrorHandling {
  final VoiceService _voiceService = VoiceService();

  Future<void> speakWithErrorHandling(String text) async {
    try {
      await _voiceService.speak(text);
    } catch (e) {
      // Log error
      print('Voice service error: $e');
      
      // Show user-friendly message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice service temporarily unavailable'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => speakWithErrorHandling(text),
          ),
        ),
      );
    }
  }
}
```

## Best Practices

1. **Initialize Early**: Initialize the VoiceService in your app's main widget
2. **Dispose Properly**: Always call `dispose()` when done
3. **Handle Errors**: Implement proper error handling for network issues
4. **User Preferences**: Allow users to enable/disable voice features
5. **Battery Optimization**: Consider battery usage for voice features
6. **Accessibility**: Use voice features to improve app accessibility
7. **Testing**: Test on different devices and network conditions

## Troubleshooting

### Common Issues

1. **No Sound**: Check device volume and audio permissions
2. **Google TTS Fails**: Verify API key and network connection
3. **Local TTS Issues**: Check device language settings
4. **Performance**: Use voice features judiciously to avoid battery drain

### Debug Mode

Enable debug mode to see detailed logs:
```dart
// The service automatically uses debug mode in debug builds
// Check console for detailed logging
```

## Conclusion

The VoiceService provides a robust foundation for adding voice features to your food marketplace app. Use it to enhance user experience, improve accessibility, and provide innovative voice-guided interactions for your customers.
