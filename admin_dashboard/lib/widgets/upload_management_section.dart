import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/admin_theme.dart';
import 'universal_upload_widget.dart';

class UploadManagementSection extends StatefulWidget {
  const UploadManagementSection({Key? key}) : super(key: key);

  @override
  State<UploadManagementSection> createState() => _UploadManagementSectionState();
}

class _UploadManagementSectionState extends State<UploadManagementSection> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _uploadTypes = [
    {
      'title': 'Platform Assets',
      'description': 'Upload logos, banners, promotional images for the platform',
      'folder': 'platform',
      'tags': ['platform', 'assets'],
      'icon': Icons.business,
      'color': AdminTheme.deepTeal,
    },
    {
      'title': 'Category Images',
      'description': 'Upload category thumbnails and banners',
      'folder': 'categories',
      'tags': ['category', 'thumbnail'],
      'icon': Icons.category,
      'color': Colors.orange,
    },
    {
      'title': 'Promotional Content',
      'description': 'Upload promotional banners, ads, marketing materials',
      'folder': 'promotions',
      'tags': ['promotion', 'marketing'],
      'icon': Icons.campaign,
      'color': Colors.purple,
    },
    {
      'title': 'Documentation Assets',
      'description': 'Upload help images, guides, tutorial assets',
      'folder': 'docs',
      'tags': ['documentation', 'help'],
      'icon': Icons.help_center,
      'color': Colors.blue,
    },
    {
      'title': 'Email Templates',
      'description': 'Upload images for email templates and notifications',
      'folder': 'email-assets',
      'tags': ['email', 'templates'],
      'icon': Icons.email,
      'color': Colors.green,
    },
    {
      'title': 'Bulk Media Upload',
      'description': 'Upload multiple files for various purposes',
      'folder': 'bulk',
      'tags': ['bulk', 'media'],
      'icon': Icons.cloud_upload,
      'color': Colors.indigo,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.cloud_upload,
                size: 32,
                color: AdminTheme.deepTeal,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Management',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage file uploads for different sections of the platform',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AdminTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showUploadStats,
                icon: const Icon(Icons.analytics),
                tooltip: 'View Upload Statistics',
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Upload Type Selector
          SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: (_uploadTypes.length / 3).ceil(),
              itemBuilder: (context, pageIndex) {
                final startIndex = pageIndex * 3;
                final endIndex = (startIndex + 3).clamp(0, _uploadTypes.length);
                final pageItems = _uploadTypes.sublist(startIndex, endIndex);

                return Row(
                  children: pageItems.map((type) {
                    final index = _uploadTypes.indexOf(type);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildUploadTypeCard(type, index),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // Page Indicator
          if (_uploadTypes.length > 3) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                (_uploadTypes.length / 3).ceil(),
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentPage
                        ? AdminTheme.deepTeal
                        : AdminTheme.mediumGrey.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Upload Widget
          Expanded(
            child: _buildCurrentUploadWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTypeCard(Map<String, dynamic> type, int index) {
    final isSelected = index == _getSelectedUploadTypeIndex();
    
    return GestureDetector(
      onTap: () => _selectUploadType(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? type['color'].withOpacity(0.1)
              : AdminTheme.angel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? type['color']
                : AdminTheme.silverGray,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: type['color'].withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type['icon'],
              size: 24,
              color: isSelected ? type['color'] : AdminTheme.mediumGrey,
            ),
            const SizedBox(height: 8),
            Text(
              type['title'],
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? type['color'] : AdminTheme.darkGrey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentUploadWidget() {
    final selectedIndex = _getSelectedUploadTypeIndex();
    final selectedType = _uploadTypes[selectedIndex];

    return UniversalUploadWidget(
      key: ValueKey(selectedIndex), // Force rebuild when type changes
      title: selectedType['title'],
      description: selectedType['description'],
      folder: selectedType['folder'],
      tags: List<String>.from(selectedType['tags']),
      onUploadComplete: (urls) => _handleUploadComplete(urls, selectedType),
      multiple: true,
      maxFiles: selectedType['folder'] == 'bulk' ? 50 : 10,
      maxFileSizeMB: selectedType['folder'] == 'bulk' ? 10.0 : 5.0,
    );
  }

  int _getSelectedUploadTypeIndex() {
    // You could store this in state, for now return 0
    return 0;
  }

  void _selectUploadType(int index) {
    setState(() {
      // Store selected index in state if needed
    });
  }

  void _handleUploadComplete(List<String> urls, Map<String, dynamic> type) {
    // Log upload to Firestore for tracking
    _logUploadToFirestore(urls, type);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${urls.length} file(s) uploaded successfully to ${type['title']}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _logUploadToFirestore(List<String> urls, Map<String, dynamic> type) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final url in urls) {
        final docRef = FirebaseFirestore.instance.collection('upload_logs').doc();
        batch.set(docRef, {
          'url': url,
          'type': type['title'],
          'folder': type['folder'],
          'tags': type['tags'],
          'uploadedAt': FieldValue.serverTimestamp(),
          'uploadedBy': 'admin', // Replace with actual admin ID
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Error logging upload: $e');
    }
  }

  void _showUploadStats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Statistics'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('upload_logs')
                .orderBy('uploadedAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No upload history found'));
              }
              
              final logs = snapshot.data!.docs;
              final typeStats = <String, int>{};
              
              for (final log in logs) {
                final data = log.data() as Map<String, dynamic>;
                final type = data['type'] as String? ?? 'Unknown';
                typeStats[type] = (typeStats[type] ?? 0) + 1;
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Uploads: ${logs.length}'),
                  const SizedBox(height: 16),
                  const Text('By Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: typeStats.entries.map((entry) => 
                        ListTile(
                          title: Text(entry.key),
                          trailing: Text('${entry.value} files'),
                        ),
                      ).toList(),
                    ),
                  ),
                ],
              );
            },
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
