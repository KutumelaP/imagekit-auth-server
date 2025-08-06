import 'package:flutter/material.dart';
import '../utils/advanced_memory_optimizer.dart';

class PerformanceMonitor extends StatefulWidget {
  @override
  _PerformanceMonitorState createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  Map<String, dynamic> _stats = {};
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateStats();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateStats();
    });
  }

  void _updateStats() {
    setState(() {
      _stats = AdvancedMemoryOptimizer.getComprehensiveStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Performance Monitor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildStatRow(
              'Image Cache',
              '${_stats['imageCache']?['currentSize'] ?? 0}/${_stats['imageCache']?['maximumSize'] ?? 0}',
              '${_stats['imageCache']?['usagePercent'] ?? 0}%',
              _getUsageColor(_stats['imageCache']?['usagePercent'] ?? 0),
            ),
            _buildStatRow(
              'Active Streams',
              '${_stats['streams']?['activeCount'] ?? 0}',
              'streams',
              Colors.green,
            ),
            _buildStatRow(
              'Data Cache',
              '${_stats['dataCache']?['entries'] ?? 0}',
              'entries',
              Colors.orange,
            ),
            _buildStatRow(
              'Debounce Timers',
              '${_stats['system']?['debounceTimers'] ?? 0}',
              'active',
              Colors.purple,
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _stats['system']?['lowMemoryMode'] == true 
                    ? Colors.red.withOpacity(0.1) 
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _stats['system']?['lowMemoryMode'] == true 
                        ? Icons.warning 
                        : Icons.check_circle,
                    color: _stats['system']?['lowMemoryMode'] == true 
                        ? Colors.red 
                        : Colors.green,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _stats['system']?['lowMemoryMode'] == true 
                        ? 'Low Memory Mode Active'
                        : 'Memory Usage Normal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, String unit, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getUsageColor(int usagePercent) {
    if (usagePercent > 80) return Colors.red;
    if (usagePercent > 60) return Colors.orange;
    return Colors.green;
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
} 