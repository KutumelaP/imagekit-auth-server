import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:admin_dashboard/theme/admin_theme.dart';

class AnalyticsDashboardSection extends StatefulWidget {
  const AnalyticsDashboardSection({super.key});

  @override
  State<AnalyticsDashboardSection> createState() => _AnalyticsDashboardSectionState();
}

class _AnalyticsDashboardSectionState extends State<AnalyticsDashboardSection> {
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};
  List<Map<String, dynamic>> _recentEvents = [];
  Map<String, int> _eventCounts = {};
  Map<String, int> _userActivity = {};

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get analytics summary
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      
      final snapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final events = snapshot.docs;
      
      // Process analytics data
      final eventCounts = <String, int>{};
      final userActivity = <String, int>{};
      final recentEvents = <Map<String, dynamic>>[];

      for (final doc in events) {
        final data = doc.data();
        final eventName = data['event_name'] as String? ?? 'unknown';
        final userId = data['user_id'] as String? ?? 'anonymous';
        final parameters = data['parameters'] as Map<String, dynamic>? ?? {};
        final timestamp = data['timestamp'] as Timestamp?;

        // Count events
        eventCounts[eventName] = (eventCounts[eventName] ?? 0) + 1;
        userActivity[userId] = (userActivity[userId] ?? 0) + 1;

        // Add to recent events
        recentEvents.add({
          'id': doc.id,
          'event_name': eventName,
          'user_id': userId,
          'parameters': parameters,
          'timestamp': timestamp,
        });
      }

      setState(() {
        _analyticsData = {
          'total_events': events.length,
          'unique_users': userActivity.length,
          'period': 'last_24_hours',
        };
        _eventCounts = eventCounts;
        _userActivity = userActivity;
        _recentEvents = recentEvents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: AdminTheme.deepTeal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewCards(),
                  const SizedBox(height: 24),
                  _buildEventBreakdown(),
                  const SizedBox(height: 24),
                  _buildRecentEvents(),
                  const SizedBox(height: 24),
                  _buildUserActivity(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMetricCard(
          'Total Events',
          _analyticsData['total_events']?.toString() ?? '0',
          Icons.analytics,
          AdminTheme.deepTeal,
        ),
        _buildMetricCard(
          'Unique Users',
          _analyticsData['unique_users']?.toString() ?? '0',
          Icons.people,
          AdminTheme.success,
        ),
        _buildMetricCard(
          'Period',
          _analyticsData['period'] ?? 'N/A',
          Icons.schedule,
          AdminTheme.warning,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventBreakdown() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: AdminTheme.deepTeal),
                const SizedBox(width: 8),
                const Text(
                  'Event Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._eventCounts.entries.map((entry) {
              final percentage = _analyticsData['total_events'] > 0
                  ? (entry.value / _analyticsData['total_events'] * 100).round()
                  : 0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatEventName(entry.key),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        entry.value.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '$percentage%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AdminTheme.deepTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEvents() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AdminTheme.deepTeal),
                const SizedBox(width: 8),
                const Text(
                  'Recent Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _recentEvents.length,
                itemBuilder: (context, index) {
                  final event = _recentEvents[index];
                  final timestamp = event['timestamp'] as Timestamp?;
                  final timeAgo = timestamp != null
                      ? _getTimeAgo(timestamp.toDate())
                      : 'Unknown';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AdminTheme.deepTeal,
                      child: Icon(
                        _getEventIcon(event['event_name']),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      _formatEventName(event['event_name']),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'User: ${event['user_id']} • $timeAgo',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => _showEventDetails(event),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActivity() {
    final sortedUsers = _userActivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: AdminTheme.deepTeal),
                const SizedBox(width: 8),
                const Text(
                  'Most Active Users',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedUsers.take(10).map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key == 'anonymous' ? 'Anonymous User' : entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${entry.value} events',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  String _formatEventName(String eventName) {
    return eventName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  IconData _getEventIcon(String eventName) {
    switch (eventName) {
      case 'user_login':
        return Icons.login;
      case 'user_registration':
        return Icons.person_add;
      case 'product_view':
        return Icons.visibility;
      case 'search':
        return Icons.search;
      case 'add_to_cart':
        return Icons.shopping_cart;
      case 'purchase':
        return Icons.payment;
      case 'chat_message_sent':
        return Icons.chat;
      case 'chat_initiated':
        return Icons.chat_bubble;
      case 'performance':
        return Icons.speed;
      case 'error':
        return Icons.error;
      case 'engagement':
        return Icons.touch_app;
      case 'session_start':
        return Icons.play_arrow;
      case 'session_end':
        return Icons.stop;
      case 'profile_update':
        return Icons.edit;
      case 'notification_interaction':
        return Icons.notifications;
      default:
        return Icons.event;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showEventDetails(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_formatEventName(event['event_name'])),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('User ID: ${event['user_id']}'),
              const SizedBox(height: 8),
              Text('Event ID: ${event['id']}'),
              const SizedBox(height: 8),
              Text('Timestamp: ${event['timestamp']?.toDate().toString() ?? 'Unknown'}'),
              const SizedBox(height: 8),
              const Text('Parameters:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...(event['parameters'] as Map<String, dynamic>).entries.map(
                (entry) => Text('  ${entry.key}: ${entry.value}'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 