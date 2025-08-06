import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/performance_utils.dart';

class CacheManagementScreen extends StatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends State<CacheManagementScreen> {
  Map<String, dynamic> _cacheStats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  void _loadCacheStats() {
    setState(() {
      _cacheStats = PerformanceUtils.getCacheStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        title: const Text('Cache Management'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCacheStats,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCacheStatsCard(),
            const SizedBox(height: 16),
            _buildCacheActionsCard(),
            const SizedBox(height: 16),
            _buildCacheInfoCard(),
            const SizedBox(height: 16),
            _buildPerformanceBenefitsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStatsCard() {
    final currentSize = _cacheStats['currentSize'] ?? 0;
    final maxSize = _cacheStats['maximumSize'] ?? 2000;
    final usagePercent = _cacheStats['usagePercent'] ?? 0;
    final maxMemoryMB = _cacheStats['maxMemoryMB'] ?? 200;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cache Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.deepTeal,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Images Cached', '$currentSize / $maxSize'),
            _buildStatRow('Memory Usage', '${usagePercent}%'),
            _buildStatRow('Memory Limit', '${maxMemoryMB} MB'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: usagePercent / 100,
              backgroundColor: AppTheme.cloud,
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePercent > 80 ? AppTheme.warning : AppTheme.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              usagePercent > 80 
                ? '⚠️ Cache usage is high'
                : '✅ Cache usage is healthy',
              style: TextStyle(
                color: usagePercent > 80 ? AppTheme.warning : AppTheme.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cache Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.deepTeal,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _optimizeCache,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Optimize Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: AppTheme.angel,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _clearCache,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: AppTheme.angel,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _emergencyCleanup,
                    icon: const Icon(Icons.emergency),
                    label: const Text('Emergency Cleanup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: AppTheme.angel,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _restoreLargeCache,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore Large Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.info,
                      foregroundColor: AppTheme.angel,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cache Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.deepTeal,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Large Cache Support', '✅ Enabled'),
            _buildInfoRow('Max Images', '2,000 images'),
            _buildInfoRow('Max Memory', '200 MB'),
            _buildInfoRow('Auto Cleanup', 'Every 3 minutes'),
            _buildInfoRow('Cleanup Threshold', '1,800 images (90%)'),
            _buildInfoRow('Smart Cleanup', '✅ Enabled'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Large Cache Benefits:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Faster image loading\n'
                    '• Better user experience\n'
                    '• Reduced network usage\n'
                    '• Smart memory management',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.deepTeal,
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

  Widget _buildPerformanceBenefitsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Benefits',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.deepTeal,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Faster Image Loading', '✅ Enabled'),
            _buildInfoRow('Better User Experience', '✅ Enabled'),
            _buildInfoRow('Reduced Network Usage', '✅ Enabled'),
            _buildInfoRow('Smart Memory Management', '✅ Enabled'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.info.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚀 Performance Benefits:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.info,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Images are loaded instantly from cache\n'
                    '• No more waiting for network requests\n'
                    '• Reduced data transfer and bandwidth usage\n'
                    '• Smoother scrolling and navigation',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.deepTeal,
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

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: AppTheme.deepTeal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _optimizeCache() async {
    setState(() => _isLoading = true);
    
    try {
      PerformanceUtils.optimizeMemoryUsage();
      _loadCacheStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache optimized successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error optimizing cache: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);
    
    try {
      PerformanceUtils.clearImageCache();
      _loadCacheStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _emergencyCleanup() async {
    setState(() => _isLoading = true);
    
    try {
      PerformanceUtils.emergencyCleanup();
      _loadCacheStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency cleanup completed!'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during emergency cleanup: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreLargeCache() async {
    setState(() => _isLoading = true);
    
    try {
      PerformanceUtils.restoreLargeCacheSize();
      _loadCacheStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Large cache restored!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring large cache: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
} 