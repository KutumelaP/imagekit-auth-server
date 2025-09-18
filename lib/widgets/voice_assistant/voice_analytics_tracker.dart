import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Voice Analytics Data Model
class VoiceAnalyticsData {
  final String userId;
  final DateTime timestamp;
  final String command;
  final String language;
  final bool successful;
  final double responseTime;
  final String screen;
  final String category;

  VoiceAnalyticsData({
    required this.userId,
    required this.timestamp,
    required this.command,
    required this.language,
    required this.successful,
    required this.responseTime,
    required this.screen,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'command': command,
      'language': language,
      'successful': successful,
      'responseTime': responseTime,
      'screen': screen,
      'category': category,
    };
  }

  factory VoiceAnalyticsData.fromJson(Map<String, dynamic> json) {
    return VoiceAnalyticsData(
      userId: json['userId'],
      timestamp: DateTime.parse(json['timestamp']),
      command: json['command'],
      language: json['language'],
      successful: json['successful'],
      responseTime: json['responseTime'],
      screen: json['screen'],
      category: json['category'],
    );
  }
}

/// Voice Usage Statistics
class VoiceUsageStats {
  final int totalCommands;
  final int successfulCommands;
  final double successRate;
  final double averageResponseTime;
  final Map<String, int> commandFrequency;
  final Map<String, int> languageUsage;
  final Map<String, int> screenUsage;
  final DateTime lastUsed;

  VoiceUsageStats({
    required this.totalCommands,
    required this.successfulCommands,
    required this.successRate,
    required this.averageResponseTime,
    required this.commandFrequency,
    required this.languageUsage,
    required this.screenUsage,
    required this.lastUsed,
  });
}

/// Voice Analytics Tracker
class VoiceAnalyticsTracker {
  static final VoiceAnalyticsTracker _instance = VoiceAnalyticsTracker._internal();
  factory VoiceAnalyticsTracker() => _instance;
  VoiceAnalyticsTracker._internal();

  final List<VoiceAnalyticsData> _analyticsData = [];
  final StreamController<VoiceUsageStats> _statsController = StreamController<VoiceUsageStats>.broadcast();
  
  Timer? _saveTimer;
  bool _isEnabled = true;
  
  /// Enable/disable analytics tracking
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      _startPeriodicSave();
    } else {
      _stopPeriodicSave();
    }
  }

  /// Start periodic save timer
  void _startPeriodicSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _saveAnalyticsData();
    });
  }

  /// Stop periodic save timer
  void _stopPeriodicSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Track voice command usage
  Future<void> trackVoiceCommand({
    required String userId,
    required String command,
    required String language,
    required bool successful,
    required double responseTime,
    required String screen,
    String category = 'general',
  }) async {
    if (!_isEnabled) return;

    final data = VoiceAnalyticsData(
      userId: userId,
      timestamp: DateTime.now(),
      command: command,
      language: language,
      successful: successful,
      responseTime: responseTime,
      screen: screen,
      category: category,
    );

    _analyticsData.add(data);
    
    // Update statistics
    final stats = calculateUsageStats();
    _statsController.add(stats);
    
    if (kDebugMode) {
      print('📊 Voice Analytics: $command (${successful ? 'Success' : 'Failed'}) - ${responseTime}ms');
    }
  }

  /// Calculate usage statistics
  VoiceUsageStats calculateUsageStats() {
    if (_analyticsData.isEmpty) {
      return VoiceUsageStats(
        totalCommands: 0,
        successfulCommands: 0,
        successRate: 0.0,
        averageResponseTime: 0.0,
        commandFrequency: {},
        languageUsage: {},
        screenUsage: {},
        lastUsed: DateTime.now(),
      );
    }

    final totalCommands = _analyticsData.length;
    final successfulCommands = _analyticsData.where((d) => d.successful).length;
    final successRate = (successfulCommands / totalCommands) * 100;
    
    final totalResponseTime = _analyticsData.fold<double>(0, (sum, d) => sum + d.responseTime);
    final averageResponseTime = totalResponseTime / totalCommands;
    
    final commandFrequency = <String, int>{};
    final languageUsage = <String, int>{};
    final screenUsage = <String, int>{};
    
    for (final data in _analyticsData) {
      commandFrequency[data.command] = (commandFrequency[data.command] ?? 0) + 1;
      languageUsage[data.language] = (languageUsage[data.language] ?? 0) + 1;
      screenUsage[data.screen] = (screenUsage[data.screen] ?? 0) + 1;
    }
    
    final lastUsed = _analyticsData.map((d) => d.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);

    return VoiceUsageStats(
      totalCommands: totalCommands,
      successfulCommands: successfulCommands,
      successRate: successRate,
      averageResponseTime: averageResponseTime,
      commandFrequency: commandFrequency,
      languageUsage: languageUsage,
      screenUsage: screenUsage,
      lastUsed: lastUsed,
    );
  }

  /// Get usage statistics stream
  Stream<VoiceUsageStats> get statsStream => _statsController.stream;

  /// Get most used commands
  List<MapEntry<String, int>> getMostUsedCommands({int limit = 5}) {
    final stats = calculateUsageStats();
    final sorted = stats.commandFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  /// Get language preferences
  List<MapEntry<String, int>> getLanguagePreferences() {
    final stats = calculateUsageStats();
    final sorted = stats.languageUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  /// Get screen usage patterns
  List<MapEntry<String, int>> getScreenUsagePatterns() {
    final stats = calculateUsageStats();
    final sorted = stats.screenUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  /// Save analytics data to local storage
  Future<void> _saveAnalyticsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = _analyticsData.map((d) => d.toJson()).toList();
      await prefs.setString('voice_analytics_data', jsonEncode(jsonData));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving analytics data: $e');
      }
    }
  }

  /// Load analytics data from local storage
  Future<void> loadAnalyticsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('voice_analytics_data');
      
      if (jsonString != null) {
        final jsonData = jsonDecode(jsonString) as List;
        _analyticsData.clear();
        _analyticsData.addAll(
          jsonData.map((json) => VoiceAnalyticsData.fromJson(json)).toList()
        );
        
        if (kDebugMode) {
          print('📊 Loaded ${_analyticsData.length} analytics records');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading analytics data: $e');
      }
    }
  }

  /// Clear all analytics data
  Future<void> clearAnalyticsData() async {
    _analyticsData.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('voice_analytics_data');
    
    if (kDebugMode) {
      print('🗑️ Analytics data cleared');
    }
  }

  /// Export analytics data for analysis
  Map<String, dynamic> exportAnalyticsData() {
    final stats = calculateUsageStats();
    
    return {
      'summary': {
        'totalCommands': stats.totalCommands,
        'successfulCommands': stats.successfulCommands,
        'successRate': stats.successRate,
        'averageResponseTime': stats.averageResponseTime,
        'lastUsed': stats.lastUsed.toIso8601String(),
      },
      'commandFrequency': stats.commandFrequency,
      'languageUsage': stats.languageUsage,
      'screenUsage': stats.screenUsage,
      'rawData': _analyticsData.map((d) => d.toJson()).toList(),
    };
  }

  /// Build analytics dashboard widget
  Widget buildAnalyticsDashboard() {
    return StreamBuilder<VoiceUsageStats>(
      stream: statsStream,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? calculateUsageStats();
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voice Analytics Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Success Rate',
                      '${stats.successRate.toStringAsFixed(1)}%',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Most Used Commands
              const Text(
                'Most Used Commands',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...getMostUsedCommands().map((entry) => ListTile(
                leading: const Icon(Icons.trending_up),
                title: Text(entry.key),
                trailing: Text('${entry.value} times'),
              )),
              
              const SizedBox(height: 16),
              
              // Language Usage
              const Text(
                'Language Preferences',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...getLanguagePreferences().map((entry) => ListTile(
                leading: const Icon(Icons.language),
                title: Text(entry.key.toUpperCase()),
                trailing: Text('${entry.value} times'),
              )),
              
              const SizedBox(height: 16),
              
              // Export Button
              ElevatedButton.icon(
                onPressed: () {
                  final data = exportAnalyticsData();
                  if (kDebugMode) {
                    print('📊 Exported Analytics Data: $data');
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Export Data'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build stat card widget
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Dispose resources
  void dispose() {
    _stopPeriodicSave();
    _saveAnalyticsData();
    _statsController.close();
  }
}
