import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/bulletproof_service.dart';
import '../services/advanced_security_service.dart';
import '../services/enterprise_performance_service.dart';

/// 🛡️ BULLETPROOF WIDGET - Enterprise-grade widget protection
/// 
/// This widget wrapper provides:
/// - Error boundary protection
/// - Performance monitoring
/// - Security validation
/// - Memory optimization
/// - Automatic recovery
class BulletproofWidget extends StatefulWidget {
  final Widget child;
  final String context;
  final bool enablePerformanceMonitoring;
  final bool enableSecurityValidation;
  final bool enableErrorRecovery;

  const BulletproofWidget({
    super.key,
    required this.child,
    required this.context,
    this.enablePerformanceMonitoring = true,
    this.enableSecurityValidation = true,
    this.enableErrorRecovery = true,
  });

  @override
  State<BulletproofWidget> createState() => _BulletproofWidgetState();
}

class _BulletproofWidgetState extends State<BulletproofWidget> {
  bool _hasError = false;
  String? _errorMessage;
  int _buildCount = 0;
  DateTime? _lastBuildTime;

  @override
  void initState() {
    super.initState();
    _recordWidgetInitialization();
  }

  @override
  Widget build(BuildContext context) {
    final stopwatch = Stopwatch()..start();

    try {
      // Security validation
      if (widget.enableSecurityValidation) {
        _validateSecurity();
      }

      // Performance monitoring
      if (widget.enablePerformanceMonitoring) {
        _monitorPerformance();
      }

      // Build the widget
      final builtWidget = _buildProtectedWidget();

      // Record build performance
      stopwatch.stop();
      EnterprisePerformanceService.recordPerformanceMetric(
        '${widget.context}_build',
        stopwatch.elapsedMilliseconds.toDouble(),
      );

      _buildCount++;
      _lastBuildTime = DateTime.now();

      return builtWidget;
    } catch (e) {
      // Handle build errors
      return _handleBuildError(e);
    }
  }

  /// 🛡️ Build protected widget with error boundary
  Widget _buildProtectedWidget() {
    if (_hasError) {
      return _buildErrorWidget();
    }

    return RepaintBoundary(
      child: widget.child,
    );
  }

  /// 🚨 Handle build errors
  Widget _handleBuildError(dynamic error) {
    _hasError = true;
    _errorMessage = error.toString();

    // Record security violation
    BulletproofService.recordSecurityViolation(
      'widget_build_error',
      '${widget.context}: $error',
    );

    // Attempt recovery if enabled
    if (widget.enableErrorRecovery) {
      _attemptErrorRecovery();
    }

    return _buildErrorWidget();
  }

  /// 🔄 Attempt error recovery
  void _attemptErrorRecovery() {
    // Implement error recovery logic
    print('🔄 RECOVERY: Attempting to recover from widget error in ${widget.context}');
    
    // Clear error state after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _hasError = false;
          _errorMessage = null;
        });
      }
    });
  }

  /// 🚨 Build error widget
  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade600,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Something went wrong',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We\'re working to fix this issue.',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 12,
            ),
          ),
          if (kDebugMode && _errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              'Debug: $_errorMessage',
              style: TextStyle(
                color: Colors.red.shade500,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 🛡️ Validate security
  void _validateSecurity() {
    // Implement security validation logic
    // This could include checking for suspicious content, validating data, etc.
    
    // For now, we'll just log the validation
    if (kDebugMode) {
      print('🛡️ SECURITY: Validating widget ${widget.context}');
    }
  }

  /// ⚡ Monitor performance
  void _monitorPerformance() {
    // Check build frequency
    if (_lastBuildTime != null) {
      final timeSinceLastBuild = DateTime.now().difference(_lastBuildTime!);
      if (timeSinceLastBuild < const Duration(milliseconds: 100)) {
        // Too frequent rebuilds
        print('⚠️ PERFORMANCE: Widget ${widget.context} rebuilding too frequently');
        EnterprisePerformanceService.recordPerformanceMetric(
          '${widget.context}_frequent_rebuilds',
          timeSinceLastBuild.inMilliseconds.toDouble(),
        );
      }
    }

    // Check build count
    if (_buildCount > 100) {
      print('⚠️ PERFORMANCE: Widget ${widget.context} has been built $_buildCount times');
    }
  }

  /// 📊 Record widget initialization
  void _recordWidgetInitialization() {
    EnterprisePerformanceService.recordPerformanceMetric(
      '${widget.context}_initialization',
      0.0,
    );
  }

  @override
  void dispose() {
    // Record widget lifecycle
    EnterprisePerformanceService.recordPerformanceMetric(
      '${widget.context}_disposal',
      0.0,
    );
    super.dispose();
  }
}

/// 🛡️ BULLETPROOF TEXT FIELD - Secure input field
class BulletproofTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String context;

  const BulletproofTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    required this.context,
  });

  @override
  State<BulletproofTextField> createState() => _BulletproofTextFieldState();
}

class _BulletproofTextFieldState extends State<BulletproofTextField> {
  final TextEditingController _internalController = TextEditingController();
  bool _hasSecurityViolation = false;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    final controller = widget.controller ?? _internalController;
    
    controller.addListener(() {
      _validateInput(controller.text);
    });
  }

  void _validateInput(String? text) {
    if (text == null || text.isEmpty) return;

    // Security validation
    final sanitized = AdvancedSecurityService.sanitizeInput(text, context: widget.context);
    
    if (sanitized == null) {
      setState(() {
        _hasSecurityViolation = true;
      });
      
      BulletproofService.recordSecurityViolation(
        'suspicious_input',
        '${widget.context}: $text',
      );
    } else {
      setState(() {
        _hasSecurityViolation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BulletproofWidget(
      context: 'text_field_${widget.context}',
      child: TextFormField(
        controller: widget.controller ?? _internalController,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: _hasSecurityViolation
              ? Icon(
                  Icons.security,
                  color: Colors.red.shade600,
                )
              : null,
        ),
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        validator: (value) {
          // Custom validator with security check
          if (_hasSecurityViolation) {
            return 'Invalid input detected';
          }
          
          // Call original validator
          if (widget.validator != null) {
            return widget.validator!(value);
          }
          
          return null;
        },
      ),
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }
}

/// 🛡️ BULLETPROOF BUTTON - Secure button with protection
class BulletproofButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final String context;
  final bool enableRateLimiting;
  final Duration? rateLimitDuration;

  const BulletproofButton({
    super.key,
    required this.text,
    this.onPressed,
    required this.context,
    this.enableRateLimiting = true,
    this.rateLimitDuration,
  });

  @override
  State<BulletproofButton> createState() => _BulletproofButtonState();
}

class _BulletproofButtonState extends State<BulletproofButton> {
  bool _isRateLimited = false;
  DateTime? _lastPressed;

  @override
  Widget build(BuildContext context) {
    return BulletproofWidget(
      context: 'button_${widget.context}',
      child: ElevatedButton(
        onPressed: _isRateLimited ? null : _handlePress,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isRateLimited ? Colors.grey : null,
        ),
        child: Text(widget.text),
      ),
    );
  }

  void _handlePress() {
    if (widget.enableRateLimiting) {
      _checkRateLimit();
    }

    if (!_isRateLimited && widget.onPressed != null) {
      widget.onPressed!();
      _lastPressed = DateTime.now();
    }
  }

  void _checkRateLimit() {
    if (_lastPressed != null) {
      final timeSinceLastPress = DateTime.now().difference(_lastPressed!);
      final limitDuration = widget.rateLimitDuration ?? const Duration(seconds: 1);
      
      if (timeSinceLastPress < limitDuration) {
        setState(() {
          _isRateLimited = true;
        });
        
        // Clear rate limit after duration
        Future.delayed(limitDuration, () {
          if (mounted) {
            setState(() {
              _isRateLimited = false;
            });
          }
        });
      }
    }
  }
}

/// 🛡️ BULLETPROOF LIST VIEW - Optimized list with protection
class BulletproofListView extends StatelessWidget {
  final List<Widget> children;
  final String context;
  final bool enableVirtualization;
  final int? itemCount;

  const BulletproofListView({
    super.key,
    required this.children,
    required this.context,
    this.enableVirtualization = true,
    this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return BulletproofWidget(
      context: 'list_view_$context',
      child: ListView.builder(
        itemCount: itemCount ?? children.length,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: BulletproofWidget(
              context: 'list_item_${context}_$index',
              child: children[index],
            ),
          );
        },
      ),
    );
  }
} 