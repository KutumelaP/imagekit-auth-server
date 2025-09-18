import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../services/voice_service.dart';
import 'voice_language_manager.dart';

/// Voice Accessibility Manager for enhanced accessibility features
class VoiceAccessibilityManager {
  static final VoiceAccessibilityManager _instance = VoiceAccessibilityManager._internal();
  factory VoiceAccessibilityManager() => _instance;
  VoiceAccessibilityManager._internal();

  final VoiceService _voiceService = VoiceService();
  final VoiceLanguageManager _languageManager = VoiceLanguageManager();
  
  bool _screenReaderMode = false;
  bool _voiceOnlyNavigation = false;
  bool _highContrastVoice = false;
  double _voiceSpeed = 1.0;
  
  /// Enable screen reader mode
  void enableScreenReaderMode(bool enable) {
    _screenReaderMode = enable;
    if (enable) {
      _announceScreenReaderMode();
    }
  }

  /// Enable voice-only navigation
  void enableVoiceOnlyNavigation(bool enable) {
    _voiceOnlyNavigation = enable;
    if (enable) {
      _announceVoiceOnlyMode();
    }
  }

  /// Enable high contrast voice (clearer speech)
  void enableHighContrastVoice(bool enable) {
    _highContrastVoice = enable;
    if (enable) {
      _voiceSpeed = 0.7; // Slower for clarity
    } else {
      _voiceSpeed = 1.0;
    }
  }

  /// Announce screen reader mode
  Future<void> _announceScreenReaderMode() async {
    await _voiceService.speak(
      "Screen reader mode is now active. I'll describe everything on the screen for you. "
      "You can navigate using voice commands or gestures."
    );
  }

  /// Announce voice-only mode
  Future<void> _announceVoiceOnlyMode() async {
    await _voiceService.speak(
      "Voice-only navigation is now active. You can control the entire app using voice commands. "
      "Say 'help' to hear available commands."
    );
  }

  /// Describe screen element
  Future<void> describeElement(Widget element, String description) async {
    if (!_screenReaderMode) return;
    
    final localizedDescription = _getLocalizedDescription(description);
    await _voiceService.speak(localizedDescription);
  }

  /// Describe current screen
  Future<void> describeScreen(String screenName, List<String> elements) async {
    if (!_screenReaderMode) return;
    
    final currentLang = _languageManager.currentLanguage.code;
    String description = _getScreenDescription(screenName, currentLang);
    
    if (elements.isNotEmpty) {
      description += " " + _getElementsDescription(elements, currentLang);
    }
    
    await _voiceService.speak(description);
  }

  /// Get screen description in current language
  String _getScreenDescription(String screenName, String lang) {
    switch (lang) {
      case 'zu':
        return "Usesikhundleni se-$screenName.";
      case 'xh':
        return "Ukwisikrim se-$screenName.";
      case 'af':
        return "Jy is op die $screenName skerm.";
      default:
        return "You are on the $screenName screen.";
    }
  }

  /// Get elements description in current language
  String _getElementsDescription(List<String> elements, String lang) {
    final elementsText = elements.join(", ");
    switch (lang) {
      case 'zu':
        return "Izinto ezitholakalayo: $elementsText";
      case 'xh':
        return "Izinto ezikhoyo: $elementsText";
      case 'af':
        return "Beskikbare elemente: $elementsText";
      default:
        return "Available elements: $elementsText";
    }
  }

  /// Get localized description
  String _getLocalizedDescription(String description) {
    // For now, return as is. In the future, implement translation
    return description;
  }

  /// Create accessible button with voice feedback
  Widget createAccessibleButton({
    required String label,
    required VoidCallback onPressed,
    required String description,
    IconData? icon,
  }) {
    return Semantics(
      label: label,
      hint: description,
      button: true,
      child: ElevatedButton.icon(
        onPressed: () {
          if (_screenReaderMode) {
            _voiceService.speak("$label button pressed. $description");
          }
          onPressed();
        },
        icon: Icon(icon ?? Icons.touch_app),
        label: Text(label),
      ),
    );
  }

  /// Create accessible text field with voice feedback
  Widget createAccessibleTextField({
    required String label,
    required String hint,
    required Function(String) onChanged,
    TextEditingController? controller,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      textField: true,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
        onChanged: (value) {
          if (_screenReaderMode && value.isNotEmpty) {
            _voiceService.speak("You typed: $value");
          }
          onChanged(value);
        },
        onTap: () {
          if (_screenReaderMode) {
            _voiceService.speak("$label text field. $hint");
          }
        },
      ),
    );
  }

  /// Create accessible list item with voice feedback
  Widget createAccessibleListItem({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? leading,
    Widget? trailing,
  }) {
    final description = subtitle != null ? "$title. $subtitle" : title;
    
    return Semantics(
      label: title,
      hint: subtitle,
      button: true,
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing,
        onTap: () {
          if (_screenReaderMode) {
            _voiceService.speak("Selected $description");
          }
          onTap();
        },
      ),
    );
  }

  /// Navigate using voice commands
  Future<void> voiceNavigate(String command, BuildContext context) async {
    if (!_voiceOnlyNavigation) return;
    
    await _voiceService.speak("Navigating to $command");
    
    // Implement navigation logic based on voice commands
    switch (command.toLowerCase()) {
      case 'home':
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        break;
      case 'cart':
        Navigator.pushNamed(context, '/cart');
        break;
      case 'orders':
        Navigator.pushNamed(context, '/orders');
        break;
      case 'profile':
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  /// Get accessibility settings widget
  Widget buildAccessibilitySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Voice Accessibility Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Screen Reader Mode
          SwitchListTile(
            title: const Text('Screen Reader Mode'),
            subtitle: const Text('Describes all screen elements with voice'),
            value: _screenReaderMode,
            onChanged: enableScreenReaderMode,
          ),
          
          // Voice-Only Navigation
          SwitchListTile(
            title: const Text('Voice-Only Navigation'),
            subtitle: const Text('Control the app entirely with voice commands'),
            value: _voiceOnlyNavigation,
            onChanged: enableVoiceOnlyNavigation,
          ),
          
          // High Contrast Voice
          SwitchListTile(
            title: const Text('High Contrast Voice'),
            subtitle: const Text('Clearer, slower speech for better understanding'),
            value: _highContrastVoice,
            onChanged: enableHighContrastVoice,
          ),
          
          const SizedBox(height: 16),
          
          // Voice Speed Slider
          const Text('Voice Speed'),
          Slider(
            value: _voiceSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            label: '${(_voiceSpeed * 100).round()}%',
            onChanged: (value) {
              _voiceSpeed = value;
              // Update voice service speed
            },
          ),
          
          const SizedBox(height: 16),
          
          // Test Voice Button
          ElevatedButton(
            onPressed: () {
              _voiceService.speak(
                "This is a test of the accessibility voice settings. "
                "The voice speed is set to ${(_voiceSpeed * 100).round()} percent."
              );
            },
            child: const Text('Test Voice Settings'),
          ),
        ],
      ),
    );
  }

  /// Voice help for accessibility
  Future<void> announceAccessibilityHelp() async {
    await _voiceService.speak(
      "Accessibility features are available. You can enable screen reader mode "
      "for detailed descriptions, voice-only navigation for complete voice control, "
      "and high contrast voice for clearer speech. Say 'accessibility settings' to configure these options."
    );
  }

  /// Get accessibility status
  Map<String, bool> getAccessibilityStatus() {
    return {
      'screenReaderMode': _screenReaderMode,
      'voiceOnlyNavigation': _voiceOnlyNavigation,
      'highContrastVoice': _highContrastVoice,
    };
  }

  /// Handle voice accessibility commands
  Future<void> handleAccessibilityCommand(String command) async {
    switch (command.toLowerCase()) {
      case 'enable screen reader':
        enableScreenReaderMode(true);
        break;
      case 'disable screen reader':
        enableScreenReaderMode(false);
        break;
      case 'enable voice navigation':
        enableVoiceOnlyNavigation(true);
        break;
      case 'disable voice navigation':
        enableVoiceOnlyNavigation(false);
        break;
      case 'accessibility help':
        await announceAccessibilityHelp();
        break;
    }
  }
}
