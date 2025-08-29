import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chatbot_service.dart';

/// Floating chatbot widget for customer support
class ChatbotWidget extends StatefulWidget {
  final double? initialDx; // 0..1 of screen width
  final double? initialDy; // 0..1 of screen height
  final bool ignoreSavedPosition; // when true, don't restore saved position (use initial)
  const ChatbotWidget({Key? key, this.initialDx, this.initialDy, this.ignoreSavedPosition = false}) : super(key: key);

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> with TickerProviderStateMixin {
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode(debugLabel: 'chatbot_input');
  bool _isFullscreen = false;
  
  bool _isExpanded = false;
  bool _isInitialized = false;
  bool _isTyping = false;
  List<ChatMessage> _messages = [];
  
  // Draggable FAB position (normalized to screen width/height)
  // Persisted per device via SharedPreferences
  bool _positionLoaded = false;
  double _fabDx = 0.9; // 90% from left by default (near right)
  double _fabDy = kIsWeb ? 0.65 : 0.8; // Higher on web/PWA (65%), lower on mobile (80%)

  static const double _fabSize = 50.0;
  static const double _margin = 16.0;
  static const double _windowWidth = 280.0;
  double _windowHeight = 400.0;
  static const double _windowGap = 10.0;
  
  late AnimationController _slideController;
  late AnimationController _bounceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChatbot();
    _loadSavedPosition();
    
    // Listen for keyboard changes to auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.addListener(_onInputFocusChange);
      }
    });
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    // Start bounce animation
    _bounceController.repeat(reverse: true);
  }

  Future<void> _initializeChatbot() async {
    try {
      await _chatbotService.initialize();
      
      // Listen to messages stream (debounced to reduce rebuilds)
      _chatbotService.messagesStream.listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          _scrollToBottom();
        }
      });

      // Listen to typing indicator (debounced)
      _chatbotService.typingStream.listen((isTyping) {
        if (mounted && _isTyping != isTyping) {
          setState(() {
            _isTyping = isTyping;
          });
        }
      });

      _isInitialized = true;
    } catch (e) {
      // Silent fail for chatbot initialization
    }
  }

  Future<void> _loadSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDx = widget.ignoreSavedPosition ? null : prefs.getDouble('chatbot_fab_dx');
      final savedDy = widget.ignoreSavedPosition ? null : prefs.getDouble('chatbot_fab_dy');
      if (mounted) {
        setState(() {
          if (savedDx != null) {
            _fabDx = savedDx;
          } else if (widget.initialDx != null) {
            _fabDx = widget.initialDx!.clamp(0.0, 1.0);
          }
          if (savedDy != null) {
            _fabDy = savedDy;
          } else if (widget.initialDy != null) {
            _fabDy = widget.initialDy!.clamp(0.0, 1.0);
          }
          _positionLoaded = true;
        });
        // If we're ignoring saved position and we had initials, persist the new position for next time
        if (widget.ignoreSavedPosition) {
          _savePosition(_fabDx, _fabDy);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _positionLoaded = true;
        });
      }
    }
  }

  Future<void> _savePosition(double dx, double dy) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('chatbot_fab_dx', dx);
      await prefs.setDouble('chatbot_fab_dy', dy);
    } catch (_) {
      // ignore persistence failures silently
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) _isFullscreen = false;
    });

    if (_isExpanded) {
      _slideController.forward();
      _bounceController.stop();
      // Focus input after opening and scroll to bottom
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _inputFocusNode.requestFocus();
          _scrollToBottom();
        }
      });
    } else {
      _slideController.reverse();
      _bounceController.repeat(reverse: true);
    }
  }

  void _toggleFullscreen() {
    if (!_isExpanded) return;
    setState(() { _isFullscreen = !_isFullscreen; });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isInitialized) return;

    _messageController.clear();
    
    try {
      await _chatbotService.sendMessage(text);
      
      // Scroll to bottom after sending message
      _scrollToBottom();
      
      // Provide haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _onInputFocusChange() {
    if (_inputFocusNode.hasFocus) {
      // When input gets focus, scroll to bottom to show input field
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToBottom();
          
          // Additional safety: ensure input field is visible above keyboard
          final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
          if (keyboardInset > 0) {
            // Keyboard is open, scroll to ensure input is visible
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && _scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
            
            // Adjust window height if keyboard would push bot too high
            _adjustWindowHeightForKeyboard(keyboardInset);
          }
        }
      });
    }
  }
  
  void _adjustWindowHeightForKeyboard(double keyboardInset) {
    if (!mounted) return;
    
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    
    // Calculate if keyboard would push bot too high
    final currentHeight = _windowHeight;
    final minGapAboveKeyboard = 120.0;
    final minTop = 20.0;
    
    final wouldPushTooHigh = (screenSize.height - keyboardInset - currentHeight - minGapAboveKeyboard) < minTop;
    
    if (wouldPushTooHigh) {
      // Adjust height to fit above keyboard while maintaining minimum top position
      final adjustedHeight = screenSize.height - keyboardInset - minTop - minGapAboveKeyboard;
      if (adjustedHeight > 200) { // Minimum viable height
        setState(() {
          _windowHeight = adjustedHeight;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final keyboardInset = media.viewInsets.bottom;

    // Fixed positioning for bot FAB (no need for dynamic calculations)

    // Position chat window above the fixed bot FAB position
    final double windowLeft = 20.0; // Same left position as bot FAB
    
    // Smart keyboard-aware positioning with better text field visibility
    double windowTop;
    if (keyboardInset > 0) {
      // When keyboard is open, position window above keyboard with generous spacing
      // Ensure input field is always visible above keyboard and bot doesn't get pushed up too much
      final minGapAboveKeyboard = 120.0; // Increased gap to prevent bot from being pushed up too high
      windowTop = size.height - keyboardInset - _windowHeight - minGapAboveKeyboard;
      
      // Ensure the bot doesn't go above the top of the screen
      final minTop = 20.0;
      if (windowTop < minTop) {
        // If keyboard would push bot too high, adjust window height instead
        final adjustedHeight = size.height - keyboardInset - minTop - minGapAboveKeyboard;
        if (adjustedHeight > 200) { // Minimum viable height
          _windowHeight = adjustedHeight;
          windowTop = minTop;
        } else {
          // Fallback: position at minimum top with current height
          windowTop = minTop;
        }
      }
    } else {
      // Normal position: above the shifted bot FAB (now at bottom: 60)
      windowTop = size.height - _windowHeight - 120; // 120px above bottom (60px from FAB + 60px gap)
    }
    
    // Ensure window doesn't go off-screen and input field is always accessible
    final minTop = 20.0;
    final maxTop = size.height - _windowHeight - 20.0;
    windowTop = windowTop.clamp(minTop, maxTop);
    
    // Additional safety: if keyboard is open, ensure at least 120px gap above keyboard
    if (keyboardInset > 0) {
      final minGapAboveKeyboard = 120.0;
      final maxAllowedTop = size.height - keyboardInset - minGapAboveKeyboard;
      if (windowTop > maxAllowedTop) {
        windowTop = maxAllowedTop;
      }
    }

    return Stack(
      children: [
        // Chat window when expanded
        if (_isExpanded && !_isFullscreen)
          Positioned(left: windowLeft, top: windowTop, child: _buildChatWindow(fullscreen: false)),
        if (_isExpanded && _isFullscreen)
          Positioned.fill(child: _buildChatWindow(fullscreen: true)),

        // Fixed position floating action button (shifted up by 2 positions)
        Positioned(
          bottom: 60, // Shifted up from 20 to 60
          left: 20,
          child: Listener(
            onPointerDown: (_) {
              _bounceController.stop();
            },
            onPointerUp: (_) {
              if (!_isExpanded) {
                _bounceController.repeat(reverse: true);
              }
            },
            child: GestureDetector(
              onTap: _toggleExpanded,
              child: _buildFloatingButton(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatWindow({bool fullscreen = false}) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final screenSize = MediaQuery.of(context).size;
    
    if (fullscreen) {
      // Fullscreen mode: use full height minus keyboard
      return SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: screenSize.width,
          height: screenSize.height - keyboardInset,
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            children: [
              _buildHeader(fullscreen: true),
              Expanded(child: _buildMessagesList()),
              _buildInputArea(),
            ],
          ),
        ),
      );
    }
    
    // Normal mode: smart height calculation for keyboard with guaranteed input visibility
    final double maxHeight = screenSize.height * 0.6;
    const double minHeight = 280.0;
    
    double availableHeight;
    if (keyboardInset > 0) {
      // When keyboard is open, ensure input field is always visible
      // Calculate height to fit above keyboard with generous spacing
      final maxAllowedHeight = screenSize.height - keyboardInset - 120; // 120px margin when keyboard is open
      availableHeight = maxAllowedHeight.clamp(minHeight, maxHeight);
    } else {
      // Default height when no keyboard
      availableHeight = 400.0;
    }
    
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: fullscreen ? screenSize.width : 280,
        height: availableHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(fullscreen ? 0 : 20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(fullscreen: fullscreen),
            Expanded(child: _buildMessagesList()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({bool fullscreen = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D5A), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(fullscreen ? 0 : 20),
          topRight: Radius.circular(fullscreen ? 0 : 20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Online • Ready to help',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: fullscreen ? 'Exit full screen (F)' : 'Full screen (F)',
            onPressed: _toggleFullscreen,
            icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2E7D5A),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator();
        }
        
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) _buildBotAvatar(),
          if (!message.isUser) const SizedBox(width: 8),
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFF2E7D5A)
                    : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: message.isUser 
                          ? Colors.white70 
                          : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (message.isUser) const SizedBox(width: 8),
          if (message.isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D5A), Color(0xFF4CAF50)],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.smart_toy,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.blue[400],
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildBotAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(200),
                const SizedBox(width: 4),
                _buildTypingDot(400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.5 + (value * 0.5),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Increased padding for better spacing
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _inputFocusNode,
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Type a message…',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8), // Better text field padding
              ),
            ),
          ),
          const SizedBox(width: 8), // Add spacing between text field and send button
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, color: Color(0xFF2E7D5A)),
            padding: const EdgeInsets.all(8), // Better button padding
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40), // Ensure button is large enough
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton() {
    return ScaleTransition(
      scale: _bounceAnimation,
      child: GestureDetector(
        onTap: _toggleExpanded,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D5A), Color(0xFF4CAF50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D5A).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  _isExpanded ? Icons.close : Icons.chat_bubble,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              if (!_isExpanded && _messages.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bounceController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    // Clean up focus listener
    _inputFocusNode.removeListener(_onInputFocusChange);
    super.dispose();
  }
}

/// Wrapper widget to add chatbot to any screen
class ChatbotWrapper extends StatelessWidget {
  final Widget child;
  final bool showChatbot;
  final double? initialDx;
  final double? initialDy;

  const ChatbotWrapper({
    Key? key,
    required this.child,
    this.showChatbot = true,
    this.initialDx,
    this.initialDy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showChatbot)
          Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => Material(
                  type: MaterialType.transparency,
                  child: ChatbotWidget(
                    initialDx: initialDx,
                    initialDy: initialDy,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
