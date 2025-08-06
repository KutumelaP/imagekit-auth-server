import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firebase_auth_wrapper.dart';

/// Error boundary widget to catch Firebase Auth casting errors
class FirebaseErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(String error)? errorBuilder;

  const FirebaseErrorBoundary({
    Key? key,
    required this.child,
    this.errorBuilder,
  }) : super(key: key);

  @override
  State<FirebaseErrorBoundary> createState() => _FirebaseErrorBoundaryState();
}

class _FirebaseErrorBoundaryState extends State<FirebaseErrorBoundary> {
  String? _error;
  bool _isRecovering = false;
  bool _hasDisabledAuth = false;

  @override
  void initState() {
    super.initState();
    // Set up error handling for Firebase Auth
    _setupErrorHandling();
  }

  void _setupErrorHandling() {
    // Override Flutter's error handling for Firebase Auth specific errors
    FlutterError.onError = (FlutterErrorDetails details) {
      final error = details.exception.toString();
      
      // Check if this is a PigeonUserDetails casting error
      if (error.contains('PigeonUserDetails') || 
          error.contains('List<Object?>') ||
          error.contains('type cast')) {
        print('⚠️ Caught Firebase Auth casting error: $error');
        
        if (mounted) {
          setState(() {
            _error = 'Authentication error detected. Attempting to recover...';
          });
          
          // Try to recover automatically
          _attemptRecovery();
        }
        return;
      }
      
      // Let other errors pass through
      FlutterError.presentError(details);
    };
  }

  Future<void> _attemptRecovery() async {
    if (_isRecovering) return;
    
    setState(() {
      _isRecovering = true;
    });

    try {
      // Wait a bit before attempting recovery
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Completely disable Firebase Auth if we're still having issues
      if (FirebaseAuthWrapper.hasCastingErrors) {
        FirebaseAuthWrapper.disable();
        _hasDisabledAuth = true;
        print('🚫 Firebase Auth completely disabled due to persistent casting errors');
      }
      
      // Force refresh the Firebase Auth wrapper cache
      FirebaseAuthWrapper.forceRefreshCache();
      
      // Wait a bit more
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _error = null;
          _isRecovering = false;
        });
        print('✅ Firebase Auth error recovery successful');
      }
    } catch (e) {
      print('❌ Firebase Auth error recovery failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Recovery failed. Firebase Auth has been disabled.';
          _isRecovering = false;
        });
      }
    }
  }

  void _enableAuth() {
    FirebaseAuthWrapper.enable();
    setState(() {
      _error = null;
      _hasDisabledAuth = false;
    });
    print('✅ Firebase Auth manually re-enabled');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!) ?? _buildDefaultErrorWidget();
    }
    
    return widget.child;
  }

  Widget _buildDefaultErrorWidget() {
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isRecovering ? Icons.refresh : Icons.error_outline,
                  size: 64,
                  color: AppTheme.deepTeal,
                ),
                const SizedBox(height: 24),
                Text(
                  _isRecovering ? 'Recovering...' : 'Authentication Error',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'An authentication error occurred.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.cloud,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_hasDisabledAuth) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Firebase Auth has been disabled to prevent crashes. You can still use the app with limited functionality.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.deepTeal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (_isRecovering) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                  ),
                ] else ...[
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _attemptRecovery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Try Again'),
                  ),
                  const SizedBox(height: 16),
                  if (_hasDisabledAuth) ...[
                    TextButton(
                      onPressed: _enableAuth,
                      child: Text(
                        'Re-enable Firebase Auth',
                        style: TextStyle(color: AppTheme.deepTeal),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextButton(
                    onPressed: () {
                      // Restart the app
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/home',
                        (route) => false,
                      );
                    },
                    child: Text(
                      'Restart App',
                      style: TextStyle(color: AppTheme.deepTeal),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 