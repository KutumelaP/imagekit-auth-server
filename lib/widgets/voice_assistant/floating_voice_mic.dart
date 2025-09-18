import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'voice_assistant_service.dart';

/// Floating Voice Microphone Widget
/// A small, unobtrusive floating mic button for voice assistant
class FloatingVoiceMic extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final Offset position;
  final bool showPulse;
  final bool showTooltip;

  const FloatingVoiceMic({
    Key? key,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.iconColor,
    this.size = 56.0,
    this.position = const Offset(16, 16),
    this.showPulse = true,
    this.showTooltip = true,
  }) : super(key: key);

  @override
  State<FloatingVoiceMic> createState() => _FloatingVoiceMicState();
}

class _FloatingVoiceMicState extends State<FloatingVoiceMic>
    with TickerProviderStateMixin {
  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();
  
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupVoiceAssistant();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupVoiceAssistant() {
    _voiceAssistant.listeningStream.listen((isListening) {
      if (mounted) {
        setState(() {
          _isListening = isListening;
        });
        
        if (isListening) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    });
    
    _voiceAssistant.processingStream.listen((isProcessing) {
      if (mounted) {
        setState(() {
          _isProcessing = isProcessing;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    
    if (_isListening) {
      _voiceAssistant.stopListening();
    } else {
      _voiceAssistant.startListening();
    }
    
    widget.onTap?.call();
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    
    widget.onLongPress?.call();
  }

  void _handleHover(bool isHovering) {
    if (mounted) {
      setState(() {
        _isHovering = isHovering;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: widget.position.dx,
      bottom: widget.position.dy,
      child: MouseRegion(
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse effect when listening
                  if (_isListening && widget.showPulse)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: widget.size * 1.5,
                            height: widget.size * 1.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_voiceAssistant.isActive 
                                  ? Colors.blue 
                                  : Colors.grey).withOpacity(0.3),
                            ),
                          ),
                        );
                      },
                    ),
                  
                  // Main mic button
                  GestureDetector(
                    onTap: _handleTap,
                    onLongPress: _handleLongPress,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getBackgroundColor(),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getIcon(),
                        color: _getIconColor(),
                        size: widget.size * 0.4,
                      ),
                    ),
                  ),
                  
                  // Processing indicator
                  if (_isProcessing)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!_voiceAssistant.isActive) {
      return Colors.grey.withOpacity(0.7);
    }
    
    if (_isProcessing) {
      return Colors.orange;
    }
    
    if (_isListening) {
      return Colors.red;
    }
    
    if (_isHovering) {
      return (widget.backgroundColor ?? Colors.blue).withOpacity(0.9);
    }
    
    return widget.backgroundColor ?? Colors.blue;
  }

  Color _getIconColor() {
    return widget.iconColor ?? Colors.white;
  }

  IconData _getIcon() {
    if (_isProcessing) {
      return Icons.hourglass_empty;
    }
    
    if (_isListening) {
      return Icons.mic;
    }
    
    return Icons.mic_none;
  }
}

/// Voice Assistant Tooltip Widget
class VoiceAssistantTooltip extends StatelessWidget {
  final String message;
  final bool isVisible;
  final Duration duration;

  const VoiceAssistantTooltip({
    Key? key,
    required this.message,
    this.isVisible = false,
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.record_voice_over,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Voice Assistant Status Indicator
class VoiceAssistantStatusIndicator extends StatelessWidget {
  final VoiceAssistantService voiceAssistant;
  final bool showText;

  const VoiceAssistantStatusIndicator({
    Key? key,
    required this.voiceAssistant,
    this.showText = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: voiceAssistant.listeningStream,
      builder: (context, snapshot) {
        final isListening = snapshot.data ?? false;
        
        if (!isListening) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mic,
                color: Colors.white,
                size: 16,
              ),
              if (showText) ...[
                const SizedBox(width: 4),
                const Text(
                  'Listening...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
