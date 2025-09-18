import 'package:flutter/material.dart';
import 'onboarding_voice_guide.dart';

/// Onboarding Widget for new users
/// Shows a welcome message and starts voice onboarding
class OnboardingWidget extends StatefulWidget {
  final String userName;
  final DateTime? userRegistrationDate;
  final bool hasPlacedOrder;
  final bool hasBrowsedProducts;
  final VoidCallback? onOnboardingComplete;

  const OnboardingWidget({
    Key? key,
    required this.userName,
    this.userRegistrationDate,
    this.hasPlacedOrder = false,
    this.hasBrowsedProducts = false,
    this.onOnboardingComplete,
  }) : super(key: key);

  @override
  State<OnboardingWidget> createState() => _OnboardingWidgetState();
}

class _OnboardingWidgetState extends State<OnboardingWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _showOnboarding = false;
  bool _isOnboardingActive = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkOnboardingStatus();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
  }

  void _checkOnboardingStatus() {
    final needsOnboarding = OnboardingVoiceGuide.shouldShowOnboarding(
      userRegistrationDate: widget.userRegistrationDate,
      hasPlacedOrder: widget.hasPlacedOrder,
      hasBrowsedProducts: widget.hasBrowsedProducts,
    );
    
    if (needsOnboarding) {
      setState(() {
        _showOnboarding = true;
      });
      
      // Start animations
      _fadeController.forward();
      _slideController.forward();
      
      // Start voice onboarding after a delay
      Future.delayed(const Duration(seconds: 2), () {
        _startVoiceOnboarding();
      });
    }
  }

  Future<void> _startVoiceOnboarding() async {
    if (_isOnboardingActive) return;
    
    setState(() {
      _isOnboardingActive = true;
    });
    
    try {
      await OnboardingVoiceGuide.startOnboarding(
        userName: widget.userName,
        context: context,
      );
    } catch (e) {
      print('❌ Error during voice onboarding: $e');
    } finally {
      setState(() {
        _isOnboardingActive = false;
      });
    }
  }

  void _skipOnboarding() {
    setState(() {
      _showOnboarding = false;
      _isOnboardingActive = false;
    });
    
    _fadeController.reverse();
    _slideController.reverse();
    
    widget.onOnboardingComplete?.call();
  }

  void _restartOnboarding() {
    _startVoiceOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOnboarding) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _slideAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Welcome icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.record_voice_over,
                          size: 40,
                          color: Colors.blue,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Welcome text
                      const Text(
                        'Welcome to OmniaSA!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Text(
                        'I\'m your shopping assistant and I\'m here to help you get started!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Status indicator
                      if (_isOnboardingActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Voice guide is playing...',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Skip button
                          TextButton(
                            onPressed: _skipOnboarding,
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          
                          // Restart button
                          if (_isOnboardingActive)
                            TextButton(
                              onPressed: _restartOnboarding,
                              child: const Text(
                                'Restart',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          
                          // Start button
                          if (!_isOnboardingActive)
                            ElevatedButton(
                              onPressed: _startVoiceOnboarding,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Start Guide',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Help text
                      Text(
                        'Tap the floating mic button anytime for help!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}

/// Simple onboarding overlay that can be added to any screen
class OnboardingOverlay extends StatelessWidget {
  final Widget child;
  final String userName;
  final DateTime? userRegistrationDate;
  final bool hasPlacedOrder;
  final bool hasBrowsedProducts;

  const OnboardingOverlay({
    Key? key,
    required this.child,
    required this.userName,
    this.userRegistrationDate,
    this.hasPlacedOrder = false,
    this.hasBrowsedProducts = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        OnboardingWidget(
          userName: userName,
          userRegistrationDate: userRegistrationDate,
          hasPlacedOrder: hasPlacedOrder,
          hasBrowsedProducts: hasBrowsedProducts,
        ),
      ],
    );
  }
}
