import 'package:flutter/material.dart';
import 'package:marketplace_app/theme/app_theme.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;
  final VoidCallback? onError;

  const ErrorBoundary({
    Key? key,
    required this.child,
    this.errorBuilder,
    this.onError,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    // Set up error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      setState(() {
        _error = details.exception;
        _stackTrace = details.stack;
      });
      widget.onError?.call();
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!, _stackTrace) ??
          _buildDefaultErrorWidget();
    }

    return widget.child;
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.primaryRed,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We encountered an unexpected error. Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkGrey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _stackTrace = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
              TextButton(
                onPressed: () {
                  // Report error to analytics
                  print('Error reported: $_error');
                },
                child: Text(
                  'Report Issue',
                  style: TextStyle(color: AppTheme.primaryRed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Convenience widget for wrapping error-prone content
class SafeWidget extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const SafeWidget({
    Key? key,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: child,
      errorBuilder: (error, stackTrace) {
        return fallback ??
            Container(
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: Text(
                  'Content unavailable',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
      },
    );
  }
} 