import 'package:flutter/material.dart';

class DebugOverlay extends StatefulWidget {
  final Widget child;
  
  const DebugOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  final List<String> _debugLogs = [];
  bool _isVisible = true;
  bool _isExpanded = false;

  void addLog(String message) {
    if (mounted) {
      setState(() {
        _debugLogs.add('${DateTime.now().toString().substring(11, 19)}: $message');
        // Keep only last 20 logs
        if (_debugLogs.length > 20) {
          _debugLogs.removeAt(0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible)
          Positioned(
            top: 50,
            right: 10,
            child: Container(
              width: _isExpanded ? 300 : 50,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with controls
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🐛 DEBUG',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isExpanded ? Icons.compress : Icons.expand,
                            color: Colors.white,
                            size: 16,
                          ),
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                          onPressed: () {
                            setState(() {
                              _isVisible = false;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Debug logs
                  if (_isExpanded)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _debugLogs.length,
                          itemBuilder: (context, index) {
                            final log = _debugLogs[_debugLogs.length - 1 - index];
                            Color logColor = Colors.white;
                            
                            if (log.contains('PUSH')) logColor = Colors.green;
                            else if (log.contains('POP')) logColor = Colors.orange;
                            else if (log.contains('REPLACE')) logColor = Colors.yellow;
                            else if (log.contains('REMOVE')) logColor = Colors.red;
                            else if (log.contains('Provider')) logColor = Colors.cyan;
                            else if (log.contains('ERROR')) logColor = Colors.red;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                log,
                                style: TextStyle(
                                  color: logColor,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // Collapsed view
                  if (!_isExpanded)
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${_debugLogs.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Show debug button if hidden
        if (!_isVisible)
          Positioned(
            top: 50,
            right: 10,
            child: FloatingActionButton.small(
              onPressed: () {
                setState(() {
                  _isVisible = true;
                });
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.bug_report, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// Global debug logger
class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  final List<Function(String)> _listeners = [];

  void addListener(Function(String) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(String) listener) {
    _listeners.remove(listener);
  }

  void log(String message) {
    print('🐛 DEBUG: $message');
    for (final listener in _listeners) {
      try {
        listener(message);
      } catch (e) {
        print('Error in debug listener: $e');
      }
    }
  }
}

