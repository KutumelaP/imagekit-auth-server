import 'dart:async';
import 'dart:developer' as developer;

/// Performance monitoring service to track app performance and identify bottlenecks
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, List<Duration>> _measurements = {};
  static final Map<String, int> _operationCounts = {};
  static final List<String> _performanceLog = [];
  
  // Performance thresholds
  static const Duration _slowThreshold = Duration(milliseconds: 1000);
  static const Duration _verySlowThreshold = Duration(milliseconds: 3000);
  static const int _maxLogEntries = 100;
  
  /// Start timing an operation
  static void startTimer(String name) {
    _timers[name] = Stopwatch()..start();
    _operationCounts[name] = (_operationCounts[name] ?? 0) + 1;
    
    developer.log('⏱️ Started timer: $name', name: 'PerformanceMonitor');
  }
  
  /// End timing an operation and log the result
  static void endTimer(String name) {
    final timer = _timers[name];
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsed;
      
      // Store measurement for statistics
      if (!_measurements.containsKey(name)) {
        _measurements[name] = [];
      }
      _measurements[name]!.add(duration);
      
      // Log performance
      _logPerformance(name, duration);
      
      // Clean up
      _timers.remove(name);
    }
  }
  
  /// Log performance with appropriate level based on duration
  static void _logPerformance(String name, Duration duration) {
    final message = '⏱️ $name took ${duration.inMilliseconds}ms';
    
    if (duration > _verySlowThreshold) {
      developer.log('🚨 VERY SLOW: $message', name: 'PerformanceMonitor');
      _addToLog('🚨 VERY SLOW: $message');
    } else if (duration > _slowThreshold) {
      developer.log('⚠️ SLOW: $message', name: 'PerformanceMonitor');
      _addToLog('⚠️ SLOW: $message');
    } else {
      developer.log(message, name: 'PerformanceMonitor');
      _addToLog(message);
    }
  }
  
  /// Add entry to performance log
  static void _addToLog(String entry) {
    _performanceLog.add('${DateTime.now().toIso8601String()}: $entry');
    
    // Keep log size manageable
    if (_performanceLog.length > _maxLogEntries) {
      _performanceLog.removeRange(0, _performanceLog.length - _maxLogEntries);
    }
  }
  
  /// Get performance statistics for an operation
  static Map<String, dynamic> getOperationStats(String name) {
    final measurements = _measurements[name];
    if (measurements == null || measurements.isEmpty) {
      return {
        'name': name,
        'count': 0,
        'average': 0,
        'min': 0,
        'max': 0,
        'total': 0,
      };
    }
    
    final total = measurements.fold<Duration>(
      Duration.zero,
      (sum, duration) => sum + duration,
    );
    
    final average = total.inMilliseconds / measurements.length;
    final min = measurements.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
    final max = measurements.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
    
    return {
      'name': name,
      'count': measurements.length,
      'average': average.round(),
      'min': min,
      'max': max,
      'total': total.inMilliseconds,
    };
  }
  
  /// Get all performance statistics
  static Map<String, Map<String, dynamic>> getAllStats() {
    final stats = <String, Map<String, dynamic>>{};
    
    for (final name in _measurements.keys) {
      stats[name] = getOperationStats(name);
    }
    
    return stats;
  }
  
  /// Get performance log
  static List<String> getPerformanceLog() {
    return List.from(_performanceLog);
  }
  
  /// Clear performance data
  static void clearData() {
    _timers.clear();
    _measurements.clear();
    _operationCounts.clear();
    _performanceLog.clear();
  }
  
  /// Get summary of slow operations
  static List<Map<String, dynamic>> getSlowOperations() {
    final slowOps = <Map<String, dynamic>>[];
    
    for (final entry in _measurements.entries) {
      final name = entry.key;
      final measurements = entry.value;
      
      final slowCount = measurements.where((d) => d > _slowThreshold).length;
      final verySlowCount = measurements.where((d) => d > _verySlowThreshold).length;
      
      if (slowCount > 0) {
        slowOps.add({
          'name': name,
          'totalCount': measurements.length,
          'slowCount': slowCount,
          'verySlowCount': verySlowCount,
          'slowPercentage': (slowCount / measurements.length * 100).round(),
        });
      }
    }
    
    // Sort by slow percentage (descending)
    slowOps.sort((a, b) => (b['slowPercentage'] as int).compareTo(a['slowPercentage'] as int));
    
    return slowOps;
  }
  
  /// Monitor a function execution
  static Future<T> monitor<T>(String name, Future<T> Function() operation) async {
    startTimer(name);
    try {
      final result = await operation();
      return result;
    } finally {
      endTimer(name);
    }
  }
  
  /// Monitor a synchronous function execution
  static T monitorSync<T>(String name, T Function() operation) {
    startTimer(name);
    try {
      final result = operation();
      return result;
    } finally {
      endTimer(name);
    }
  }
  
  /// Check if any timers are still running (for debugging)
  static List<String> getActiveTimers() {
    return _timers.keys.toList();
  }
  
  /// Force stop all active timers (for cleanup)
  static void stopAllTimers() {
    for (final entry in _timers.entries) {
      developer.log('⚠️ Force stopping timer: ${entry.key}', name: 'PerformanceMonitor');
      entry.value.stop();
    }
    _timers.clear();
  }
} 