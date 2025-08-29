import 'package:flutter/material.dart';
import '../services/image_cleanup_service.dart';
import '../theme/admin_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ImageManagementSection extends StatefulWidget {
  const ImageManagementSection({Key? key}) : super(key: key);

  @override
  State<ImageManagementSection> createState() => _ImageManagementSectionState();
}

class _ImageManagementSectionState extends State<ImageManagementSection> {
  bool _isLoading = false;
  bool _isDeleting = false;
  int _deletionProgress = 0;
  Map<String, String> _deletionErrors = {};
  Map<String, dynamic> _storageStats = {};
  List<Map<String, dynamic>> _orphanedImages = [];
  String _selectedOrphanType = 'all';
  List<Map<String, dynamic>> _filteredOrphanedImages = [];

  String _normalizePath(String? raw) {
    final p = (raw ?? '').trim();
    if (p.isEmpty) return '';
    // Remove all leading slashes
    return p.replaceFirst(RegExp(r'^/+'), '');
  }

  @override
  void initState() {
    super.initState();
    _loadStorageStats();
  }

  void _updateFilteredImages() {
    if (_selectedOrphanType == 'all') {
      _filteredOrphanedImages = _orphanedImages;
    } else {
      _filteredOrphanedImages = _orphanedImages.where((img) {
        final path = _normalizePath(img['filePath'] as String?);
        switch (_selectedOrphanType) {
          case 'products':
            return path.startsWith('products/');
          case 'profiles':
            return path.startsWith('profile_images/');
          case 'stores':
            return path.startsWith('store_images/');
          case 'chat':
            return path.startsWith('chat_images/');
          case 'profile_videos':
            return path.startsWith('profile_videos/');
          case 'store_videos':
            return path.startsWith('store_videos/');
          case 'uncategorized':
            return !(path.startsWith('products/') ||
                     path.startsWith('profile_images/') ||
                     path.startsWith('store_images/') ||
                     path.startsWith('chat_images/') ||
                     path.startsWith('profile_videos/') ||
                     path.startsWith('store_videos/') ||
                     path.startsWith('kyc/'));
          default:
            return false;
        }
      }).toList();
    }
  }

  Future<void> _loadStorageStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await ImageCleanupService.getStorageStats();
      setState(() {
        _storageStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    }
  }

  Future<void> _findOrphanedImages() async {
    setState(() => _isLoading = true);
    try {
      final allOrphaned = <Map<String, dynamic>>[];
      
      // Get all types of orphaned media (images + videos)
      final productOrphans = await ImageCleanupService.findOrphanedProductImages();
      final profileOrphans = await ImageCleanupService.findOrphanedProfileImages();
      final storeOrphans = await ImageCleanupService.findOrphanedStoreImages();
      final chatOrphans = await ImageCleanupService.findOrphanedChatImages();
      final profileVideoOrphans = await ImageCleanupService.findOrphanedProfileVideos();
      final storeVideoOrphans = await ImageCleanupService.findOrphanedStoreVideos();
      final uncategorized = await ImageCleanupService.findUncategorizedMedia();
      
      allOrphaned.addAll(productOrphans);
      allOrphaned.addAll(profileOrphans);
      allOrphaned.addAll(storeOrphans);
      allOrphaned.addAll(chatOrphans);
      allOrphaned.addAll(profileVideoOrphans);
      allOrphaned.addAll(storeVideoOrphans);
      allOrphaned.addAll(uncategorized);
      
      if (mounted) {
        setState(() {
          _orphanedImages = allOrphaned;
          _updateFilteredImages();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding orphaned images: $e')),
        );
      }
    }
  }

  Future<void> _deleteOrphanedImages() async {
    if (_filteredOrphanedImages.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Orphaned Images'),
        content: Text('Are you sure you want to delete ${_filteredOrphanedImages.length} orphaned images? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
      _deletionProgress = 0;
      _deletionErrors = <String, String>{};
    });

    final fileIds = _filteredOrphanedImages.map((img) => img['fileId'] as String).toList();
    final results = await ImageCleanupService.deleteImages(fileIds);

    // Track failed deletions for retry
    final failedDeletions = <String>[];
    for (final entry in results.entries) {
      if (entry.value) {
        _deletionProgress++;
      } else {
        failedDeletions.add(entry.key);
        // Try to get error message from the service
        _deletionErrors[entry.key] = 'Deletion failed - check console for details';
      }
    }

    setState(() {
      _isDeleting = false;
      _deletionProgress = 0;
    });

    // Show results
    final successCount = results.values.where((success) => success).length;
    final failureCount = results.values.where((success) => !success).length;

    if (failureCount > 0) {
      // Show detailed error dialog with retry option
      final shouldRetry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Deletion Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Successfully deleted: $successCount images'),
              SizedBox(height: 8),
              Text('❌ Failed to delete: $failureCount images'),
              if (_deletionErrors.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Failed deletions:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ..._deletionErrors.entries.take(5).map((e) => 
                  Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('• ${e.key}: ${e.value}', style: TextStyle(fontSize: 12)),
                  )
                ),
                if (_deletionErrors.length > 5)
                  Text('... and ${_deletionErrors.length - 5} more', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
              SizedBox(height: 16),
              Text('Would you like to retry the failed deletions?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: Text('Retry Failed'),
            ),
          ],
        ),
      );

      if (shouldRetry == true && failedDeletions.isNotEmpty) {
        // Retry failed deletions
        await _retryFailedDeletions(failedDeletions);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Successfully deleted $successCount orphaned images'),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Refresh the orphaned images list
    await _findOrphanedImages();
  }

  Future<void> _retryFailedDeletions(List<String> failedFileIds) async {
    setState(() {
      _isDeleting = true;
      _deletionProgress = 0;
      _deletionErrors.clear();
    });

    final results = await ImageCleanupService.deleteImages(failedFileIds);
    
    final successCount = results.values.where((success) => success).length;
    final failureCount = results.values.where((success) => !success).length;

    setState(() {
      _isDeleting = false;
      _deletionProgress = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Retry complete: $successCount succeeded, $failureCount still failed'),
        backgroundColor: failureCount > 0 ? Colors.orange : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    // Refresh the orphaned images list
    await _findOrphanedImages();
  }

  Map<String, int> _getOrphanCountsByType() {
    final counts = <String, int>{};
    counts['all'] = _orphanedImages.length;
    counts['products'] = _orphanedImages.where((img) {
      final path = _normalizePath(img['filePath'] as String?);
      return path.startsWith('products/');
    }).length;
    counts['profiles'] = _orphanedImages.where((img) {
      final path = _normalizePath(img['filePath'] as String?);
      return path.startsWith('profile_images/');
    }).length;
    counts['stores'] = _orphanedImages.where((img) {
      final path = _normalizePath(img['filePath'] as String?);
      return path.startsWith('store_images/');
    }).length;
    counts['chat'] = _orphanedImages.where((img) {
      final path = _normalizePath(img['filePath'] as String?);
      return path.startsWith('chat_images/');
    }).length;
    counts['profile_videos'] = _orphanedImages.where((img) {
      final path = _normalizePath(img['filePath'] as String?);
      return path.startsWith('profile_videos/');
    }).length;
    counts['store_videos'] = _orphanedImages.where((img) {
      final path = _normalizePath(img['filePath'] as String?);
      return path.startsWith('store_videos/');
    }).length;
    counts['uncategorized'] = _orphanedImages.where((img) {
      final path = _normalizePath(img['filePath'] as String?);
      final known = path.startsWith('products/') ||
                    path.startsWith('profile_images/') ||
                    path.startsWith('store_images/') ||
                    path.startsWith('chat_images/') ||
                    path.startsWith('profile_videos/') ||
                    path.startsWith('store_videos/') ||
                    path.startsWith('kyc/');
      return !known;
    }).length;
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final orphanCounts = _getOrphanCountsByType();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Image Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AdminTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 24),
          
          // Storage Stats
          if (_storageStats != null) ...[
            _buildStatsGrid(),
            const SizedBox(height: 24),
          ],
          
          // Action Buttons
          _buildActionButtons(),
          const SizedBox(height: 24),
          
          // Orphaned Images Section
          if (_orphanedImages.isNotEmpty) ...[
            _buildOrphanedImagesSection(orphanCounts),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final int orphanedCount = _orphanedImages.length;
    final int orphanedBytes = _orphanedImages.fold<int>(0, (sum, img) => sum + ((img['size'] as int?) ?? 0));
    String _formatMb(num mb) => '${mb.toStringAsFixed(1)} MB';

    final String totalSizeLabel = () {
      final totalSizeMbStr = _storageStats!['totalSizeMB'];
      if (totalSizeMbStr is String && totalSizeMbStr.isNotEmpty) {
        return '$totalSizeMbStr MB';
      }
      final totalBytes = _storageStats!['totalSizeBytes'];
      if (totalBytes is int && totalBytes > 0) {
        return _formatMb(totalBytes / (1024 * 1024));
      }
      return '0 MB';
    }();

    final String orphanedSizeLabel = _formatMb(orphanedBytes / (1024 * 1024));

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.8,
      children: [
        _buildStatCard(
          'Total Images',
          _storageStats!['totalImages']?.toString() ?? '0',
          Icons.image,
          AdminTheme.deepTeal,
        ),
        _buildStatCard(
          'Total Size',
          totalSizeLabel,
          Icons.storage,
          AdminTheme.success,
        ),
        _buildStatCard(
          'Orphaned Images',
          orphanedCount.toString(),
          Icons.delete_outline,
          AdminTheme.warning,
        ),
        _buildStatCard(
          'Orphaned Size',
          orphanedSizeLabel,
          Icons.delete_sweep,
          AdminTheme.error,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _findOrphanedImages,
          icon: const Icon(Icons.search),
          label: const Text('Find Orphaned Images'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.deepTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _syncImageAssets,
          icon: const Icon(Icons.sync),
          label: const Text('Sync Image Assets'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildOrphanedImagesSection(Map<String, int> orphanCounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Orphaned Images (${_filteredOrphanedImages.length})',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AdminTheme.warning,
              ),
            ),
            const Spacer(),
            if (_filteredOrphanedImages.isNotEmpty)
              ElevatedButton(
                onPressed: _filteredOrphanedImages.isEmpty || _isDeleting ? null : _deleteOrphanedImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _isDeleting 
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Deleting...'),
                      ],
                    )
                  : Text('Delete ${_filteredOrphanedImages.length}'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Filter Chips
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: Text('All (${orphanCounts['all']})'),
              selected: _selectedOrphanType == 'all',
              onSelected: (selected) {
                setState(() {
                  _selectedOrphanType = 'all';
                  _updateFilteredImages();
                });
              },
              selectedColor: AdminTheme.deepTeal.withOpacity(0.2),
            ),
            FilterChip(
              label: Text('Products (${orphanCounts['products']})'),
              selected: _selectedOrphanType == 'products',
              onSelected: (selected) {
                setState(() {
                  _selectedOrphanType = 'products';
                  _updateFilteredImages();
                });
              },
              selectedColor: AdminTheme.deepTeal.withOpacity(0.2),
            ),
            FilterChip(
              label: Text('Profile Images (${orphanCounts['profiles']})'),
              selected: _selectedOrphanType == 'profiles',
              onSelected: (selected) {
                setState(() {
                  _selectedOrphanType = 'profiles';
                  _updateFilteredImages();
                });
              },
              selectedColor: AdminTheme.deepTeal.withOpacity(0.2),
            ),
            FilterChip(
              label: Text('Profile Videos (${orphanCounts['profile_videos']})'),
              selected: _selectedOrphanType == 'profile_videos',
              onSelected: (selected) {
                setState(() {
                  _selectedOrphanType = 'profile_videos';
                  _updateFilteredImages();
                });
              },
              selectedColor: AdminTheme.deepTeal.withOpacity(0.2),
            ),
            FilterChip(
              label: Text('Store Images (${orphanCounts['stores']})'),
              selected: _selectedOrphanType == 'stores',
              onSelected: (selected) {
                setState(() {
                  _selectedOrphanType = 'stores';
                  _updateFilteredImages();
                });
              },
              selectedColor: AdminTheme.deepTeal.withOpacity(0.2),
            ),
            FilterChip(
              label: Text('Store Videos (${orphanCounts['store_videos']})'),
              selected: _selectedOrphanType == 'store_videos',
              onSelected: (selected) {
                setState(() {
                  _selectedOrphanType = 'store_videos';
                  _updateFilteredImages();
                });
              },
              selectedColor: AdminTheme.deepTeal.withOpacity(0.2),
            ),
            FilterChip(
              label: Text('Chat Images (${orphanCounts['chat']})'),
              selected: _selectedOrphanType == 'chat',
              onSelected: (selected) {
                setState(() {
                  _selectedOrphanType = 'chat';
                  _updateFilteredImages();
                });
              },
              selectedColor: AdminTheme.deepTeal.withOpacity(0.2),
            ),
            FilterChip(
              label: Text('Uncategorized (${orphanCounts['uncategorized']})'),
              selected: _selectedOrphanType == 'uncategorized',
              onSelected: (selected) {
                setState(() {
                  _selectedOrphanType = 'uncategorized';
                  _updateFilteredImages();
                });
              },
              selectedColor: AdminTheme.deepTeal.withOpacity(0.2),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Images Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: _filteredOrphanedImages.length,
          itemBuilder: (context, index) {
            final image = _filteredOrphanedImages[index];
            return _buildImageCard(image);
          },
        ),
      ],
    );
  }

  Widget _buildImageCard(Map<String, dynamic> image) {
    final url = image['url'] as String? ?? '';
    final name = image['name'] as String? ?? 'Unknown';
    final path = image['filePath'] as String? ?? '';
    final size = image['size'] as int? ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: url.isNotEmpty
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 32),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, size: 32),
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  path,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${(size / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncImageAssets() async {
    setState(() => _isLoading = true);
    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('syncImageAssetsNow').call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync completed: ${result.data['synced']} images synced')),
        );
      }
      
      // Refresh data
      await _loadStorageStats();
      await _findOrphanedImages();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing images: $e')),
        );
      }
    }
  }

  Future<void> _testBatchDelete() async {
    setState(() => _isLoading = true);
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final result = await functions.httpsCallable('testBatchDelete').call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test completed: ${result.data['message']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error testing delete function: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
