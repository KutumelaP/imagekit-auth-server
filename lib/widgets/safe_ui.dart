import 'package:flutter/material.dart';

class SafeUI {
  static Widget safeWidget(Widget child, {Widget? fallback}) {
    return ErrorBoundary(
      child: child,
      fallback: fallback ?? const Center(
        child: Text('Something went wrong'),
      ),
    );
  }

  static Widget safeBuilder(
    BuildContext context,
    Widget Function(BuildContext) builder, {
    Widget? fallback,
  }) {
    try {
      return builder(context);
    } catch (e) {
      return fallback ?? 
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e'),
            ],
          ),
        );
    }
  }

  static Widget safeAsyncBuilder<T>({
    required Future<T> future,
    required Widget Function(BuildContext, T) builder,
    Widget? loading,
    Widget? error,
  }) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ?? const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return error ?? 
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
        }
        
        if (snapshot.hasData) {
          return builder(context, snapshot.data as T);
        }
        
        return const Center(child: Text('No data available'));
      },
    );
  }
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;

  const ErrorBoundary({
    Key? key,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? 
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Something went wrong'),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text('Error: $_error'),
              ],
            ],
          ),
        );
    }

    return widget.child;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }
} 