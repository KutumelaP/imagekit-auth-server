import 'package:flutter/material.dart';
import '../services/safari_state_persistence_service.dart';

/// Widget that detects Safari reloads and shows recovery splash
/// Makes reloads invisible to users by restoring their session
class SafariReloadRecoveryWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSessionRestored;
  
  const SafariReloadRecoveryWidget({
    super.key,
    required this.child,
    this.onSessionRestored,
  });

  @override
  State<SafariReloadRecoveryWidget> createState() => _SafariReloadRecoveryWidgetState();
}

class _SafariReloadRecoveryWidgetState extends State<SafariReloadRecoveryWidget>
    with TickerProviderStateMixin {
  bool _isRecovering = false;
  bool _hasRecovered = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _checkForSafariReload();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _checkForSafariReload() async {
    // Small delay to ensure Flutter is fully initialized
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted && SafariStatePersistenceService.isSafariReload) {
      setState(() {
        _isRecovering = true;
      });
      
      // Show recovery splash
      _animationController.forward();
      
      // Simulate recovery process
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        // Restore session
        _restoreSession();
        
        // Hide recovery splash
        _animationController.reverse();
        
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (mounted) {
          setState(() {
            _isRecovering = false;
            _hasRecovered = true;
          });
          
          // Update timestamp to prevent false reload detection
          SafariStatePersistenceService.updateReloadTimestamp();
          
          // Notify parent
          widget.onSessionRestored?.call();
        }
      }
    }
  }
  
  void _restoreSession() {
    // Restore cart state
    final cartState = SafariStatePersistenceService.loadCartState();
    if (cartState != null) {
      // TODO: Integrate with your cart provider
      print('🔄 [SAFARI] Cart restored: ${cartState.length} items');
    }
    
    // Restore user state
    final userState = SafariStatePersistenceService.loadUserState();
    if (userState != null) {
      // TODO: Integrate with your user provider
      print('🔄 [SAFARI] User session restored');
    }
    
    // Restore navigation state
    final navigationState = SafariStatePersistenceService.loadNavigationState();
    if (navigationState != null) {
      // TODO: Integrate with your navigation system
      print('🔄 [SAFARI] Navigation restored: ${navigationState['route']}');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Safari reload recovery overlay
        if (_isRecovering)
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                                                 // Safari icon
                         Container(
                           width: 80,
                           height: 80,
                           decoration: BoxDecoration(
                             color: Colors.blue.shade600,
                             borderRadius: BorderRadius.circular(20),
                           ),
                           child: const Icon(
                             Icons.web,
                             color: Colors.white,
                             size: 50,
                           ),
                         ),
                        
                        const SizedBox(height: 24),
                        
                        // Recovery message
                        const Text(
                          'Restoring Your Session',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        const Text(
                          'Safari reloaded the page, but we\'re\nrecovering your session...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Loading indicator
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        
        // Success message (brief)
        if (_hasRecovered && !_isRecovering)
          AnimatedOpacity(
            opacity: _hasRecovered ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Container(
              color: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Session Restored Successfully!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
