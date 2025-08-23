import 'package:flutter/material.dart';
import '../services/image_cleanup_service.dart';
import '../theme/admin_theme.dart';

class ImageManagementSection extends StatefulWidget {
  const ImageManagementSection({Key? key}) : super(key: key);

  @override
  State<ImageManagementSection> createState() => _ImageManagementSectionState();
}

class _ImageManagementSectionState extends State<ImageManagementSection> {
  bool _isLoading = false;
  Map<String, dynamic> _storageStats = {};
  List<Map<String, dynamic>> _orphanedImages = [];
  Map<String, int> _cleanupResults = {};
  
  @override
  void initState() {
    super.initState();
    _loadStorageStats();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading storage stats: $e')),
      );
    }
  }
  
  Future<void> _findOrphanedImages() async {
    setState(() => _isLoading = true);
    try {
      final orphanedProducts = await ImageCleanupService.findOrphanedProductImages();
      final orphanedProfiles = await ImageCleanupService.findOrphanedProfileImages();
      final orphanedStores = await ImageCleanupService.findOrphanedStoreImages();
      final orphanedChats = await ImageCleanupService.findOrphanedChatImages();
      
      setState(() {
        _orphanedImages = [
          ...orphanedProducts.map((img) => {...img, 'type': 'Product'}),
          ...orphanedProfiles.map((img) => {...img, 'type': 'Profile'}),
          ...orphanedStores.map((img) => {...img, 'type': 'Store'}),
          ...orphanedChats.map((img) => {...img, 'type': 'Chat'}),
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding orphaned images: $e')),
      );
    }
  }
  
  Future<void> _cleanupOrphanedImages() async {
    setState(() => _isLoading = true);
    try {
      final results = await ImageCleanupService.cleanupOrphanedImages();
      setState(() {
        _cleanupResults = results;
        _isLoading = false;
      });
      
      // Reload stats after cleanup
      await _loadStorageStats();
      await _findOrphanedImages();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleanup completed: ${results.values.fold(0, (sum, count) => sum + count)} images removed'),
          backgroundColor: AdminTheme.success,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during cleanup: $e')),
      );
    }
  }
  
  Future<void> _deleteSpecificImage(String fileId) async {
    try {
      final success = await ImageCleanupService.deleteImage(fileId);
      if (success) {
        setState(() {
          _orphanedImages.removeWhere((img) => img['fileId'] == fileId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete image')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting image: $e')),
      );
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminTheme.whisper,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.image, size: 32, color: AdminTheme.deepTeal),
                const SizedBox(width: 16),
                Text(
                  'Image Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AdminTheme.deepTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Storage Statistics
            _buildStorageStatsCard(),
            const SizedBox(height: 24),
            
            // Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 24),
            
            // Cleanup Results
            if (_cleanupResults.isNotEmpty) _buildCleanupResultsCard(),
            if (_cleanupResults.isNotEmpty) const SizedBox(height: 24),
            
            // Orphaned Images List
            if (_orphanedImages.isNotEmpty) _buildOrphanedImagesCard(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStorageStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, color: AdminTheme.deepTeal),
              const SizedBox(width: 12),
              Text(
                'Storage Statistics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_storageStats.isEmpty)
            const Text('No storage data available')
          else
            _buildStorageStatsGrid(),
        ],
      ),
    );
  }
  
  Widget _buildStorageStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        _buildStatItem(
          'Total Images',
          '${_storageStats['totalImages'] ?? 0}',
          Icons.image,
          AdminTheme.info,
        ),
        _buildStatItem(
          'Total Size',
          '${_storageStats['totalSizeMB'] ?? '0'} MB',
          Icons.storage,
          AdminTheme.warning,
        ),
        _buildStatItem(
          'Orphaned Images',
          '${_orphanedImages.length}',
          Icons.delete_sweep,
          AdminTheme.error,
        ),
      ],
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _loadStorageStats,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh Stats'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _findOrphanedImages,
          icon: const Icon(Icons.search),
          label: const Text('Find Orphaned Images'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.warning,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _isLoading || _orphanedImages.isEmpty ? null : _cleanupOrphanedImages,
          icon: const Icon(Icons.cleaning_services),
          label: const Text('Cleanup All'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCleanupResultsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AdminTheme.success),
              const SizedBox(width: 12),
              Text(
                'Cleanup Results',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _cleanupResults.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AdminTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminTheme.success.withOpacity(0.3)),
                ),
                child: Text(
                  '${entry.key}: ${entry.value} deleted',
                  style: TextStyle(
                    color: AdminTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOrphanedImagesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delete_sweep, color: AdminTheme.error),
              const SizedBox(width: 12),
              Text(
                'Orphaned Images (${_orphanedImages.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: _orphanedImages.length,
              itemBuilder: (context, index) {
                final image = _orphanedImages[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AdminTheme.angel,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.image,
                        color: AdminTheme.deepTeal,
                      ),
                    ),
                    title: Text(
                      image['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type: ${image['type']}'),
                        Text('Size: ${_formatFileSize(image['size'] ?? 0)}'),
                        Text('Path: ${image['filePath'] ?? 'Unknown'}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: AdminTheme.error),
                      onPressed: () => _deleteSpecificImage(image['fileId']),
                      tooltip: 'Delete this image',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
