import 'package:flutter/material.dart';
import 'voice_assistant_service.dart';
import 'floating_voice_mic.dart';

/// Main Voice Assistant Widget
/// Easy-to-integrate voice assistant with floating mic and tooltips
class VoiceAssistantWidget extends StatefulWidget {
  final Widget child;
  final String? userName;
  final bool isNewUser;
  final bool showFloatingMic;
  final bool showTooltips;
  final bool showStatusIndicator;
  final Offset micPosition;
  final Color? micColor;
  final VoidCallback? onAssistantActivated;
  final VoidCallback? onAssistantDeactivated;

  const VoiceAssistantWidget({
    Key? key,
    required this.child,
    this.userName,
    this.isNewUser = false,
    this.showFloatingMic = true,
    this.showTooltips = true,
    this.showStatusIndicator = true,
    this.micPosition = const Offset(16, 16),
    this.micColor,
    this.onAssistantActivated,
    this.onAssistantDeactivated,
  }) : super(key: key);

  @override
  State<VoiceAssistantWidget> createState() => _VoiceAssistantWidgetState();
}

class _VoiceAssistantWidgetState extends State<VoiceAssistantWidget> {
  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();
  
  bool _showWelcomeTooltip = false;
  bool _showHelpTooltip = false;
  String _currentTooltipMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeVoiceAssistant();
    _setupTooltips();
  }

  Future<void> _initializeVoiceAssistant() async {
    await _voiceAssistant.initialize(
      userName: widget.userName,
      isNewUser: widget.isNewUser,
    );
    
    // Show welcome message for new users
    if (widget.isNewUser) {
      _showWelcomeMessage();
    }
  }

  void _setupTooltips() {
    _voiceAssistant.responseStream.listen((response) {
      if (mounted) {
        setState(() {
          _currentTooltipMessage = response;
          _showHelpTooltip = true;
        });
        
        // Hide tooltip after delay
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showHelpTooltip = false;
            });
          }
        });
      }
    });
  }

  void _showWelcomeMessage() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showWelcomeTooltip = true;
        });
        
        // Hide welcome tooltip after delay
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showWelcomeTooltip = false;
            });
          }
        });
      }
    });
  }

  void _handleMicTap() {
    if (_voiceAssistant.isListening) {
      _voiceAssistant.stopListening();
    } else {
      _voiceAssistant.startListening();
    }
  }

  void _handleMicLongPress() {
    // Show help tooltip
    setState(() {
      _currentTooltipMessage = "Hold to talk, tap to start listening. Ask me anything about the app!";
      _showHelpTooltip = true;
    });
    
    // Hide tooltip after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showHelpTooltip = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main app content
        widget.child,
        
        // Voice Assistant Components
        if (widget.showFloatingMic)
          FloatingVoiceMic(
            onTap: _handleMicTap,
            onLongPress: _handleMicLongPress,
            backgroundColor: widget.micColor,
            position: widget.micPosition,
          ),
        
        // Status indicator
        if (widget.showStatusIndicator)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: VoiceAssistantStatusIndicator(
              voiceAssistant: _voiceAssistant,
            ),
          ),
        
        // Welcome tooltip for new users
        if (widget.showTooltips && _showWelcomeTooltip)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            right: 16,
            child: VoiceAssistantTooltip(
              message: "Hi! I'm your shopping assistant. Hold the mic button and ask me anything!",
              isVisible: _showWelcomeTooltip,
            ),
          ),
        
        // Help tooltip
        if (widget.showTooltips && _showHelpTooltip)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: VoiceAssistantTooltip(
              message: _currentTooltipMessage,
              isVisible: _showHelpTooltip,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _voiceAssistant.dispose();
    super.dispose();
  }
}

/// Voice Assistant Settings Widget
class VoiceAssistantSettings extends StatefulWidget {
  final VoiceAssistantService voiceAssistant;
  final VoidCallback? onSettingsChanged;

  const VoiceAssistantSettings({
    Key? key,
    required this.voiceAssistant,
    this.onSettingsChanged,
  }) : super(key: key);

  @override
  State<VoiceAssistantSettings> createState() => _VoiceAssistantSettingsState();
}

class _VoiceAssistantSettingsState extends State<VoiceAssistantSettings> {
  bool _isEnabled = true;
  bool _showTooltips = true;
  bool _showStatusIndicator = true;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.voiceAssistant.isActive;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voice Assistant Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Enable/Disable toggle
            SwitchListTile(
              title: const Text('Enable Voice Assistant'),
              subtitle: const Text('Turn on/off voice guidance'),
              value: _isEnabled,
              onChanged: (value) {
                setState(() {
                  _isEnabled = value;
                });
                widget.voiceAssistant.toggleAssistant();
                widget.onSettingsChanged?.call();
              },
            ),
            
            // Tooltips toggle
            SwitchListTile(
              title: const Text('Show Tooltips'),
              subtitle: const Text('Display helpful messages'),
              value: _showTooltips,
              onChanged: (value) {
                setState(() {
                  _showTooltips = value;
                });
                widget.onSettingsChanged?.call();
              },
            ),
            
            // Status indicator toggle
            SwitchListTile(
              title: const Text('Show Status Indicator'),
              subtitle: const Text('Display listening status'),
              value: _showStatusIndicator,
              onChanged: (value) {
                setState(() {
                  _showStatusIndicator = value;
                });
                widget.onSettingsChanged?.call();
              },
            ),
            
            const SizedBox(height: 16),
            
            // Voice service status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voice Service Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<bool>(
                    stream: widget.voiceAssistant.listeningStream,
                    builder: (context, snapshot) {
                      final isListening = snapshot.data ?? false;
                      return Row(
                        children: [
                          Icon(
                            isListening ? Icons.mic : Icons.mic_none,
                            color: isListening ? Colors.green : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isListening ? 'Listening' : 'Ready',
                            style: TextStyle(
                              color: isListening ? Colors.green : Colors.grey[600],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Voice Assistant Demo Widget
class VoiceAssistantDemo extends StatefulWidget {
  const VoiceAssistantDemo({Key? key}) : super(key: key);

  @override
  State<VoiceAssistantDemo> createState() => _VoiceAssistantDemoState();
}

class _VoiceAssistantDemoState extends State<VoiceAssistantDemo> {
  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();
  String _currentContext = 'home';

  @override
  void initState() {
    super.initState();
    _voiceAssistant.initialize(userName: 'Demo User', isNewUser: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Voice Assistant Settings'),
                  content: VoiceAssistantSettings(
                    voiceAssistant: _voiceAssistant,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: VoiceAssistantWidget(
        userName: 'Demo User',
        isNewUser: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Context selector
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Context',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: _currentContext,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'home', child: Text('Home Screen')),
                          DropdownMenuItem(value: 'products', child: Text('Products Screen')),
                          DropdownMenuItem(value: 'cart', child: Text('Cart Screen')),
                          DropdownMenuItem(value: 'checkout', child: Text('Checkout Screen')),
                          DropdownMenuItem(value: 'orders', child: Text('Orders Screen')),
                          DropdownMenuItem(value: 'profile', child: Text('Profile Screen')),
                          DropdownMenuItem(value: 'seller', child: Text('Seller Screen')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _currentContext = value;
                            });
                            _voiceAssistant.setContext(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Demo instructions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Demo Instructions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Tap the floating mic button to start listening\n'
                        '2. Ask questions like:\n'
                        '   • "How do I place an order?"\n'
                        '   • "What payment methods do you accept?"\n'
                        '   • "How do I track my delivery?"\n'
                        '3. Change the context above to see different responses\n'
                        '4. Long press the mic for help',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Voice status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Voice Assistant Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<Map<String, dynamic>>(
                        stream: Stream.periodic(
                          const Duration(milliseconds: 500),
                          (_) => _voiceAssistant.getStatus(),
                        ),
                        builder: (context, snapshot) {
                          final status = snapshot.data ?? {};
                          return Column(
                            children: [
                              _buildStatusRow('Active', status['isActive'] ?? false),
                              _buildStatusRow('Listening', status['isListening'] ?? false),
                              _buildStatusRow('Processing', status['isProcessing'] ?? false),
                              _buildStatusRow('Google TTS', status['voiceServiceAvailable'] ?? false),
                              _buildStatusRow('Context', status['currentContext'] ?? 'None'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          if (value is bool)
            Icon(
              value ? Icons.check_circle : Icons.cancel,
              color: value ? Colors.green : Colors.red,
              size: 16,
            )
          else
            Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _voiceAssistant.dispose();
    super.dispose();
  }
}
